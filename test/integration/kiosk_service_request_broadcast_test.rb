# frozen_string_literal: true

require "test_helper"

class KioskServiceRequestBroadcastTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

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

  test "kiosk create broadcasts to the organization queue stream" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_broadcasts("organization_#{@organization.id}_queue", 5) do
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
    end
  end

  test "kiosk create broadcasts to the waiting display stream" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_broadcasts("organization_#{@organization.id}_waiting_display", 3) do
        post kiosk_service_requests_path,
          params: {
            service_id: @service.id,
            service_request: {
              first_name: "jane",
              last_name: "doe",
              dob: "1985-03-20",
              postcode: "EC1A 1BB",
              privacy_requested: false
            }
          },
          as: :json
      end

      assert_response :success
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
