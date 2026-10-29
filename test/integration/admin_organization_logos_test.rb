require "test_helper"

class AdminOrganizationLogosTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @admin = users(:one)
    system_admin_role = Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_ADMIN) { |r| r.permanent = true }
    @admin.grant_role!(system_admin_role)

    @owner = users(:two)
    @organization = Organization.create_personal_for!(@owner)
    @logo = @organization.organization_logos.build(uploaded_by: @owner)
    @logo.image.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")
    @logo.save!

    post login_path, params: { email: @admin.email, password: "password123" }
  end

  test "index lists logos and supports filtering by status" do
    get admin_organization_logos_path, params: { status: "pending" }
    assert_response :success
  end

  test "show renders a submission" do
    get admin_organization_logo_path(@logo)
    assert_response :success
  end

  test "approve marks the logo approved and notifies the org" do
    assert_enqueued_with(job: NotificationDispatchJob) do
      patch approve_admin_organization_logo_path(@logo)
    end

    assert_redirected_to admin_organization_logo_path(@logo)
    assert @logo.reload.approved?
    assert_equal @admin, @logo.reviewed_by
    assert AuditLog.exists?(event_type: :organization_logo_approved, resource_type: "OrganizationLogo", resource_id: @logo.id)
  end

  test "decline without a reason re-renders with a validation error" do
    patch decline_admin_organization_logo_path(@logo), params: { organization_logo: { decline_reason: "" } }

    assert_response :unprocessable_entity
    assert @logo.reload.pending?
  end

  test "decline with a reason marks the logo declined and notifies the org" do
    assert_enqueued_with(job: NotificationDispatchJob) do
      patch decline_admin_organization_logo_path(@logo), params: { organization_logo: { decline_reason: "Low resolution" } }
    end

    assert_redirected_to admin_organization_logo_path(@logo)
    assert @logo.reload.declined?
    assert_equal "Low resolution", @logo.decline_reason
    assert AuditLog.exists?(event_type: :organization_logo_declined, resource_type: "OrganizationLogo", resource_id: @logo.id)
  end

  test "a system_user without the organization_logos permission is blocked" do
    system_admin_role_only = users(:one).roles.system.find_by!(name: Role::SYSTEM_ADMIN)
    users(:one).user_roles.find_by!(role: system_admin_role_only).destroy!

    system_user_role = Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_USER) { |r| r.permanent = true }
    users(:one).grant_role!(system_user_role)

    get admin_organization_logos_path

    assert_redirected_to root_path
  end

  test "a regular user cannot access the admin queue" do
    delete logout_path
    post login_path, params: { email: @owner.email, password: "password123" }

    get admin_organization_logos_path

    assert_redirected_to root_path
  end
end
