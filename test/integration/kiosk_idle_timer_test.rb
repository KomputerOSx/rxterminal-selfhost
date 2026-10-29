# frozen_string_literal: true

require "test_helper"

class KioskIdleTimerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @api_key = SecureRandom.hex(32)
    @device = @organization.devices.create!(
      device_id: "lobby_kiosk_idle",
      name: "Lobby",
      api_key: @api_key,
      status: "active"
    )

    @service = @organization.services.create!(
      internal_name: "flu_vax",
      display_name: "Flu vaccination",
      estimated_duration: 15,
      active: true,
      display_order: 0,
      allows_immediate: true
    )
  end

  test "interactive kiosk pages include overlay idle timer" do
    with_authenticated_kiosk do
    get kiosk_services_path
    assert_response :success
    assert_match "idle-countdown-overlay", response.body
    assert_match 'data-kiosk-idle-mode-value="overlay"', response.body
    assert_match "idle:cancel", response.body
    end
  end

  test "upsell page includes auto-submit idle timer for decline" do
    with_authenticated_kiosk do
    seed_upsell_rule!
    create_walk_in!

    get kiosk_upsell_path
    assert_response :success
    assert_match 'data-kiosk-idle-mode-value="auto-submit"', response.body
    assert_match "data-kiosk-idle-form-selector-value", response.body
    assert_match "decline", response.body
    end
  end

  test "confirmed pages include auto-redirect idle timer" do
    with_authenticated_kiosk do
    post kiosk_service_requests_path,
      params: {
        service_id: @service.id,
        service_request: {
          first_name: "jane",
          last_name: "doe",
          dob: "1985-05-20",
          postcode: "SW1A 2AA",
          privacy_requested: false
        }
      },
      as: :json

    get JSON.parse(response.body)["redirect_to"]
    assert_match 'data-kiosk-idle-mode-value="auto-redirect"', response.body
    assert_match "countdownText", response.body
    end
  end

  test "home screen has no idle timer" do
    with_authenticated_kiosk do
    get kiosk_root_path
    assert_response :success
    assert_no_match 'data-controller="kiosk-idle"', response.body
    end
  end

  private

  def with_authenticated_kiosk
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      authenticate_kiosk!
      yield
    end
  end

  def authenticate_kiosk!
    post kiosk_setup_configure_path, params: {
      device_id: @device.device_id,
      api_key: @api_key
    }
    post kiosk_setup_authenticate_path
    follow_redirect!
  end

  def seed_upsell_rule!
    @suggested = @organization.services.create!(
      internal_name: "blood_pressure",
      display_name: "Blood pressure check",
      estimated_duration: 10,
      active: true,
      allows_immediate: true,
      icon: "monitor_heart"
    )

    @organization.upsell_rules.create!(
      name: "Flu to BP",
      trigger_service: @service,
      suggested_service: @suggested,
      frequency_type: "every_nth_customer",
      frequency_value: 2,
      visit_type: "any",
      cooldown_days: 0,
      active: true,
      upsell_templates_attributes: [
        {
          title: "Free BP check",
          description: "Quick check while you wait.",
          cta_text: "Add blood pressure check"
        }
      ]
    )
  end

  def create_walk_in!
    post kiosk_service_requests_path,
      params: {
        service_id: @service.id,
        service_request: {
          first_name: "jane",
          last_name: "doe",
          dob: "1985-05-20",
          postcode: "SW1A 2AA",
          privacy_requested: false
        }
      },
      as: :json
  end
end
