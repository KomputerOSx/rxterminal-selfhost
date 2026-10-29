# frozen_string_literal: true

require "test_helper"

class CustomerPiiLookupTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @other_organization = Organization.create_personal_for!(users(:two))
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "lookup_svc_#{Time.current.to_i}",
      display_name: "Lookup Service",
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
      status: "waiting",
      request_type: "immediate",
      queue_number: "1",
      queue_date: Date.current
    )
  end

  test "finds records by first name, last name, and dob" do
    result = CustomerPiiLookup.new(
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15)
    ).call

    assert_includes result.appointments, @appointment
    assert_includes result.service_requests, @service_request
  end

  test "matches names case insensitively" do
    @appointment.update!(first_name: "JANE", last_name: "DOE")
    @service_request.update!(first_name: "JANE", last_name: "DOE")

    result = CustomerPiiLookup.new(
      first_name: "jane",
      last_name: "doe",
      dob: Date.new(1990, 5, 15)
    ).call

    assert_includes result.appointments, @appointment
    assert_includes result.service_requests, @service_request
  end

  test "matches when stored names are uppercase and query uses mixed case" do
    @appointment.update!(first_name: "JANE", last_name: "DOE")
    @service_request.update!(first_name: "JANE", last_name: "DOE")

    result = CustomerPiiLookup.new(
      first_name: "JaNe",
      last_name: "DoE",
      dob: Date.new(1990, 5, 15)
    ).call

    assert_includes result.appointments, @appointment
    assert_includes result.service_requests, @service_request
  end

  test "does not match when first name differs" do
    result = CustomerPiiLookup.new(
      first_name: "John",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15)
    ).call

    assert_empty result.appointments
    assert_empty result.service_requests
  end

  test "narrows results when postcode is provided" do
    @appointment.update!(postcode: "N1 1AA")
    @service_request.update!(postcode: "E1 1AA")

    result = CustomerPiiLookup.new(
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA"
    ).call

    assert_includes result.appointments, @appointment
    assert_not_includes result.service_requests, @service_request
  end

  test "scopes to multiple organizations when provided" do
    other_calendar = @other_organization.calendars.find_by!(is_default: true)
    other_service = @other_organization.services.create!(
      internal_name: "other_lookup_svc",
      display_name: "Other Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: other_calendar
    )
    other_appointment = Appointment.create!(
      organization: @other_organization,
      service: other_service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15),
      postcode: "E1 1AA",
      appointment_date: Date.current + 2.days,
      appointment_time: Time.zone.parse("11:00"),
      status: "booked"
    )

    result = CustomerPiiLookup.new(
      organization_ids: [ @organization.id, @other_organization.id ],
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15)
    ).call

    assert_includes result.appointments, @appointment
    assert_includes result.appointments, other_appointment
  end

  test "scopes to organization when provided" do
    other_calendar = @other_organization.calendars.find_by!(is_default: true)
    other_service = @other_organization.services.create!(
      internal_name: "other_lookup_svc",
      display_name: "Other Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: other_calendar
    )
    other_appointment = Appointment.create!(
      organization: @other_organization,
      service: other_service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15),
      postcode: "E1 1AA",
      appointment_date: Date.current + 2.days,
      appointment_time: Time.zone.parse("11:00"),
      status: "booked"
    )

    result = CustomerPiiLookup.new(
      organization_ids: [ @organization.id ],
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15)
    ).call

    assert_includes result.appointments, @appointment
    assert_not_includes result.appointments, other_appointment
  end

  test "returns empty result when no dob is given and no organization is selected" do
    result = CustomerPiiLookup.new(first_name: "Jane", last_name: "Doe").call

    assert_empty result.appointments
    assert_empty result.service_requests
  end

  test "finds records by name only when scoped to an organization and no dob is given" do
    result = CustomerPiiLookup.new(
      organization_ids: [ @organization.id ],
      first_name: "Jane",
      last_name: "Doe"
    ).call

    assert_includes result.appointments, @appointment
    assert_includes result.service_requests, @service_request
  end

  test "includes linked service request for checked-in appointment" do
    @appointment.update!(service_request: @service_request, status: "checked_in", checked_in_at: Time.current)

    result = CustomerPiiLookup.new(
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15)
    ).call

    assert_includes result.appointments, @appointment
    assert_includes result.service_requests, @service_request
  end
end
