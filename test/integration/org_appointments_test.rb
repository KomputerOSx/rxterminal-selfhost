# frozen_string_literal: true

require "test_helper"

class OrgAppointmentsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15,
      requires_appointment: true,
      allows_immediate: false,
      icon: "vaccines"
    )
    @appointment = @organization.appointments.create!(
      service: @service,
      first_name: "JOHN",
      last_name: "SMITH",
      dob: Date.new(1990, 5, 15),
      postcode: "SW1A 1AA",
      appointment_date: Date.current + 1.day,
      appointment_time: "10:00",
      status: "booked"
    )
  end

  test "a member with app.appointments.view can view appointments index" do
    post login_path, params: { email: @owner.email, password: "password123" }

    cancelled = @organization.appointments.create!(
      service: @service,
      first_name: "CANCEL",
      last_name: "ME",
      dob: Date.new(1991, 1, 1),
      postcode: "SW1A 1AA",
      appointment_date: @appointment.appointment_date,
      appointment_time: "09:00",
      status: "cancelled"
    )

    get org_appointments_path(date: @appointment.appointment_date)
    assert_response :success
    assert_match "JOHN SMITH", response.body
    assert_match @appointment.booking_reference, response.body
    assert_select "span.font-semibold.text-base-content", text: "2"
    assert_match "booked", response.body
    assert_match "cancelled", response.body
    assert_match cancelled.booking_reference, response.body
  end

  test "a member with app.appointments.manage can create an appointment" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { @organization.appointments.count }, 1 do
        post org_appointments_path, params: {
          appointment: {
            service_id: @service.id,
            first_name: "jane",
            last_name: "doe",
            dob: "20-05-1985",
            postcode: "SW1A 2AA",
            appointment_date: (Date.current + 2.days).strftime("%d-%m-%Y"),
            appointment_time: "11:00"
          }
        }
      end
    end

    created = @organization.appointments.order(:id).last
    assert_redirected_to org_appointment_path(created)
    assert_equal "JANE", created.first_name
    assert_equal "booked", created.status
  end

  test "a member with app.appointments.manage can check in a todays appointment" do
    post login_path, params: { email: @owner.email, password: "password123" }

    today_appointment = @organization.appointments.create!(
      service: @service,
      first_name: "ALICE",
      last_name: "JONES",
      dob: Date.new(1988, 3, 10),
      postcode: "SW1A 1AA",
      appointment_date: Date.current,
      appointment_time: "14:00",
      status: "booked"
    )

    patch check_in_org_appointment_path(today_appointment)
    assert_redirected_to org_queue_path
    today_appointment.reload
    assert_equal "checked_in", today_appointment.status
    assert today_appointment.service_request.present?
  end

  test "a member with app.appointments.manage can return a checked-in appointment to booked" do
    post login_path, params: { email: @owner.email, password: "password123" }

    today_appointment = @organization.appointments.create!(
      service: @service,
      first_name: "ALICE",
      last_name: "JONES",
      dob: Date.new(1988, 3, 10),
      postcode: "SW1A 1AA",
      appointment_date: Date.current,
      appointment_time: "14:00",
      status: "booked"
    )
    service_request = today_appointment.check_in!

    patch return_to_booked_org_appointment_path(today_appointment)

    assert_redirected_to org_appointment_path(today_appointment)
    today_appointment.reload
    assert_equal "booked", today_appointment.status
    assert_nil today_appointment.service_request_id
    assert_equal "cancelled", service_request.reload.status
  end

  test "return_to_booked is blocked when the queue entry is already in progress" do
    post login_path, params: { email: @owner.email, password: "password123" }

    today_appointment = @organization.appointments.create!(
      service: @service,
      first_name: "ALICE",
      last_name: "JONES",
      dob: Date.new(1988, 3, 10),
      postcode: "SW1A 1AA",
      appointment_date: Date.current,
      appointment_time: "14:00",
      status: "booked"
    )
    service_request = today_appointment.check_in!
    service_request.call!

    patch return_to_booked_org_appointment_path(today_appointment)

    assert_redirected_to org_appointment_path(today_appointment)
    assert_equal "checked_in", today_appointment.reload.status
  end

  test "return_to_booked rejects an appointment that is not checked in" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch return_to_booked_org_appointment_path(@appointment)

    assert_redirected_to org_appointment_path(@appointment)
    assert_equal "booked", @appointment.reload.status
  end

  test "a member with app.appointments.manage can cancel an appointment" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch cancel_org_appointment_path(@appointment)
    assert_redirected_to org_appointments_path(date: @appointment.appointment_date)
    assert_equal "cancelled", @appointment.reload.status
  end

  test "a member can cancel an appointment booked without dob and postcode when the organization no longer requires them" do
    @organization.update!(kiosk_collect_dob: false, kiosk_collect_postcode: false)
    optional_appointment = @organization.appointments.create!(
      service: @service,
      first_name: "OPTIONAL",
      last_name: "FIELDS",
      dob: nil,
      postcode: nil,
      appointment_date: @appointment.appointment_date,
      appointment_time: "11:00",
      status: "booked"
    )

    post login_path, params: { email: @owner.email, password: "password123" }

    patch cancel_org_appointment_path(optional_appointment)
    assert_redirected_to org_appointments_path(date: optional_appointment.appointment_date)
    assert_equal "cancelled", optional_appointment.reload.status
  end

  test "cancelling with a reason stores it and emails it to the customer" do
    @appointment.update!(email: "john@example.com")
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_enqueued_email_with AppointmentMailer, :cancellation, args: [ @appointment ] do
      patch cancel_org_appointment_path(@appointment), params: { cancellation_reason: "Pharmacist unavailable" }
    end

    assert_equal "cancelled", @appointment.reload.status
    assert_equal "Pharmacist unavailable", @appointment.cancellation_reason

    get org_appointment_path(@appointment)
    assert_match "Cancellation reason", response.body
    assert_match "Pharmacist unavailable", response.body
  end

  test "the appointment page offers a cancellation reason box" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_appointment_path(@appointment)

    assert_response :success
    assert_match 'name="cancellation_reason"', response.body
  end

  test "staff bookings require an email when the organization requires it" do
    @organization.update!(require_appointment_email: true)
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_no_difference -> { Appointment.count } do
      post org_appointments_path, params: {
        appointment: {
          service_id: @service.id,
          first_name: "JANE",
          last_name: "DOE",
          dob: "1990-01-01",
          postcode: "N1 1AA",
          email: "",
          appointment_date: (Date.current + 1.day).iso8601,
          appointment_time: "11:00"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "be blank", response.body.downcase
  end

  test "slots endpoint returns available slots" do
    post login_path, params: { email: @owner.email, password: "password123" }

    slot_date = Date.current + 1.day
    slot_date += 1.day while slot_date.saturday? || slot_date.sunday?

    get slots_org_appointments_path,
      params: { service_id: @service.id, date: slot_date.strftime("%d-%m-%Y") }
    assert_response :success
    assert_match "10:00", response.body
  end

  test "print view renders full appointment table" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get print_org_appointments_path(date: @appointment.appointment_date)
    assert_response :success
    assert_match "Print Appointments", response.body
    assert_match %q(data-theme="light"), response.body
    assert_match @organization.name, response.body
    assert_match @appointment.booking_reference, response.body
    assert_match "DOB", response.body
    assert_match "Postcode", response.body
    assert_match "Email", response.body
    assert_match "Notes", response.body
    assert_no_match "material-symbols-outlined", response.body
  end

  test "print view filters by service_id" do
    post login_path, params: { email: @owner.email, password: "password123" }

    other_service = @organization.services.create!(
      internal_name: "blood-test",
      display_name: "Blood Test",
      estimated_duration: 10,
      requires_appointment: true,
      allows_immediate: false,
      icon: "science"
    )
    other_appointment = @organization.appointments.create!(
      service: other_service,
      first_name: "BOB",
      last_name: "JONES",
      dob: Date.new(1985, 1, 1),
      postcode: "SW1A 1AA",
      appointment_date: @appointment.appointment_date,
      appointment_time: "11:00",
      status: "booked"
    )

    get print_org_appointments_path(date: @appointment.appointment_date, service_id: @service.id)
    assert_response :success
    assert_match @appointment.booking_reference, response.body
    assert_no_match other_appointment.booking_reference, response.body
  end

  test "a member without app.appointments.view is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_appointments_path
    assert_redirected_to root_path
  end

  test "week view shows appointments across the week and excludes other weeks" do
    post login_path, params: { email: @owner.email, password: "password123" }

    monday = Date.new(2027, 3, 1)
    inside = appointment_on(monday + 4.days, first_name: "WEEK", last_name: "INSIDE")
    outside = appointment_on(monday + 7.days, first_name: "WEEK", last_name: "OUTSIDE")
    cancelled = appointment_on(monday, first_name: "GONE", last_name: "AWAY", status: "cancelled")

    get org_appointments_path(view: "week", date: (monday + 2.days).iso8601)
    assert_response :success
    assert_select "#appointments_day_2027-03-01"
    assert_select "#appointments_day_2027-03-07"
    assert_select "#appointments_day_2027-03-08", count: 0
    assert_select "#appointments_day_2027-03-05 a[href^=?]", "#{org_appointment_path(inside)}?"
    assert_select "#appointments_day_2027-03-01 .line-through", text: "GONE AWAY"
    assert_select "a[href^=?]", "#{org_appointment_path(outside)}?", count: 0
    assert_select "a[href^=?]", "#{org_appointment_path(cancelled)}?"
  end

  test "month view shows status counts per day linking to the day view" do
    post login_path, params: { email: @owner.email, password: "password123" }

    day = Date.new(2027, 3, 10)
    appointment_on(day)
    appointment_on(day)
    appointment_on(day, status: "cancelled")
    appointment_on(Date.new(2027, 5, 10))

    get org_appointments_path(view: "month", date: day.iso8601)
    assert_response :success
    assert_select "a#appointments_day_2027-03-10[href=?]", org_appointments_path(view: "day", date: "2027-03-10")
    assert_select "#appointments_day_2027-03-10", text: /2\s+booked/
    assert_select "#appointments_day_2027-03-10", text: /1\s+cancelled/
    assert_select "#appointments_day_2027-02-28", count: 0
    assert_select "#appointments_day_2027-04-04"
    assert_select "#appointments_day_2027-04-05", count: 0
    assert_select "span.font-semibold", text: "March 2027"
  end

  test "an unknown view falls back to the day view" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_appointments_path(view: "year", date: @appointment.appointment_date)
    assert_response :success
    assert_select "table"
    assert_match @appointment.booking_reference, response.body
  end

  test "calendar filter limits appointments to the chosen calendar" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_appointments_path(view: "week", date: @appointment.appointment_date)
    assert_select "select[name=calendar_id]", count: 0

    clinic = @organization.calendars.create!(name: "Clinic")
    clinic_service = @organization.services.create!(
      internal_name: "bp-check",
      display_name: "BP Check",
      estimated_duration: 15,
      requires_appointment: true,
      allows_immediate: false,
      icon: "monitor_heart",
      calendar: clinic
    )
    clinic_appointment = appointment_on(@appointment.appointment_date, service: clinic_service)
    assert_equal clinic.id, clinic_appointment.calendar_id

    get org_appointments_path(view: "week", date: @appointment.appointment_date)
    assert_select "select[name=calendar_id]"
    assert_select "a[href^=?]", "#{org_appointment_path(@appointment)}?"
    assert_select "a[href^=?]", "#{org_appointment_path(clinic_appointment)}?"

    get org_appointments_path(view: "week", date: @appointment.appointment_date, calendar_id: clinic.id)
    assert_select "a[href^=?]", "#{org_appointment_path(@appointment)}?", count: 0
    assert_select "a[href^=?]", "#{org_appointment_path(clinic_appointment)}?"
  end

  test "week view shows closed days with their reason" do
    post login_path, params: { email: @owner.email, password: "password123" }

    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 3), end_date: Date.new(2027, 3, 3), reason: "Refit")

    get org_appointments_path(view: "week", date: "2027-03-01")
    assert_select "#appointments_day_2027-03-03", text: /Closed: Refit/
    assert_select "#appointments_day_2027-03-04", text: /Closed/, count: 0
  end

  test "show back link returns to the view the appointment was opened from" do
    post login_path, params: { email: @owner.email, password: "password123" }

    clinic = @organization.calendars.create!(name: "Clinic")
    get org_appointments_path(view: "month", date: "2027-03-15", calendar_id: clinic.id)
    assert_select "a#appointments_day_2027-03-01"

    get org_appointments_path(view: "week", date: @appointment.appointment_date)
    assert_select "a[href=?]", org_appointment_path(@appointment, view: "week", date: @appointment.appointment_date.iso8601)

    get org_appointment_path(@appointment, view: "month", date: "2027-03-15", calendar_id: clinic.id)
    assert_select "a.btn[href=?]", org_appointments_path(view: "month", date: "2027-03-15", calendar_id: clinic.id), text: "Back"
  end

  test "show back link ignores unknown views, foreign calendars and bad dates" do
    post login_path, params: { email: @owner.email, password: "password123" }

    other_org = Organization.create_personal_for!(users(:two))
    foreign_calendar = other_org.calendars.first

    get org_appointment_path(@appointment, view: "javascript:alert(1)", date: "not-a-date", calendar_id: foreign_calendar.id)
    assert_select "a.btn[href=?]", org_appointments_path(date: @appointment.appointment_date.iso8601), text: "Back"
  end

  test "search results keep the current view" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get search_org_appointments_path(q: "SMITH", view: "week")
    assert_select "a[href=?]", org_appointment_path(@appointment, view: "week")
  end

  private

  def appointment_on(date, time: nil, status: "booked", service: @service, first_name: "JANE", last_name: "DOE")
    @slot_offset = (@slot_offset || 0) + 1
    time ||= format("%02d:%02d", 12 + @slot_offset / 4, (@slot_offset % 4) * 15)
    appointment = @organization.appointments.create!(
      service: service,
      first_name: first_name,
      last_name: last_name,
      dob: Date.new(1990, 5, 15),
      postcode: "SW1A 1AA",
      appointment_date: Date.current + 1.day,
      appointment_time: time,
      status: status
    )
    appointment.update_columns(appointment_date: date)
    appointment
  end
end
