# frozen_string_literal: true

require "test_helper"

class OrgServicesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15,
      allows_immediate: true,
      icon: "vaccines"
    )
  end

  test "a member with app.services.manage can view services index" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_services_path
    assert_response :success
    assert_match "Flu Jab", response.body
  end

  test "a member with app.services.manage can create a service" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_difference -> { @organization.services.visible.count }, 1 do
      post org_services_path, params: {
        service: {
          internal_name: "blood_pressure",
          display_name: "Blood pressure check",
          estimated_duration: 10,
          allows_immediate: true,
          requires_appointment: false,
          active: true,
          icon: "monitor_heart"
        }
      }
    end

    created = @organization.services.visible.find_by!(internal_name: "blood_pressure")
    assert_redirected_to org_service_path(created)
    assert_equal "monitor_heart", created.icon
  end

  test "a member with app.services.manage can toggle a service" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert @service.active?
    post toggle_org_service_path(@service)
    assert_redirected_to org_services_path
    assert_not @service.reload.active?
  end

  test "a member with app.services.manage can soft delete a service" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_difference -> { @organization.services.visible.count }, -1 do
      delete org_service_path(@service)
    end

    assert_redirected_to org_services_path
    assert @service.reload.deleted?
  end

  test "a member without app.services.manage is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_services_path
    assert_redirected_to root_path
  end
end
