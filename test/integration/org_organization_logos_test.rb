require "test_helper"

class OrgOrganizationLogosTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    post login_path, params: { email: @owner.email, password: "password123" }
  end

  def uploaded_image(filename: "logo.png", content_type: "image/png", bytes: "fake-logo-bytes")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), content_type, original_filename: filename)
  end

  test "an owner can upload up to 3 logos, each starting pending" do
    images = 3.times.map { |i| uploaded_image(filename: "logo#{i}.png") }

    post org_organization_logos_path, params: { organization_logo: { images: images } }

    assert_redirected_to org_settings_path
    assert_equal 3, @organization.organization_logos.count
    assert @organization.organization_logos.all?(&:pending?)
    assert_equal 3, AuditLog.where(event_type: :organization_logo_submitted).count
  end

  test "uploading beyond the cap of 3 pending/approved logos is rejected" do
    3.times { post org_organization_logos_path, params: { organization_logo: { images: [ uploaded_image ] } } }

    post org_organization_logos_path, params: { organization_logo: { images: [ uploaded_image ] } }

    assert_redirected_to org_settings_path
    assert_equal "You can have at most 3 logos pending or approved at a time.", flash[:alert]
    assert_equal 3, @organization.organization_logos.count
  end

  test "rejects a non-image content type" do
    malicious = uploaded_image(filename: "logo.svg", content_type: "image/svg+xml", bytes: "<script>alert(1)</script>")

    post org_organization_logos_path, params: { organization_logo: { images: [ malicious ] } }

    assert_redirected_to org_settings_path
    assert_match "PNG, JPEG, GIF, or WebP", flash[:alert]
    assert_equal 0, @organization.organization_logos.count
  end

  test "rejects a file over the size limit" do
    oversized = uploaded_image(bytes: "x" * (Org::OrganizationLogosController::MAX_FILE_SIZE + 1))

    post org_organization_logos_path, params: { organization_logo: { images: [ oversized ] } }

    assert_redirected_to org_settings_path
    assert_match "smaller than", flash[:alert]
    assert_equal 0, @organization.organization_logos.count
  end

  test "a member without app.portal.configure cannot upload a logo" do
    member = users(:two)
    @organization.memberships.create!(user: member)
    post login_path, params: { email: member.email, password: "password123" }

    post org_organization_logos_path, params: { organization_logo: { images: [ uploaded_image ] } }

    assert_redirected_to root_path
    assert_equal 0, @organization.organization_logos.count
  end

  test "activating an approved logo attaches it as the live kiosk_logo" do
    logo = @organization.organization_logos.build(uploaded_by: @owner, status: "approved")
    logo.image.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")
    logo.save!

    patch activate_org_organization_logo_path(logo)

    assert_redirected_to org_settings_path
    assert @organization.reload.kiosk_logo.attached?
    assert_equal logo.image.blob_id, @organization.kiosk_logo.blob_id
    assert AuditLog.exists?(event_type: :organization_logo_activated, resource_type: "OrganizationLogo", resource_id: logo.id)
  end

  test "a pending (not yet approved) logo cannot be activated" do
    logo = @organization.organization_logos.build(uploaded_by: @owner, status: "pending")
    logo.image.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")
    logo.save!

    patch activate_org_organization_logo_path(logo)

    assert_response :not_found
    assert_not @organization.reload.kiosk_logo.attached?
  end

  test "deactivate purges the active kiosk_logo" do
    @organization.kiosk_logo.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")

    patch deactivate_org_organization_logos_path

    assert_redirected_to org_settings_path
    assert_not @organization.reload.kiosk_logo.attached?
  end

  test "an owner can withdraw a pending logo before it's reviewed" do
    logo = @organization.organization_logos.build(uploaded_by: @owner, status: "pending")
    logo.image.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")
    logo.save!

    delete org_organization_logo_path(logo)

    assert_redirected_to org_settings_path
    assert_not OrganizationLogo.exists?(logo.id)
    assert AuditLog.exists?(event_type: :organization_logo_withdrawn)
  end

  test "an owner can withdraw an approved logo too" do
    logo = @organization.organization_logos.build(uploaded_by: @owner, status: "approved")
    logo.image.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")
    logo.save!

    delete org_organization_logo_path(logo)

    assert_redirected_to org_settings_path
    assert_not OrganizationLogo.exists?(logo.id)
    assert AuditLog.exists?(event_type: :organization_logo_withdrawn)
  end

  test "withdrawing the currently active logo leaves the live kiosk_logo attached" do
    logo = @organization.organization_logos.build(uploaded_by: @owner, status: "approved")
    logo.image.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")
    logo.save!
    @organization.kiosk_logo.attach(logo.image.blob)

    delete org_organization_logo_path(logo)

    assert_redirected_to org_settings_path
    assert_not OrganizationLogo.exists?(logo.id)
    assert @organization.reload.kiosk_logo.attached?
  end

  test "a member without app.portal.configure cannot withdraw a logo" do
    logo = @organization.organization_logos.build(uploaded_by: @owner, status: "pending")
    logo.image.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")
    logo.save!

    member = users(:two)
    @organization.memberships.create!(user: member)
    post login_path, params: { email: member.email, password: "password123" }

    delete org_organization_logo_path(logo)

    assert_redirected_to root_path
    assert OrganizationLogo.exists?(logo.id)
  end
end
