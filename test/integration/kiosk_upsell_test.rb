# frozen_string_literal: true

require "test_helper"

class KioskUpsellTest < ActionDispatch::IntegrationTest
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
      display_order: 0,
      allows_immediate: true
    )
  end

  test "create redirects to upsell when rule matches" do
    with_authenticated_kiosk do
    seed_upsell_rule!

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
    assert_equal kiosk_upsell_path, body["redirect_to"]
    end
  end

  test "upsell show renders selected A/B variant" do
    with_authenticated_kiosk do
    seed_upsell_rule_with_variants!
    template_b = @rule.upsell_templates.order(:id).last
    UpsellEngine.stub(:select_template, template_b) do
      create_walk_in_for_upsell!
    end

    get kiosk_upsell_path
    assert_response :success
    assert_match "Better BP offer", response.body
    assert_match "Add better check", response.body
    refute_match "Free BP check", response.body
    end
  end

  test "upsell decline records the selected template on interaction" do
    with_authenticated_kiosk do
    seed_upsell_rule_with_variants!
    template_b = @rule.upsell_templates.order(:id).last
    UpsellEngine.stub(:select_template, template_b) do
      create_walk_in_for_upsell!
    end

    assert_difference -> { UpsellInteraction.count }, 1 do
      post kiosk_decline_upsell_path
    end

    interaction = UpsellInteraction.order(:created_at).last
    assert_equal template_b, interaction.upsell_template
    assert_equal "declined", interaction.outcome
    end
  end

  test "upsell show renders offer" do
    with_authenticated_kiosk do
    seed_upsell_rule!
    create_walk_in_for_upsell!

    get kiosk_upsell_path
    assert_response :success
    assert_match "One more thing", response.body
    assert_match "Free BP check", response.body
    assert_match "kiosk-upsell", response.body
    assert_match "Add blood pressure check", response.body
    end
  end

  test "upsell accept creates second service request and shows both queue numbers" do
    with_authenticated_kiosk do
    seed_upsell_rule!
    create_walk_in_for_upsell!

    assert_difference -> { ServiceRequest.count }, 1 do
      post kiosk_accept_upsell_path
    end

    assert_redirected_to kiosk_confirmed_upsell_path
    follow_redirect!
    assert_match "Request Confirmed!", response.body
    assert_match "Flu vaccination", response.body
    assert_match "Blood pressure check", response.body
    end
  end

  test "upsell decline returns to confirmed with one queue number" do
    with_authenticated_kiosk do
    seed_upsell_rule!
    create_walk_in_for_upsell!

    assert_no_difference -> { ServiceRequest.count } do
      post kiosk_decline_upsell_path
    end

    assert_redirected_to kiosk_confirmed_upsell_path
    follow_redirect!
    assert_match "Request Confirmed!", response.body
    assert_match "Flu vaccination", response.body
    end
  end

  test "upsell book later can be cancelled back to queue confirmation" do
    with_authenticated_kiosk do
    seed_upsell_rule!(requires_appointment: true)
    original_request = create_walk_in_for_upsell!

    post kiosk_book_later_upsell_path
    assert_redirected_to kiosk_new_appointment_path(service_id: @suggested.id)

    follow_redirect!
    assert_match cancel_upsell_booking_kiosk_appointments_path, response.body

    assert_no_difference -> { Appointment.count } do
      post cancel_upsell_booking_kiosk_appointments_path
    end

    assert_redirected_to kiosk_confirmed_upsell_path
    follow_redirect!
    assert_match "Request Confirmed!", response.body
    assert_match original_request.queue_number.to_s, response.body
    assert_match @service.display_name, response.body

    get kiosk_new_appointment_path(service_id: @suggested.id)
    assert_response :success
    refute_match 'data-kiosk-appointment-upsell-booking-value="true"', response.body
    end
  end

  test "upsell book later shows queue number and booking reference after appointment" do
    with_authenticated_kiosk do
    seed_upsell_rule!(requires_appointment: true)
    original_request = create_walk_in_for_upsell!

    post kiosk_book_later_upsell_path
    assert_redirected_to kiosk_new_appointment_path(service_id: @suggested.id)

    appointment_date = next_bookable_date

    assert_difference -> { Appointment.count }, 1 do
      post kiosk_appointments_path,
        params: {
          appointment: {
            appointment_date: appointment_date.iso8601,
            appointment_time: "10:00",
            email: "jane@example.com",
            notes: "Wheelchair access"
          }
        },
        as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal kiosk_upsell_booking_confirmation_path, body["redirect_to"]

    appointment = Appointment.last
    assert_equal original_request.first_name, appointment.first_name
    assert_equal original_request.last_name, appointment.last_name
    assert_equal original_request.dob, appointment.dob
    assert_equal @suggested, appointment.service

    get body["redirect_to"]
    assert_response :success
    assert_match "Queue Saved and Appointment Booked!", response.body
    assert_match original_request.queue_number.to_s, response.body
    assert_match @service.display_name, response.body
    assert_match appointment.booking_reference, response.body
    assert_match @suggested.display_name, response.body
    assert_match appointment.formatted_time, response.body

    get kiosk_upsell_booking_confirmation_path
    assert_redirected_to kiosk_root_path
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

  def seed_upsell_rule_with_variants!
    seed_upsell_rule!
    @rule.upsell_templates.create!(
      title: "Better BP offer",
      description: "Alternative wording.",
      cta_text: "Add better check"
    )
  end

  def seed_upsell_rule!(requires_appointment: false)
    @suggested = @organization.services.create!(
      internal_name: "blood_pressure",
      display_name: "Blood pressure check",
      estimated_duration: 10,
      active: true,
      allows_immediate: true,
      requires_appointment: requires_appointment,
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

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal kiosk_upsell_path, body["redirect_to"]

    ServiceRequest.order(:created_at).last
  end

  def next_bookable_date
    date = Date.current
    14.times do
      day_key = date.strftime("%A").downcase
      return date if @organization.bookable_times[day_key].present?
      date += 1.day
    end
    Date.current + 1.day
  end
end
