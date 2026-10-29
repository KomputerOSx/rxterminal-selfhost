# frozen_string_literal: true

require "test_helper"

class AppointmentNoShowJobTest < ActiveJob::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "noshow_svc_#{Time.current.to_i}",
      display_name: "No-show Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: @calendar
    )
  end

  test "marks past booked appointments as no_show" do
    past = Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "Past",
      last_name: "Guest",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      appointment_date: Date.current + 1.day,
      appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )
    past.update_columns(appointment_date: Date.current - 1.day)

    future = Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "Future",
      last_name: "Guest",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      appointment_date: Date.current + 1.day,
      appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )

    AppointmentNoShowJob.perform_now

    assert_equal "no_show", past.reload.status
    assert past.no_show_at.present?
    assert_equal "booked", future.reload.status
  end
end
