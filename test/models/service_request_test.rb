# frozen_string_literal: true

require "test_helper"

class ServiceRequestTest < ActiveSupport::TestCase
  setup do
    @ts = "#{Time.current.to_i}#{rand(9999)}"
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "walk_in_svc_#{@ts}",
      display_name: "Walk-in Service",
      estimated_duration: 15,
      allows_immediate: true,
      active: true,
      calendar: @calendar
    )
  end

  test "requires dob by default" do
    service_request = build_service_request(dob: nil)

    assert_not service_request.valid?
    assert_includes service_request.errors[:dob], "can't be blank"
  end

  test "organization.kiosk_collect_dob false skips the dob presence validation" do
    @organization.update!(kiosk_collect_dob: false)
    service_request = build_service_request(dob: nil)

    assert service_request.valid?
  end

  private

  def build_service_request(**attrs)
    ServiceRequest.new(
      {
        organization: @organization,
        service: @service,
        first_name: "JANE",
        last_name: "DOE",
        dob: Date.new(1990, 1, 1),
        postcode: "N1 1AA",
        status: "waiting",
        request_type: "immediate",
        queue_number: "1",
        queue_date: Date.current
      }.merge(attrs)
    )
  end
end
