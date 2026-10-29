# frozen_string_literal: true

require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  setup do
    @ts = "#{Time.current.to_i}#{rand(9999)}"
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "appt_svc_#{@ts}",
      display_name: "Appt Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: @calendar
    )
    @other_service = @organization.services.create!(
      internal_name: "appt_other_#{@ts}",
      display_name: "Other Appt Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: @calendar
    )
    @appointment_date = Date.current + 1.day
    @appointment_time = Time.zone.parse("10:00")
  end

  test "calendar_id is auto-assigned from service on create" do
    appt = create_appointment!

    assert_equal @calendar.id, appt.calendar_id
  end

  test "save_with_slot_protection rejects a slot already booked on the same calendar" do
    create_appointment!

    conflicting = Appointment.new(
      organization: @organization,
      service: @other_service,
      first_name: "JOHN",
      last_name: "SMITH",
      dob: Date.new(1991, 2, 2),
      postcode: "E1 1AA",
      appointment_date: @appointment_date,
      appointment_time: @appointment_time,
      status: "booked"
    )

    assert_not conflicting.save_with_slot_protection
    assert_includes conflicting.errors[:appointment_time], "is no longer available"
  end

  test "update_with_slot_protection allows saving the same slot on the same appointment" do
    appointment = create_appointment!

    assert appointment.update_with_slot_protection(first_name: "JANET")
    appointment.reload
    assert_equal "JANET", appointment.first_name
    assert_equal "10:00", appointment.appointment_time.strftime("%H:%M")
  end

  test "requires dob by default" do
    appointment = Appointment.new(
      organization: @organization,
      service: @service,
      first_name: "JANE",
      last_name: "DOE",
      postcode: "N1 1AA",
      appointment_date: @appointment_date,
      appointment_time: @appointment_time,
      status: "booked"
    )

    assert_not appointment.valid?
    assert_includes appointment.errors[:dob], "can't be blank"
  end

  test "organization.kiosk_collect_dob false skips the dob presence validation" do
    @organization.update!(kiosk_collect_dob: false)
    appointment = Appointment.new(
      organization: @organization,
      service: @service,
      first_name: "JANE",
      last_name: "DOE",
      postcode: "N1 1AA",
      appointment_date: @appointment_date,
      appointment_time: @appointment_time,
      status: "booked"
    )

    assert appointment.valid?
  end

  test "check_in! carries a blank dob onto the created service request when the organization does not collect it" do
    @organization.update!(kiosk_collect_dob: false)
    appointment = create_appointment!(dob: nil)

    service_request = appointment.check_in!

    assert_nil service_request.dob
    assert service_request.persisted?
  end

  test "cancel! succeeds on a fresh instance with blank dob and postcode when the organization no longer requires them" do
    @organization.update!(kiosk_collect_dob: false, kiosk_collect_postcode: false)
    appointment = create_appointment!(dob: nil, postcode: nil)

    reloaded = Appointment.find(appointment.id)
    reloaded.cancel!

    assert_equal "cancelled", reloaded.status
  end

  test "mark_no_show! succeeds on a fresh instance with blank dob and postcode when the organization no longer requires them" do
    @organization.update!(kiosk_collect_dob: false, kiosk_collect_postcode: false)
    appointment = create_appointment!(dob: nil, postcode: nil)

    reloaded = Appointment.find(appointment.id)
    reloaded.mark_no_show!

    assert_equal "no_show", reloaded.status
  end

  test "revert_to_booked! returns a checked-in appointment to booked and cancels its waiting service request" do
    appointment = create_appointment!
    service_request = appointment.check_in!

    appointment.revert_to_booked!

    assert_equal "booked", appointment.status
    assert_nil appointment.checked_in_at
    assert_nil appointment.service_request_id
    assert_equal "cancelled", service_request.reload.status
  end

  test "revert_to_booked! detaches an already-cancelled service request without error" do
    appointment = create_appointment!
    service_request = appointment.check_in!
    service_request.cancel!

    appointment.revert_to_booked!

    assert_equal "booked", appointment.status
    assert_equal "cancelled", service_request.reload.status
  end

  test "revert_to_booked! raises when the linked service request is in progress" do
    appointment = create_appointment!
    service_request = appointment.check_in!
    service_request.call!

    assert_raises(Appointment::RevertNotAllowedError) { appointment.revert_to_booked! }
    assert_equal "checked_in", appointment.reload.status
  end

  test "revert_to_booked! raises when the linked service request is completed" do
    appointment = create_appointment!
    service_request = appointment.check_in!
    service_request.call!
    service_request.complete!

    assert_raises(Appointment::RevertNotAllowedError) { appointment.revert_to_booked! }
    assert_equal "checked_in", appointment.reload.status
  end

  test "revert_to_booked! works when there is no linked service request" do
    appointment = create_appointment!
    appointment.update!(status: "checked_in", checked_in_at: Time.current)

    appointment.revert_to_booked!

    assert_equal "booked", appointment.status
  end

  test "cannot book on a blocked date" do
    @organization.appointment_blocked_dates.create!(start_date: @appointment_date, reason: "Bank holiday")

    appointment = build_appointment

    assert_not appointment.valid?
    assert_includes appointment.errors[:appointment_date], "is not available (Bank holiday)"
  end

  test "openings mode rejects dates without openings and times outside them" do
    @organization.update!(appointment_booking_mode: "openings")
    @organization.appointment_openings.create!(
      start_date: @appointment_date, end_date: @appointment_date,
      bookable_times: { Organization.weekday_key(@appointment_date) => [ { "start" => "09:00", "end" => "09:30" } ] }
    )

    outside_time = build_appointment(appointment_time: Time.zone.parse("09:30"))
    other_date = build_appointment(appointment_date: @appointment_date + 1.day, appointment_time: Time.zone.parse("09:00"))
    inside = build_appointment(appointment_time: Time.zone.parse("09:15"))

    assert_includes outside_time.tap(&:valid?).errors[:appointment_time], "is outside the opening's bookable windows"
    assert_includes other_date.tap(&:valid?).errors[:appointment_date], "is not within an opening"
    assert inside.valid?
  end

  test "existing appointments stay editable after their date is blocked" do
    appointment = create_appointment!
    @organization.appointment_blocked_dates.create!(start_date: @appointment_date)

    assert appointment.update(notes: "Bring inhaler")
    assert_not appointment.update(appointment_time: Time.zone.parse("11:00"))
  end

  test "email is optional by default" do
    appt = create_appointment!(email: nil)

    assert appt.persisted?
  end

  test "email is required on new bookings when the organization requires it" do
    @organization.update!(require_appointment_email: true)

    appt = build_appointment(email: nil)

    assert_not appt.valid?
    assert_includes appt.errors[:email], "can't be blank"

    appt.email = "jane@example.com"
    assert appt.valid?
  end

  test "existing bookings without an email can still be changed after email becomes required" do
    appt = create_appointment!(email: nil)
    @organization.update!(require_appointment_email: true)
    appt.reload

    assert appt.update(notes: "Running late")
    appt.cancel!
    assert_equal "cancelled", appt.reload.status
  end

  test "clearing the email on an existing booking is rejected when email is required" do
    appt = create_appointment!(email: "jane@example.com")
    @organization.update!(require_appointment_email: true)

    assert_not appt.reload.update(email: "")
    assert_includes appt.errors[:email], "can't be blank"
  end

  test "cancel! stores a stripped cancellation reason" do
    appt = create_appointment!

    appt.cancel!(reason: "  Pharmacist unavailable  ")

    assert_equal "cancelled", appt.reload.status
    assert_equal "Pharmacist unavailable", appt.cancellation_reason
  end

  test "cancel! stores no reason when a blank one is given" do
    appt = create_appointment!

    appt.cancel!(reason: "   ")

    assert_nil appt.reload.cancellation_reason
  end

  test "redacting PII clears the cancellation reason" do
    appt = create_appointment!
    appt.cancel!(reason: "Customer asked to cancel")

    appt.redact_pii!

    assert_nil appt.reload.cancellation_reason
  end

  private

  def build_appointment(**attrs)
    Appointment.new(
      {
        organization: @organization,
        service: @service,
        first_name: "JANE",
        last_name: "DOE",
        dob: Date.new(1990, 1, 1),
        postcode: "N1 1AA",
        appointment_date: @appointment_date,
        appointment_time: @appointment_time,
        status: "booked"
      }.merge(attrs)
    )
  end

  def create_appointment!(**attrs)
    Appointment.create!(
      {
        organization: @organization,
        service: @service,
        first_name: "JANE",
        last_name: "DOE",
        dob: Date.new(1990, 1, 1),
        postcode: "N1 1AA",
        appointment_date: @appointment_date,
        appointment_time: @appointment_time,
        status: "booked"
      }.merge(attrs)
    )
  end
end
