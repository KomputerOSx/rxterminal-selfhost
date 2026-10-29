# frozen_string_literal: true

require "test_helper"

class KioskSetupTest < ActionDispatch::IntegrationTest
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

    @organization.update!(
      kiosk_show_featured_service: true,
      kiosk_show_services: true,
      kiosk_show_appointments: true,
      kiosk_featured_service_id: @service.id
    )
  end

  test "setup page is reachable without authentication" do
    get kiosk_setup_path
    assert_response :success
    assert_match "Kiosk Setup", response.body
    assert_match "rx-terminal-brand", response.body
    assert_no_match "Windtunnel", response.body
  end

  test "configured but unauthenticated setup page renders a working reconfigure confirmation" do
    post kiosk_setup_configure_path, params: {
      device_id: @device.device_id,
      api_key: @api_key
    }

    get kiosk_setup_path
    assert_response :success
    assert_match "Reconfigure Device", response.body
    assert_match 'data-controller="confirm-modal"', response.body
    assert_no_match "turbo_confirm", response.body
    assert_no_match "data-turbo-confirm", response.body
    assert_match 'id="confirm-modal"', response.body
  end

  test "configure saves credentials and authenticate opens kiosk home" do
    post kiosk_setup_configure_path, params: {
      device_id: @device.device_id,
      api_key: @api_key
    }
    assert_redirected_to kiosk_setup_path

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post kiosk_setup_authenticate_path
      assert_redirected_to kiosk_root_path
      follow_redirect!
      assert_response :success
      assert_match @organization.name, response.body
      assert_match "Browse Services", response.body
    end
  end

  test "kiosk home requires authentication" do
    get kiosk_root_path
    assert_redirected_to kiosk_setup_path
  end

  test "authenticated kiosk can browse services" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      authenticate_kiosk!

      get kiosk_services_path
      assert_response :success
      assert_match @service.display_name, response.body
      assert_match "kiosk-services-shell", response.body
      assert_match "kiosk-service-card", response.body
      assert_match "Select a service to get started", response.body
    end
  end

  test "invalid api key is rejected during authenticate" do
    post kiosk_setup_configure_path, params: {
      device_id: @device.device_id,
      api_key: "wrong-key"
    }

    assert_no_difference -> { AuditLog.where(event_type: :device_auth_success).count } do
      assert_difference -> { AuditLog.where(event_type: :device_auth_failure).count }, 1 do
        post kiosk_setup_authenticate_path
      end
    end

    assert_redirected_to kiosk_setup_path
    assert_match /Invalid API key/, flash[:alert]
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
