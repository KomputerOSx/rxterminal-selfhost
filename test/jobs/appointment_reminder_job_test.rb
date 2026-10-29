# frozen_string_literal: true

require "test_helper"

class AppointmentReminderJobTest < ActiveJob::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "reminder_svc_#{Time.current.to_i}",
      display_name: "Reminder Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: @calendar
    )
  end

  test "sends reminders for booked appointments 2 days out with email" do
    reminder_date = Date.current + 2.days
    Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      email: "jane@example.com",
      appointment_date: reminder_date,
      appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )
    Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "No",
      last_name: "Email",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      appointment_date: reminder_date,
      appointment_time: Time.zone.parse("11:00"),
      status: "booked"
    )

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      AppointmentReminderJob.perform_now
    end
  end

  test "does not send reminders for appointments on other dates" do
    Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      email: "jane@example.com",
      appointment_date: Date.current + 1.day,
      appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )
    Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "John",
      last_name: "Smith",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      email: "john@example.com",
      appointment_date: Date.current + 3.days,
      appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )

    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      AppointmentReminderJob.perform_now
    end
  end
end
