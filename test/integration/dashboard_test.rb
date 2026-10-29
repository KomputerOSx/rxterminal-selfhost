# frozen_string_literal: true

require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "dashboard shows org-aware quick links for owner" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get dashboard_path

    assert_response :success
    assert_match "Dashboard", response.body
    assert_match "Queue", response.body
    assert_match "Quick links", response.body
  end

  test "dashboard shows today at a glance, upsell, and requests chart widgets for owner" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get dashboard_path

    assert_response :success
    assert_match "Today at a glance", response.body
    assert_match "In progress", response.body
    assert_match "Upsell conversions today", response.body
    assert_match "Requests this week", response.body
  end

  test "dashboard hides upsell and analytics widgets for user role" do
    user_role = Role.find_by!(scope: :app, name: Role::APP_USER)
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(user_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get dashboard_path

    assert_response :success
    assert_no_match "Upsell conversions today", response.body
    assert_no_match "Requests this week", response.body
  end

  test "dashboard shows limited links for user role" do
    user_role = Role.find_by!(scope: :app, name: Role::APP_USER)
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(user_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get dashboard_path

    assert_response :success
    assert_match "Queue", response.body
    assert_no_match "Kiosk", response.body
    assert_no_match "Analytics", response.body
  end
end
