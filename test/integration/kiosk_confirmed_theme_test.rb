# frozen_string_literal: true

require "test_helper"

class KioskConfirmedThemeTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @organization.update!(
      kiosk_theme: "custom",
      kiosk_theme_custom: {
        "success" => "#ff0000",
        "success_content" => "#ffffff",
        "warning" => "#0000ff",
        "warning_content" => "#ffffff"
      }
    )

    @api_key = SecureRandom.hex(32)
    @device = @organization.devices.create!(
      device_id: "lobby_kiosk_confirmed",
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

    authenticate_kiosk!
  end

  test "queue confirmed screen uses locked markup not theme utilities" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
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

      assert_response :success
      body = JSON.parse(response.body)

      get body["redirect_to"]
      assert_response :success
      assert_match "kiosk-confirmed-page", response.body
      assert_no_match(/\bbg-success\b/, response.body)
    end
  end

  test "upsell confirmed screen uses locked markup not theme utilities" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      seed_upsell_rule!
      create_walk_in_for_upsell!

      post kiosk_decline_upsell_path
      follow_redirect!

      assert_response :success
      assert_match "kiosk-confirmed-page", response.body
      assert_no_match(/\bbg-success\b/, response.body)
    end
  end

  test "appointment confirmation screen uses locked markup not theme utilities" do
    appointment_service = @organization.services.create!(
      internal_name: "bp_appt",
      display_name: "Blood pressure check",
      estimated_duration: 15,
      active: true,
      display_order: 1,
      requires_appointment: true,
      allows_immediate: false
    )

    appointment_date = Date.current + 3.days
    while appointment_date.saturday? || appointment_date.sunday?
      appointment_date += 1.day
    end

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post kiosk_appointments_path,
        params: {
          appointment: {
            service_id: appointment_service.id,
            first_name: "jane",
            last_name: "doe",
            dob: "1985-03-20",
            postcode: "SW1A 1AA",
            appointment_date: appointment_date.iso8601,
            appointment_time: "10:00"
          }
        },
        as: :json

      body = JSON.parse(response.body)
      get body["redirect_to"]

      assert_response :success
      assert_match "kiosk-appointment-confirmed-page", response.body
      assert_no_match(/\bbg-warning\b/, response.body)
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

  def seed_upsell_rule!
    @suggested = @organization.services.create!(
      internal_name: "blood_pressure",
      display_name: "Blood pressure check",
      estimated_duration: 10,
      active: true,
      allows_immediate: true,
      icon: "monitor_heart"
    )

    @rule = @organization.upsell_rules.create!(
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

  def create_walk_in_for_upsell!
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
