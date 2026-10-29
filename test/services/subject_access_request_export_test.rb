# frozen_string_literal: true

require "test_helper"

class SubjectAccessRequestExportTest < ActiveSupport::TestCase
  setup do
    owner = users(:one)
    @organization = Organization.create_personal_for!(owner)
    calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "csv_export_svc",
      display_name: "CSV Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: calendar
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
      status: "waiting",
      request_type: "immediate",
      queue_number: "1",
      queue_date: Date.current,
      submission_ip: "203.0.113.5"
    )
    @results = CustomerPiiLookup::Result.new(
      appointments: [ @appointment ],
      service_requests: [ @service_request ]
    )
  end

  test "to_csv includes metadata, appointments, and service requests" do
    csv = SubjectAccessRequestExport.to_csv(
      @results,
      search_criteria: { first_name: "Jane", last_name: "Doe" }
    )
    rows = CSV.parse(csv)

    assert_equal [ "exported_at" ], rows[0][0, 1]
    assert_equal [ "first_name", "Jane" ], rows[1]
    assert_includes rows.flatten, "Appointments"
    assert_includes rows.flatten, "Service requests"
    assert_includes rows.flatten, @appointment.booking_reference
    assert_includes rows.flatten, @service_request.queue_number
  end

  test "to_csv includes the service request's submitted IP" do
    csv = SubjectAccessRequestExport.to_csv(
      @results,
      search_criteria: { first_name: "Jane", last_name: "Doe" }
    )
    rows = CSV.parse(csv)
    flat = rows.flatten

    assert_includes flat, "submission_ip"
    assert_includes flat, "203.0.113.5"
  end
end
