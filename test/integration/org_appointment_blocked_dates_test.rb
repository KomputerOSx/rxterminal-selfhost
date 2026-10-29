# frozen_string_literal: true

require "test_helper"

class OrgAppointmentBlockedDatesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @date = Date.current + 3.days
    post login_path, params: { email: @owner.email, password: "password123" }
  end

  test "an owner can block a date range" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post org_appointment_booking_blocked_dates_path, params: {
        appointment_blocked_date: { start_date: @date.iso8601, end_date: (@date + 2.days).iso8601, reason: "Refit" }
      }
    end

    assert_redirected_to org_appointment_booking_path
    block = @organization.appointment_blocked_dates.last
    assert_equal [ @date, @date + 2.days, "Refit", "manual" ], [ block.start_date, block.end_date, block.reason, block.source ]
    assert AuditLog.exists?(event_type: "appointment_blocked_date_created", resource_id: block.id)
  end

  test "blocking selected calendars limits the block to them" do
    clinic = @organization.calendars.create!(name: "Clinic")
    other = @organization.calendars.create!(name: "Other")

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post org_appointment_booking_blocked_dates_path, params: {
        appointment_blocked_date: { start_date: @date.iso8601, calendar_scope: "selected", calendar_ids: [ "", clinic.id, other.id ] }
      }
    end

    assert_redirected_to org_appointment_booking_path
    assert_equal [ clinic.id, other.id ].sort, @organization.appointment_blocked_dates.last.calendar_ids.sort
  end

  test "selected calendars with none ticked is rejected" do
    @organization.calendars.create!(name: "Clinic")

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post org_appointment_booking_blocked_dates_path,
        params: { appointment_blocked_date: { start_date: @date.iso8601, calendar_scope: "selected", calendar_ids: [ "" ] } },
        as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_not @organization.appointment_blocked_dates.exists?
  end

  test "importing public holidays for selected calendars" do
    clinic = @organization.calendars.create!(name: "Clinic")

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post import_org_appointment_booking_blocked_dates_path, params: {
        holiday_import: { region: "gb_eng", calendar_scope: "selected", calendar_ids: [ "", clinic.id ] }
      }
    end

    assert_redirected_to org_appointment_booking_path
    imported = @organization.appointment_blocked_dates.includes(:calendars)
    assert imported.any?
    assert imported.all? { |block| block.calendar_ids == [ clinic.id ] }
  end

  test "invalid blocked dates render errors in place" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post org_appointment_booking_blocked_dates_path,
        params: { appointment_blocked_date: { start_date: @date.iso8601, end_date: (@date - 1.day).iso8601 } },
        as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_match "cannot be before the start date", response.body
  end

  test "blocking a date with bookings warns but keeps the appointments" do
    service = @organization.services.create!(
      internal_name: "blocked_svc", display_name: "Blocked Service", estimated_duration: 15,
      requires_appointment: true, active: true, calendar: @organization.calendars.first
    )
    booking_date = @date
    booking_date += 1.day while booking_date.saturday? || booking_date.sunday?
    appointment = Appointment.create!(
      organization: @organization, service: service, first_name: "JANE", last_name: "DOE",
      dob: Date.new(1990, 1, 1), postcode: "N1 1AA", appointment_date: booking_date,
      appointment_time: Time.zone.parse("10:00"), status: "booked"
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post org_appointment_booking_blocked_dates_path,
        params: { appointment_blocked_date: { start_date: booking_date.iso8601 } },
        as: :turbo_stream
    end

    assert_match "outside your booking schedule", response.body
    assert_match appointment.booking_reference, response.body
    assert_equal "booked", appointment.reload.status
  end

  test "an owner can import public holidays" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post import_org_appointment_booking_blocked_dates_path, params: { holiday_import: { region: "gb_eng" } }
    end

    assert_redirected_to org_appointment_booking_path
    assert @organization.appointment_blocked_dates.where(source: "imported").exists?
    log = AuditLog.find_by(event_type: "appointment_blocked_dates_imported")
    assert_equal "gb_eng", log.metadata["region"]
  end

  test "importing an unknown region is rejected" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post import_org_appointment_booking_blocked_dates_path, params: { holiday_import: { region: "atlantis" } }
    end

    assert_redirected_to org_appointment_booking_path
    assert_equal "Choose a country or region.", flash[:alert]
    assert_not @organization.appointment_blocked_dates.exists?
  end

  test "an owner can remove a blocked date" do
    block = @organization.appointment_blocked_dates.create!(start_date: @date)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      delete org_appointment_booking_blocked_date_path(block)
    end

    assert_redirected_to org_appointment_booking_path
    assert_not AppointmentBlockedDate.exists?(block.id)
    assert AuditLog.exists?(event_type: "appointment_blocked_date_deleted", resource_id: block.id)
  end

  test "removing a blocked date keeps the current page" do
    blocks = 12.times.map { |index| @organization.appointment_blocked_dates.create!(start_date: Date.current + (index + 1).days, reason: "Closure #{index + 1}") }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      delete org_appointment_booking_blocked_date_path(blocks.last, blocked_dates_page: 2), as: :turbo_stream
    end

    assert_response :success
    assert_match "Page 2 of 2", response.body
    assert_match "Closure 11", response.body
    assert_match "blocked_dates_page=1", response.body
  end

  test "a member without app.portal.configure is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)
    delete logout_path
    post login_path, params: { email: users(:two).email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post org_appointment_booking_blocked_dates_path, params: { appointment_blocked_date: { start_date: @date.iso8601 } }
    end

    assert_redirected_to root_path
    assert_not @organization.appointment_blocked_dates.exists?
  end
end
