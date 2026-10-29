# frozen_string_literal: true

require "test_helper"

class OrgOpeningHoursTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "an owner with app.portal.configure can view opening hours" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_opening_hours_path

    assert_response :success
    assert_match "Opening hours", response.body
    assert_match(/organization\[operating_hours\]\[monday\]\[open_day\]/, response.body)
    assert_match "Save opening hours", response.body
  end

  test "an owner can update opening hours" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_opening_hours_path, params: {
      organization: {
        operating_hours: {
          "monday" => { open_day: "1", open: "10:00", close: "17:00" },
          "sunday" => { open_day: "0", open: "", close: "" }
        }
      }
    }

    assert_redirected_to org_opening_hours_path
    @organization.reload
    assert_equal({ "open" => "10:00", "close" => "17:00" }, @organization.operating_hours["monday"])
    assert_nil @organization.operating_hours["sunday"]
  end

  test "invalid opening hours are rejected" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_opening_hours_path, params: {
      organization: {
        operating_hours: {
          "monday" => { open_day: "1", open: "18:00", close: "09:00" }
        }
      }
    }

    assert_response :unprocessable_entity
    assert_match(/Monday close must be after open/i, response.body)
  end

  test "a member without app.portal.configure is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_opening_hours_path
    assert_redirected_to root_path
  end
end
