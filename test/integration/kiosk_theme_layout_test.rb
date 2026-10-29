# frozen_string_literal: true

require "test_helper"

class KioskThemeLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @organization.update!(kiosk_theme: "kiosk-pastel")
    @api_key = SecureRandom.hex(32)
    @device = @organization.devices.create!(
      device_id: "theme_kiosk",
      name: "Theme kiosk",
      api_key: @api_key,
      status: "active"
    )

    authenticate_kiosk!
  end

  test "kiosk layout uses organization theme and does not read staff localStorage theme" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get kiosk_root_path

      assert_response :success
      assert_match 'data-theme="kiosk-pastel"', response.body
      assert_no_match 'localStorage.getItem("theme")', response.body
    end
  end

  test "radius overrides apply on kiosk layout for preset themes" do
    @organization.update!(kiosk_theme_custom: { "radius_box" => "1.5rem" })

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get kiosk_root_path

      assert_response :success
      assert_match "--radius-box: 1.5rem;", response.body
    end
  end

  test "custom kiosk theme applies inline css variables" do
    @organization.update!(
      kiosk_theme: "custom",
      kiosk_theme_custom: {
        "primary" => "#445566",
        "base_100" => "#fafafa",
        "upsell_bg" => "#112233"
      }
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get kiosk_root_path

      assert_response :success
      assert_match 'data-theme="kiosk-custom"', response.body
      assert_match "--color-primary: #445566;", response.body
      assert_match "--color-base-100: #fafafa;", response.body
      assert_match "--color-upsell-bg: #112233;", response.body
    end
  end

  test "new kiosk theme preset resolves on layout" do
    @organization.update!(kiosk_theme: "kiosk-acid")

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get kiosk_root_path

      assert_response :success
      assert_match 'data-theme="kiosk-acid"', response.body
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
