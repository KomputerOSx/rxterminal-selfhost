# frozen_string_literal: true

require "test_helper"

class CustomerPiiRedactionTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "redact_svc_#{Time.current.to_i}",
      display_name: "Redact Service",
      estimated_duration: 15,
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
      email: "jane.doe@example.com",
      appointment_date: Date.current + 2.days,
      appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )
    @service_request = ServiceRequest.create!(
      organization: @organization,
      service: @service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      description: "Needs help",
      status: "waiting",
      request_type: "immediate",
      queue_number: "1",
      queue_date: Date.current
    )
  end

  test "redacts selected appointment and service request" do
    result = CustomerPiiRedaction.call(
      appointment_ids: [ @appointment.id ],
      service_request_ids: [ @service_request.id ]
    )

    assert_equal 1, result.appointments.size
    assert_equal 1, result.service_requests.size

    @appointment.reload
    @service_request.reload

    assert_equal "REDACTED", @appointment.first_name
    assert_equal "REDACTED", @appointment.last_name
    assert_nil @appointment.email
    assert @appointment.pii_redacted_at.present?

    assert_equal "REDACTED", @service_request.first_name
    assert_nil @service_request.description
    assert @service_request.pii_redacted_at.present?
  end
end
