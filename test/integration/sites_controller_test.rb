require "test_helper"

class SitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create_personal_for!(users(:one))
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      @organization.update!(custom_domain: "shop.acme.test")
    end
  end

  test "renders public portal on a configured custom domain root" do
    enable_public_portal!
    host! "shop.acme.test"

    get "/"

    assert_response :success
    assert_match @organization.name, response.body
    assert_match "Book an appointment", response.body
  end

  test "bare appointments path renders the booking form instead of the org placeholder" do
    enable_public_portal!(:online_appointment_booking)
    host! "shop.acme.test"

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get "/"
      post "/privacy/accept"

      get "/appointments"

      assert_response :success
      assert_no_match "Public site placeholder", response.body
    end
  end

  test "returns not found for an unknown custom domain" do
    host! "unknown.acme.test"

    get "/"

    assert_response :not_found
  end

  test "catch-all paths on a custom domain still show the org page" do
    host! "shop.acme.test"

    get "/anything/here"

    assert_response :success
    assert_match @organization.name, response.body
    assert_match @organization.slug, response.body
    assert_match "shop.acme.test", response.body
  end

  test "health check is not swallowed by the custom domain catch-all" do
    host! "shop.acme.test"

    get "/up"

    assert_response :success
  end

  test "active storage paths are not swallowed by the custom domain catch-all" do
    host! "shop.acme.test"

    get "/rails/active_storage/blobs/redirect/bogus-signed-id/logo.png"

    # A bogus signed id 404s inside Active Storage's own controller. If the
    # custom-domain catch-all had swallowed the request instead, this would
    # be a 200 rendering the org's placeholder page.
    assert_response :not_found
    assert_no_match @organization.name, response.body
  end

  test "health check works when kamal-proxy uses a non-primary host" do
    host! "rxterminal-web-abc123"

    get "/up"

    assert_response :success
  end

  private

  def enable_public_portal!(*feature_keys)
    FeatureRegistry.sync!

    portal = Feature.find_by!(key: "public_portal")
    portal.update!(enabled: true, applies_to_all_organizations: true)

    feature_keys.each do |key|
      feature = Feature.find_by!(key: key.to_s)
      feature.update!(enabled: true, applies_to_all_organizations: true)
      @organization.update_feature!(key, enabled: true) if feature.org_opt_in_required?
    end
  end
end
