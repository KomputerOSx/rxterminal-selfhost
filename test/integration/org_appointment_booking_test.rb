# frozen_string_literal: true

require "test_helper"

class OrgAppointmentBookingTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "an owner with app.portal.configure can view appointment booking" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_appointment_booking_path

    assert_response :success
    assert_match "Appointment booking", response.body
    assert_match(/organization\[appointment_days_ahead\]/, response.body)
    assert_match(/organization\[bookable_times\]\[monday\]\[bookable_day\]/, response.body)
    assert_match "Interval", response.body
    assert_match "No booking", response.body
    assert_match "Save appointment booking", response.body
  end

  test "an owner can update appointment booking settings" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      patch org_appointment_booking_path, params: {
        organization: {
          appointment_days_ahead: 21,
          bookable_times: {
            "monday" => {
              bookable_day: "1",
              "0" => { start: "11:00", end: "12:00" }
            },
            "sunday" => { bookable_day: "0" }
          }
        }
      }

      assert_redirected_to org_appointment_booking_path
    end

    @organization.reload
    assert_equal 21, @organization.appointment_days_ahead
    assert_equal [ { "start" => "11:00", "end" => "12:00" } ], @organization.bookable_times["monday"]
    assert_equal [], @organization.bookable_times["sunday"]
  end

  test "invalid bookable windows are rejected" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      patch org_appointment_booking_path, params: {
        organization: {
          appointment_days_ahead: 14,
          bookable_times: {
            "tuesday" => {
              bookable_day: "1",
              "0" => { start: "15:00", end: "14:00" }
            }
          }
        }
      }

      assert_response :unprocessable_entity
      assert_match(/Tuesday window 1 must end after it starts/i, response.body)
    end
  end

  test "the page shows booking mode, blocked dates and openings" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_appointment_booking_path

    assert_response :success
    assert_match "Booking mode", response.body
    assert_match "Rolling dates", response.body
    assert_match "Set openings", response.body
    assert_match "Add blocked date", response.body
    assert_match "Import public holidays", response.body
    assert_match "New opening", response.body
  end

  test "an owner can switch to openings mode" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      patch org_appointment_booking_path, params: { organization: { appointment_booking_mode: "openings" } }
    end

    assert_redirected_to org_appointment_booking_path
    assert @organization.reload.booking_mode_openings?
    log = AuditLog.where(event_type: "organization_updated").last
    assert_includes log.metadata["changed_fields"], "appointment_booking_mode"
  end

  test "switching mode warns about booked appointments that no longer fit" do
    post login_path, params: { email: @owner.email, password: "password123" }
    service = @organization.services.create!(
      internal_name: "mode_svc", display_name: "Mode Service", estimated_duration: 15,
      requires_appointment: true, active: true, calendar: @organization.calendars.first
    )
    date = Date.current + 1.day
    date += 1.day while date.saturday? || date.sunday?
    appointment = Appointment.create!(
      organization: @organization, service: service, first_name: "JANE", last_name: "DOE",
      dob: Date.new(1990, 1, 1), postcode: "N1 1AA", appointment_date: date,
      appointment_time: Time.zone.parse("10:00"), status: "booked"
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      patch org_appointment_booking_path, params: { organization: { appointment_booking_mode: "openings" } }
    end

    assert_match "outside your booking schedule", flash[:toast][:message]
    follow_redirect!
    assert_match "Appointments to review", response.body
    assert_match appointment.booking_reference, response.body
    assert_equal "booked", appointment.reload.status
  end

  test "an unknown booking mode is rejected" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      patch org_appointment_booking_path, params: { organization: { appointment_booking_mode: "sometimes" } }
    end

    assert_response :unprocessable_entity
    assert @organization.reload.booking_mode_rolling?
  end

  test "openings and blocked dates tables show 10 per page" do
    post login_path, params: { email: @owner.email, password: "password123" }
    12.times do |index|
      start = Date.current + (index * 10).days
      @organization.appointment_openings.create!(name: "Opening #{index + 1}", start_date: start, end_date: start + 5.days)
      @organization.appointment_blocked_dates.create!(start_date: Date.current + (index + 1).days, reason: "Closure #{index + 1}")
    end

    get org_appointment_booking_path

    assert_response :success
    assert_equal 2, response.body.scan("Page 1 of 2").size
    assert_match "Opening 10<", response.body
    assert_no_match "Opening 11<", response.body
    assert_match "Closure 10<", response.body
    assert_no_match "Closure 11<", response.body

    get org_appointment_booking_path(openings_page: 2, blocked_dates_page: 2)

    assert_match "Opening 11<", response.body
    assert_no_match "Opening 1<", response.body
    assert_match "Closure 12<", response.body
    assert_equal 2, response.body.scan("Page 2 of 2").size
  end

  test "an out of range page shows the last page" do
    post login_path, params: { email: @owner.email, password: "password123" }
    11.times { |index| @organization.appointment_blocked_dates.create!(start_date: Date.current + (index + 1).days, reason: "Closure #{index + 1}") }

    get org_appointment_booking_path(blocked_dates_page: 9)

    assert_match "Closure 11<", response.body
    assert_match "Page 2 of 2", response.body
  end

  test "a member without app.portal.configure is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_appointment_booking_path
    assert_redirected_to root_path
  end

  test "an owner can require customer emails and set a custom email message" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_appointment_booking_path
    assert_match "Customer emails", response.body
    assert_match "Please arrive 5 minutes before your scheduled appointment.", response.body

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      patch org_appointment_booking_path, params: {
        organization: { require_appointment_email: "1", appointment_email_message: "Bring your inhaler." }
      }

      assert_redirected_to org_appointment_booking_path
    end

    @organization.reload
    assert @organization.require_appointment_email?
    assert_equal "Bring your inhaler.", @organization.appointment_email_message
  end
end
