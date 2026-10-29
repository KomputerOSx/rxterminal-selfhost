# frozen_string_literal: true

require "test_helper"

class KioskPreviewTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "flu_vax",
      display_name: "Flu vaccination",
      estimated_duration: 15,
      active: true,
      display_order: 0,
      allows_immediate: true
    )

    post login_path, params: { email: @owner.email, password: "password123" }
  end

  test "staff can enter and exit full kiosk preview" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get preview_org_kiosk_path
      assert_redirected_to kiosk_root_path

      follow_redirect!
      assert_response :success
      assert_match "Kiosk preview", response.body
      assert_match "Exit preview", response.body

      delete exit_preview_org_kiosk_path
      assert_redirected_to org_kiosk_path
    end
  end

  test "preview walk-in submission does not create a service request" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get preview_org_kiosk_path
      follow_redirect!

      assert_no_difference -> { ServiceRequest.count } do
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

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal kiosk_confirmed_upsell_path, body["redirect_to"]
    end
  end

  test "preview walk-in can reach upsell when a rule matches" do
    suggested = @organization.services.create!(
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
      suggested_service: suggested,
      frequency_type: "percentage_based",
      frequency_value: 100,
      visit_type: "any",
      cooldown_days: 0,
      active: true,
      upsell_templates_attributes: [
        { title: "Free BP check", cta_text: "Add blood pressure check" }
      ]
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get preview_org_kiosk_path
      follow_redirect!

      assert_no_difference -> { ServiceRequest.count } do
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

      body = JSON.parse(response.body)
      assert_equal kiosk_upsell_path, body["redirect_to"]

      get kiosk_upsell_path
      assert_response :success
      assert_match "Free BP check", response.body

      assert_no_difference -> { UpsellInteraction.count } do
        post kiosk_decline_upsell_path
      end

      assert_redirected_to kiosk_confirmed_upsell_path
    end
  end
end
