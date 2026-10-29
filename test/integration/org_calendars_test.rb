# frozen_string_literal: true

require "test_helper"

class OrgCalendarsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "create_personal_for! provisions a default calendar" do
    default = @organization.calendars.find_by!(is_default: true)

    assert_equal "Default", default.name
    assert_not default.archived?
    assert_not default.archivable?
  end

  test "a member with app.calendars.manage can create an additional calendar" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { @organization.calendars.count }, 1 do
        post org_calendars_path, params: {
          calendar: { name: "Room B", color: "#22c55e" }
        }
      end
    end

    created = @organization.calendars.find_by!(name: "Room B")
    assert_not created.is_default?
    assert_redirected_to org_calendars_path
  end

  test "a member with app.calendars.manage can archive a non-default calendar" do
    post login_path, params: { email: @owner.email, password: "password123" }

    default = @organization.calendars.find_by!(is_default: true)
    extra = @organization.calendars.create!(name: "Room B", color: "#22c55e")
    service = @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15,
      calendar: extra
    )

    patch archive_org_calendar_path(extra)
    assert_redirected_to org_calendars_path

    assert extra.reload.archived?
    assert_equal default.id, service.reload.calendar_id
  end

  test "archiving a calendar moves its openings and blocked dates to the default calendar" do
    post login_path, params: { email: @owner.email, password: "password123" }

    default = @organization.calendars.find_by!(is_default: true)
    extra = @organization.calendars.create!(name: "Room B", color: "#22c55e")
    shared = @organization.calendars.create!(name: "Room C", color: "#3b82f6")
    opening = @organization.appointment_openings.create!(
      start_date: Date.current + 1.day, end_date: Date.current + 30.days, calendar_ids: [ extra.id, shared.id ]
    )
    already_default = @organization.appointment_openings.create!(
      start_date: Date.current + 40.days, end_date: Date.current + 60.days, calendar_ids: [ extra.id, default.id ]
    )
    block = @organization.appointment_blocked_dates.create!(start_date: Date.current + 5.days, calendar_ids: [ extra.id ])

    patch archive_org_calendar_path(extra)

    assert_redirected_to org_calendars_path
    assert_match "openings and blocked dates moved to Default", flash[:notice]
    assert_equal [ default.id, shared.id ].sort, opening.reload.calendar_ids.sort
    assert_equal [ default.id ], already_default.reload.calendar_ids
    assert_equal [ default.id ], block.reload.calendar_ids
  end

  test "the default calendar cannot be archived" do
    post login_path, params: { email: @owner.email, password: "password123" }

    default = @organization.calendars.find_by!(is_default: true)

    patch archive_org_calendar_path(default)
    assert_redirected_to org_calendars_path
    assert_match "default calendar cannot be archived", flash[:alert]
    assert_not default.reload.archived?
  end

  test "a member without app.calendars.manage is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_calendars_path
    assert_redirected_to root_path
  end
end
