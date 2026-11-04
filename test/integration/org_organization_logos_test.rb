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

  test "an owner can upload a logo and it goes live immediately" do
    post org_organization_logo_path, params: { organization_logo: { image: uploaded_image } }

    assert_redirected_to org_settings_path
    assert @organization.reload.kiosk_logo.attached?
    assert AuditLog.exists?(event_type: :organization_logo_uploaded, resource_id: @organization.id)
  end

  test "uploading again replaces the current logo" do
    post org_organization_logo_path, params: { organization_logo: { image: uploaded_image(bytes: "first") } }
    first_blob_id = @organization.reload.kiosk_logo.blob_id

    post org_organization_logo_path, params: { organization_logo: { image: uploaded_image(bytes: "second") } }

    assert_not_equal first_blob_id, @organization.reload.kiosk_logo.blob_id
  end

  test "rejects a missing file" do
    post org_organization_logo_path, params: { organization_logo: { image: "" } }

    assert_redirected_to org_settings_path
    assert_equal "Choose a logo to upload.", flash[:alert]
  end

  test "rejects a non-image content type" do
    malicious = uploaded_image(filename: "logo.svg", content_type: "image/svg+xml", bytes: "<script>alert(1)</script>")

    post org_organization_logo_path, params: { organization_logo: { image: malicious } }

    assert_redirected_to org_settings_path
    assert_match "PNG, JPEG, GIF, or WebP", flash[:alert]
    assert_not @organization.reload.kiosk_logo.attached?
  end

  test "rejects a file over the size limit" do
    oversized = uploaded_image(bytes: "x" * (Org::OrganizationLogosController::MAX_FILE_SIZE + 1))

    post org_organization_logo_path, params: { organization_logo: { image: oversized } }

    assert_redirected_to org_settings_path
    assert_match "smaller than", flash[:alert]
    assert_not @organization.reload.kiosk_logo.attached?
  end

  test "a member without app.portal.configure cannot upload a logo" do
    member = users(:two)
    @organization.memberships.create!(user: member)
    post login_path, params: { email: member.email, password: "password123" }

    post org_organization_logo_path, params: { organization_logo: { image: uploaded_image } }

    assert_redirected_to root_path
    assert_not @organization.reload.kiosk_logo.attached?
  end

  test "an owner can remove the logo" do
    @organization.kiosk_logo.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")

    delete org_organization_logo_path

    assert_redirected_to org_settings_path
    assert_not @organization.reload.kiosk_logo.attached?
    assert AuditLog.exists?(event_type: :organization_logo_removed)
  end

  test "a member without app.portal.configure cannot remove the logo" do
    @organization.kiosk_logo.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")
    member = users(:two)
    @organization.memberships.create!(user: member)
    post login_path, params: { email: member.email, password: "password123" }

    delete org_organization_logo_path

    assert_redirected_to root_path
    assert @organization.reload.kiosk_logo.attached?
  end
end
