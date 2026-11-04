require "test_helper"

class OrgFeaturesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "an owner can opt in to a feature" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_features_path, params: { features: { "online_appointment_booking" => { enabled: "1" } } }

    assert_redirected_to org_features_path
    assert @organization.reload.feature_enabled?("online_appointment_booking")
    assert AuditLog.exists?(event_type: :organization_feature_settings_updated)
  end

  test "the features page lists the catalog" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_features_path

    assert_response :success
    assert_match "Online appointment booking", response.body
  end

  test "a member without app.organization.manage is denied" do
    user_role = Role.find_or_create_by!(scope: :app, name: Role::APP_USER)
    plain_member = @organization.memberships.create!(user: users(:two))
    plain_member.grant_role!(user_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    patch org_features_path, params: { features: { "online_appointment_booking" => { enabled: "1" } } }

    assert_redirected_to dashboard_path
  end

  test "toggling a key outside the catalog is silently ignored" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_features_path, params: { features: { "not_a_feature" => { enabled: "1" } } }

    assert_redirected_to org_features_path
    assert_equal({}, @organization.reload.feature_settings("not_a_feature"))
  end

  test "a feature that does not require org opt-in reads as enabled" do
    assert @organization.feature_enabled?("public_portal")
  end
end
