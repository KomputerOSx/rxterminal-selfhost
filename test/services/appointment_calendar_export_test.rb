# frozen_string_literal: true

require "test_helper"

class AppointmentCalendarExportTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @organization.update!(name: "Test Pharmacy")
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "ics_svc_#{Time.current.to_i}",
      display_name: "Flu Jab",
      estimated_duration: 30,
      requires_appointment: true,
      active: true,
      calendar: @calendar
    )
    @appointment = Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      appointment_date: Date.current + 5.days,
      appointment_time: Time.zone.parse("14:30"),
      status: "booked"
    )
  end

  test "generates valid ICS content" do
    ics = AppointmentCalendarExport.generate(@appointment)
    assert_match "BEGIN:VCALENDAR", ics
    assert_match "BEGIN:VEVENT", ics
    assert_match @appointment.booking_reference, ics
    assert_match "Flu Jab at Test Pharmacy", ics
  end

  test "filename includes booking reference" do
    assert_equal "appointment-#{@appointment.booking_reference}.ics",
      AppointmentCalendarExport.filename(@appointment)
  end
end
