# frozen_string_literal: true

require "test_helper"

class DataRetentionJobTest < ActiveJob::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "retention_svc_#{Time.current.to_i}",
      display_name: "Retention Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: @calendar
    )
  end

  test "redacts adult appointments older than 90 days" do
    appointment = Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "Old",
      last_name: "Adult",
      dob: Date.new(1980, 1, 1),
      postcode: "N1 1AA",
      email: "old@example.com",
      appointment_date: Date.current + 1.day,
      appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )
    appointment.update_columns(created_at: 91.days.ago, updated_at: 91.days.ago, appointment_date: Date.current - 10.days)

    DataRetentionJob.perform_now

    appointment.reload
    assert appointment.pii_redacted?
    assert_equal "REDACTED", appointment.first_name
    assert_nil appointment.email
  end

  test "redacts service requests older than 90 days" do
    service_request = ServiceRequest.create!(
      organization: @organization,
      service: @service,
      first_name: "Old",
      last_name: "Patient",
      dob: Date.new(1980, 1, 1),
      postcode: "N1 1AA",
      description: "Needs help",
      status: "completed",
      request_type: "immediate",
      queue_number: "1",
      queue_date: Date.current - 100.days
    )
    service_request.update_columns(created_at: 91.days.ago, updated_at: 91.days.ago)

    DataRetentionJob.perform_now

    service_request.reload
    assert service_request.pii_redacted?
    assert_equal "REDACTED", service_request.first_name
  end

  test "does not redact recent records" do
    appointment = Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "Recent",
      last_name: "Adult",
      dob: Date.new(1980, 1, 1),
      postcode: "N1 1AA",
      appointment_date: Date.current + 1.day,
      appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )

    DataRetentionJob.perform_now

    refute appointment.reload.pii_redacted?
  end
end
