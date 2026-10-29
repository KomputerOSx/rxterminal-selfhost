require "test_helper"

class Notifications::Rules::AppointmentBookedOnlineTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create_personal_for!(users(:one))
    calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "flu_jab", display_name: "Flu jab",
      estimated_duration: 15, requires_appointment: true, active: true, calendar: calendar
    )
    @appointment = Appointment.create!(
      organization: @organization, service: @service,
      first_name: "JANE", last_name: "DOE", dob: Date.new(1990, 1, 1), postcode: "N1 1AA",
      appointment_date: Date.current + 1.day, appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )
  end

  test "recipients is the organization's owners" do
    rule = Notifications::Rules::AppointmentBookedOnline.new(
      actor: nil, resource: @appointment, organization: @organization,
      metadata: { "booking_reference" => @appointment.booking_reference, "service" => @service.display_name, "date" => @appointment.appointment_date.to_s }
    )

    assert_equal [ users(:one) ], rule.recipients.to_a
  end

  test "channels is in_app only" do
    assert_equal [ :in_app ], Notifications::Rules::AppointmentBookedOnline.channels
  end

  test "body includes the service, date, and booking reference but not the customer's name" do
    rule = Notifications::Rules::AppointmentBookedOnline.new(
      actor: nil, resource: @appointment, organization: @organization,
      metadata: { "booking_reference" => @appointment.booking_reference, "service" => @service.display_name, "date" => @appointment.appointment_date.to_s }
    )

    assert_includes rule.body, @service.display_name
    assert_includes rule.body, @appointment.appointment_date.to_s
    assert_includes rule.body, @appointment.booking_reference
    assert_not_includes rule.body, "JANE"
  end

  test "url links to the appointment" do
    rule = Notifications::Rules::AppointmentBookedOnline.new(
      actor: nil, resource: @appointment, organization: @organization, metadata: {}
    )

    assert_equal "/org/appointments/#{@appointment.id}", rule.url
  end
end
