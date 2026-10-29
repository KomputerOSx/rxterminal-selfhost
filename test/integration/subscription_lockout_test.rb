# frozen_string_literal: true

require "test_helper"

class SubscriptionLockoutTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15,
      allows_immediate: true
    )
  end

  test "a locked org is redirected from operational pages to billing" do
    lock_organization!(@organization)

    post login_path, params: { email: @owner.email, password: "password123" }

    get org_queue_path
    assert_redirected_to billing_path
    assert_equal "This organization's subscription has ended. Update billing to restore access.", flash[:alert]

    post org_walk_in_path, params: {
      service_request: {
        service_id: @service.id,
        first_name: "john",
        last_name: "smith",
        dob: "15-01-1990",
        postcode: "SW1A 1AA"
      }
    }
    assert_redirected_to billing_path
  end

  test "a locked org can still reach billing, settings, and members" do
    lock_organization!(@organization)

    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path
    assert_response :success
    assert_match "subscription has ended", response.body

    get org_settings_path
    assert_response :success

    get org_members_path
    assert_response :success
  end

  test "a locked org can still manage their profile" do
    lock_organization!(@organization)

    post login_path, params: { email: @owner.email, password: "password123" }

    get profile_path
    assert_response :success
  end

  test "past_due org keeps operational access but shows a warning banner" do
    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.payment_processor.subscription.update!(status: "past_due")

      post login_path, params: { email: @owner.email, password: "password123" }

      get org_queue_path
      assert_response :success
      assert_match "latest payment failed", response.body
    end
  end

  test "locked public portal shows an unavailable page" do
    enable_public_portal!(@organization)
    lock_organization!(@organization)

    get portal_root_path(organization_slug: @organization.slug)
    assert_response :service_unavailable
    assert_match "temporarily unavailable", response.body
  end

  test "locked waiting display shows an unavailable page" do
    lock_organization!(@organization)

    post login_path, params: { email: @owner.email, password: "password123" }

    get org_waiting_display_path
    assert_response :service_unavailable
    assert_match "waiting display is temporarily unavailable", response.body
  end

  private

  def lock_organization!(organization)
    with_active_subscription(organization, Billing::Plans::STARTER) do
      organization.payment_processor.subscription.update!(status: "canceled", ends_at: 1.day.ago)
    end
  end

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
end
