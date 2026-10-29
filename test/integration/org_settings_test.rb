# frozen_string_literal: true

require "test_helper"

class OrgSettingsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15,
      active: true
    )
  end

  test "settings page shows identity, public URLs, logo, and leave section" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_settings_path

    assert_response :success
    assert_match @organization.name, response.body
    assert_match(/organization\[slug\]/, response.body)
    assert_match(/organization\[postcode_region\]/, response.body)
    assert_match(/organization\[service_currency\]/, response.body)
    assert_match(/organization\[kiosk_collect_postcode\]/, response.body)
    assert_match "Collect postcode on kiosk and walk-in forms", response.body
    assert_match(/organization\[kiosk_collect_dob\]/, response.body)
    assert_match "Collect date of birth on kiosk and walk-in forms", response.body
    assert_match "Organization logo", response.body
    assert_match "/#{@organization.slug}", response.body
    assert_match "Leave organization", response.body
  end

  test "members page no longer shows leave organization section" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_members_path

    assert_response :success
    assert_no_match "Leave organization", response.body
  end

  test "a plain member sees read-only organization details" do
    member = users(:two)
    @organization.memberships.create!(user: member).grant_role!(Role.find_by!(scope: :app, name: Role::APP_USER))

    post login_path, params: { email: member.email, password: "password123" }

    get org_settings_path

    assert_response :success
    assert_no_match(/organization\[slug\]/, response.body)
    assert_match @organization.slug, response.body
    assert_match "Leave organization", response.body
  end
end
