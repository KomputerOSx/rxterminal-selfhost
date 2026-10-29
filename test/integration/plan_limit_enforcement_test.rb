# frozen_string_literal: true

require "test_helper"

class PlanLimitEnforcementTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = create_personal_on_starter_trial!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
    post login_path, params: { email: @owner.email, password: "password123" }
  end

  test "starter blocks a fourth service" do
    create_services!(3)

    assert_no_difference -> { @organization.services.counting_toward_plan_limit.count } do
      post org_services_path, params: {
        service: {
          internal_name: "fourth_service",
          display_name: "Fourth service",
          estimated_duration: 10,
          allows_immediate: true,
          active: true,
          calendar_id: @calendar.id
        }
      }
    end

    assert_redirected_to billing_path
    assert_match "service limit", flash[:alert]
  end

  test "starter blocks a second upsell rule" do
    create_upsell_rule!

    assert_no_difference -> { @organization.upsell_rules.counting_toward_plan_limit.count } do
      post org_upsell_rules_path, params: second_upsell_rule_params
    end

    assert_redirected_to billing_path
    assert_match "upsell rule limit", flash[:alert]
  end

  test "starter blocks the 201st monthly service request from staff walk-ins" do
    service = create_walk_in_service!
    create_service_requests!(service, 200)

    assert_no_difference "ServiceRequest.count" do
      post org_walk_in_path, params: {
        service_request: {
          service_id: service.id,
          first_name: "PAT",
          last_name: "CUSTOMER",
          dob: "15-01-1990",
          postcode: "NE1 1AA"
        }
      }
    end

    assert_redirected_to billing_path
    assert_match "monthly service request limit", flash[:alert]
  end

  test "starter blocks staff appointment creation" do
    service = create_appointment_service!

    assert_no_difference "Appointment.count" do
      post org_appointments_path, params: {
        appointment: {
          service_id: service.id,
          first_name: "PAT",
          last_name: "CUSTOMER",
          dob: "15-01-1990",
          postcode: "NE1 1AA",
          appointment_date: next_weekday(Date.current + 1.day).iso8601,
          appointment_time: "10:00"
        }
      }
    end

    assert_redirected_to billing_path
    assert_match "appointment booking", flash[:alert]
  end

  test "starter blocks kiosk device registration" do
    assert_no_difference "Device.count" do
      post org_devices_path, params: {
        device: {
          device_id: "kiosk-lobby",
          name: "Lobby kiosk",
          status: "active"
        }
      }
    end

    assert_redirected_to billing_path
    assert_match "kiosk devices", flash[:alert]
  end

  test "members page shows an upgrade banner on starter" do
    get org_members_path

    assert_response :success
    assert_match "member limit", response.body
    assert_match "View plans", response.body
  end

  test "sidebar shows business upsell for appointments on starter" do
    get org_queue_path

    assert_response :success
    assert_match "Appointments", response.body
    assert_match "Business", response.body
  end

  test "starter blocks public appointment booking" do
    enable_public_portal!(@organization, :online_appointment_booking)
    accept_public_portal_privacy!
    service = create_appointment_service!

    assert_no_difference "Appointment.count" do
      post portal_appointments_path(organization_slug: @organization.slug), params: {
        appointment: {
          service_id: service.id,
          first_name: "JANE",
          last_name: "DOE",
          dob: "01-01-1990",
          postcode: "N1 1AA",
          appointment_date: next_weekday(Date.current + 1.day).iso8601,
          appointment_time: "10:00"
        }
      }
    end

    assert_redirected_to root_path
    assert_match "appointment booking", flash[:alert]
  end

  test "starter blocks browsing the public appointment booking form" do
    enable_public_portal!(@organization, :online_appointment_booking)
    accept_public_portal_privacy!

    get new_portal_appointment_path(organization_slug: @organization.slug)

    assert_redirected_to root_path
    assert_match "appointment booking", flash[:alert]
  end

  test "starter blocks public appointment check-in" do
    enable_public_portal!(@organization, :online_appointment_check)
    accept_public_portal_privacy!

    get new_portal_appointment_checkin_path(organization_slug: @organization.slug)

    assert_redirected_to root_path
    assert_match "appointment booking", flash[:alert]
  end

  test "starter blocks the 201st public mobile walk-in" do
    enable_public_portal!(@organization, :mobile_service_request)
    service = create_walk_in_service!
    create_service_requests!(service, 200)
    start_public_walk_in_session!

    assert_no_difference "ServiceRequest.count" do
      post portal_walk_in_path(organization_slug: @organization.slug), params: {
        service_request: {
          service_id: service.id,
          first_name: "PAT",
          last_name: "CUSTOMER",
          dob: "15-01-1990",
          postcode: "NE1 1AA"
        }
      }
    end

    assert_redirected_to root_path
    assert_match "temporarily unavailable", flash[:alert]
  end

  private

  def enable_public_portal!(organization, *feature_keys)
    FeatureRegistry.sync!

    portal = Feature.find_by!(key: "public_portal")
    portal.update!(enabled: true, applies_to_all_organizations: true)

    feature_keys.each do |key|
      feature = Feature.find_by!(key: key.to_s)
      feature.update!(enabled: true, applies_to_all_organizations: true)
      organization.update_feature!(key, enabled: true) if feature.org_opt_in_required?
    end
  end

  def start_public_walk_in_session!
    accept_public_portal_privacy!

    token = Rails.application.message_verifier("walk-in").generate(
      { "org_id" => @organization.id, "org_slug" => @organization.slug }
    )
    get portal_arrive_path(organization_slug: @organization.slug, token: token)
    assert_response :success
  end

  def accept_public_portal_privacy!
    get portal_privacy_path(organization_slug: @organization.slug)
    post accept_portal_privacy_path(organization_slug: @organization.slug)
  end

  def create_services!(count)
    count.times do |index|
      @organization.services.create!(
        internal_name: "service_#{index}_#{SecureRandom.hex(3)}",
        display_name: "Service #{index}",
        estimated_duration: 15,
        active: true,
        calendar: @calendar
      )
    end
  end

  def create_walk_in_service!
    @organization.services.create!(
      internal_name: "walk_in",
      display_name: "Walk-in",
      estimated_duration: 15,
      allows_immediate: true,
      active: true,
      calendar: @calendar
    )
  end

  def create_appointment_service!
    @organization.services.create!(
      internal_name: "appointment_only",
      display_name: "Consultation",
      estimated_duration: 15,
      requires_appointment: true,
      allows_immediate: false,
      active: true,
      calendar: @calendar
    )
  end

  def create_service_requests!(service, count)
    count.times do |index|
      @organization.service_requests.create!(
        service: service,
        first_name: "PAT",
        last_name: "CUSTOMER#{index}",
        dob: Date.new(1990, 1, 1),
        postcode: "NE1 1AA",
        queue_number: index + 1,
        queue_date: Date.current,
        status: "waiting",
        request_type: "immediate"
      )
    end
  end

  def create_upsell_rule!
    trigger = create_walk_in_service!
    suggested = create_appointment_service!
    rule = @organization.upsell_rules.build(
      name: "First rule",
      trigger_service: trigger,
      suggested_service: suggested,
      frequency_type: "every_nth_customer",
      frequency_value: 1,
      visit_type: "any",
      active: true
    )
    rule.upsell_templates.build(title: "Offer", description: "Details", cta_text: "Yes")
    rule.save!
  end

  def second_upsell_rule_params
    trigger = @organization.services.first
    suggested = @organization.services.second
    {
      upsell_rule: {
        name: "Second rule",
        trigger_service_id: trigger.id,
        suggested_service_id: suggested.id,
        frequency_type: "every_nth_customer",
        frequency_value: 1,
        visit_type: "any",
        active: true,
        upsell_templates_attributes: {
          "0" => { title: "Another", description: "More", cta_text: "Add" }
        }
      }
    }
  end

  def next_weekday(date)
    date += 1.day while date.saturday? || date.sunday?
    date
  end
end
