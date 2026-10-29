# frozen_string_literal: true

require "test_helper"

class KioskSearchTest < ActionDispatch::IntegrationTest
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

    @flu_service = @organization.services.create!(
      internal_name: "flu_vax",
      display_name: "Flu vaccination",
      estimated_duration: 15,
      active: true,
      display_order: 0,
      allows_immediate: true
    )

    @bp_service = @organization.services.create!(
      internal_name: "blood_pressure",
      display_name: "Blood pressure check",
      estimated_duration: 10,
      active: true,
      display_order: 1,
      allows_immediate: true
    )

    authenticate_kiosk!
  end

  test "search page renders shell and keyboard" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get kiosk_search_services_path
      assert_response :success
      assert_match "kiosk-search-shell", response.body
      assert_match "Find a Service", response.body
      assert_match "btn btn-lg kiosk-keyboard-key", response.body
      assert_match "What would you like to find today?", response.body
    end
  end

  test "query filtering returns matching service" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get kiosk_search_services_path, params: { q: "flu" }
      assert_response :success
      assert_match @flu_service.display_name, response.body
      assert_no_match @bp_service.display_name, response.body
      assert_match "1 service found", response.body
    end
  end

  test "nonsense query shows no results message" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get kiosk_search_services_path, params: { q: "!!!" }
      assert_response :success
      assert_match "Nothing found", response.body
      assert_no_match @flu_service.display_name, response.body
      assert_no_match @bp_service.display_name, response.body
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
