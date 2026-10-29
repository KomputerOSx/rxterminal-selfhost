# frozen_string_literal: true

require "test_helper"

class AppointmentCheckInServiceTest < ActiveSupport::TestCase
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
  end

  test "finds by booking reference" do
    appointment = create_appointment!

    found = AppointmentCheckInService.find_by_reference(@organization, appointment.booking_reference)

    assert_equal appointment, found
  end

  test "returns nil when booking reference is blank" do
    found = AppointmentCheckInService.find_by_reference(@organization, "")

    assert_nil found
  end

  test "finds candidates by last name and dob" do
    appointment = create_appointment!(first_name: "JANE", last_name: "DOE", dob: Date.new(1990, 1, 1))

    found = AppointmentCheckInService.find_candidates(organization: @organization, last_name: "doe", dob: Date.new(1990, 1, 1))

    assert_equal [ appointment ], found
  end

  test "does not match on last name alone when a dob is given but does not match" do
    create_appointment!(first_name: "JANE", last_name: "DOE", dob: Date.new(1990, 1, 1))

    found = AppointmentCheckInService.find_candidates(organization: @organization, last_name: "doe", dob: Date.new(1985, 5, 5))

    assert_empty found
  end

  test "falls back to last name only when dob is not provided" do
    @organization.update!(kiosk_collect_dob: false)
    appointment = create_appointment!(first_name: "JANE", last_name: "DOE", dob: nil)

    found = AppointmentCheckInService.find_candidates(organization: @organization, last_name: "doe", dob: nil)

    assert_equal [ appointment ], found
  end

  test "returns all matching appointments when multiple people share a last name" do
    earlier = create_appointment!(
      first_name: "JANE", last_name: "DOE", dob: Date.new(1990, 1, 1),
      appointment_date: Date.current + 1.day, appointment_time: Time.zone.parse("09:00")
    )
    later = create_appointment!(
      first_name: "JOHN", last_name: "DOE", dob: Date.new(1985, 5, 5),
      appointment_date: Date.current + 1.day, appointment_time: Time.zone.parse("10:00")
    )

    found = AppointmentCheckInService.find_candidates(organization: @organization, last_name: "doe")

    assert_equal [ earlier, later ], found
  end

  test "returns empty array when last name is blank" do
    create_appointment!

    found = AppointmentCheckInService.find_candidates(organization: @organization, last_name: "")

    assert_empty found
  end

  test "excludes appointments that are already checked in" do
    booked = create_appointment!(first_name: "JANE", last_name: "DOE")
    already_in = create_appointment!(first_name: "JOHN", last_name: "DOE", appointment_time: Time.zone.parse("11:00"))
    already_in.check_in!

    found = AppointmentCheckInService.find_candidates(organization: @organization, last_name: "doe")

    assert_equal [ booked ], found
  end

  private

  def create_appointment!(**attrs)
    Appointment.create!(
      {
        organization: @organization,
        service: @service,
        first_name: "JANE",
        last_name: "DOE",
        dob: Date.new(1990, 1, 1),
        postcode: "N1 1AA",
        appointment_date: Date.current + 1.day,
        appointment_time: Time.zone.parse("10:00"),
        status: "booked"
      }.merge(attrs)
    )
  end
end
