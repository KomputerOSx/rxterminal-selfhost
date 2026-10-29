# frozen_string_literal: true

require "test_helper"

class OrgQueueLiveSyncTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "consultation",
      display_name: "Consultation",
      estimated_duration: 15,
      active: true
    )
  end

  test "creating a service request broadcasts to the queue stream" do
    assert_broadcasts("organization_#{@organization.id}_queue", 5) do
      ServiceRequest.create!(
        organization: @organization,
        service: @service,
        first_name: "Jane",
        last_name: "Doe",
        dob: Date.new(1990, 1, 15),
        postcode: "SW1A 1AA",
        status: "waiting",
        request_type: "immediate",
        queue_number: "1",
        queue_date: Date.current
      )
    end
  end

  test "creating a service request broadcasts to the waiting display stream" do
    assert_broadcasts("organization_#{@organization.id}_waiting_display", 3) do
      ServiceRequest.create!(
        organization: @organization,
        service: @service,
        first_name: "Jane",
        last_name: "Doe",
        dob: Date.new(1990, 1, 15),
        postcode: "SW1A 1AA",
        status: "waiting",
        request_type: "immediate",
        queue_number: "1",
        queue_date: Date.current
      )
    end
  end

  test "updating a service request status broadcasts to the queue stream" do
    request = ServiceRequest.create!(
      organization: @organization,
      service: @service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 1, 15),
      postcode: "SW1A 1AA",
      status: "waiting",
      request_type: "immediate",
      queue_number: "1",
      queue_date: Date.current
    )

    assert_broadcasts("organization_#{@organization.id}_queue", 6) do
      request.update!(status: "in_progress", called_at: Time.current)
    end
  end
end
