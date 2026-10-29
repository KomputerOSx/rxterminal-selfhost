# frozen_string_literal: true

require "test_helper"

class KioskServiceRequestTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @api_key = SecureRandom.hex(32)
    @device = @organization.devices.create!(
      device_id: "lobby_kiosk",
      name: "Lobby",
      api_key: @api_key,
      status: "active"
    )

    @service = @organization.services.create!(
      internal_name: "flu_vax",
      display_name: "Flu vaccination",
      estimated_duration: 15,
      active: true,
      display_order: 0
    )

    authenticate_kiosk!
  end

  test "POST creates service request and returns redirect_to" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { ServiceRequest.count }, 1 do
        post kiosk_service_requests_path,
          params: {
            service_id: @service.id,
            service_request: {
              first_name: "john",
              last_name: "smith",
              dob: "1990-05-15",
              postcode: "SW1A 1AA",
              privacy_requested: false
            }
          },
          as: :json
      end

      assert_response :success

      body = JSON.parse(response.body)
      assert body["redirect_to"].present? || body["queue_number"].present?

      service_request = ServiceRequest.last
      assert_equal @organization, service_request.organization
      assert_equal @service, service_request.service
      assert_equal "JOHN", service_request.first_name
      assert_equal "SMITH", service_request.last_name
      assert_equal "waiting", service_request.status
      assert service_request.queue_number.present?
    end
  end

  test "new walk-in wizard renders for authenticated kiosk" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get kiosk_new_service_request_path(service_id: @service.id)
      assert_response :success
      assert_match "kiosk-service-request", response.body
      assert_match @service.display_name, response.body
    end
  end

  test "create returns 422 with validation errors" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_no_difference -> { ServiceRequest.count } do
        post kiosk_service_requests_path,
          params: {
            service_id: @service.id,
            service_request: {
              first_name: "",
              last_name: "",
              dob: "1990-05-15"
            }
          },
          as: :json
      end

      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert body["errors"].is_a?(Array)
      assert body["errors"].any?
    end
  end

  private

  def authenticate_kiosk!
    post kiosk_setup_configure_path, params: {
      device_id: @device.device_id,
      api_key: @api_key
    }
    post kiosk_setup_authenticate_path
    follow_redirect!
  end
end
