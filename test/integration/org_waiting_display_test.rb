require "test_helper"

class OrgWaitingDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15
    )
    @organization.service_requests.create!(
      service: @service,
      first_name: "JOHN",
      last_name: "SMITH",
      dob: Date.new(1990, 1, 15),
      postcode: "SW1A 1AA",
      request_type: "immediate",
      status: "waiting",
      queue_number: "1",
      queue_date: Date.current
    )
  end

  test "a member with app.queue.view can open the waiting display and receive a cookie" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_waiting_display_path
    assert_response :success
    assert_match "1", response.body
    assert_match "turbo-cable-stream-source", response.body
    assert response.cookies[Org::WaitingDisplayController::DISPLAY_TOKEN_COOKIE.to_s].present?
  end

  test "waiting display uses organization kiosk theme" do
    @organization.update!(
      kiosk_theme: "custom",
      kiosk_theme_custom: {
        "primary" => "#445566",
        "base_100" => "#fafafa"
      }
    )

    post login_path, params: { email: @owner.email, password: "password123" }
    get org_waiting_display_path

    assert_response :success
    assert_match 'data-theme="kiosk-custom"', response.body
    assert_match "--color-primary: #445566;", response.body
    assert_match "--color-base-100: #fafafa;", response.body
    assert_no_match 'data-theme="light"', response.body
  end

  test "poll returns turbo stream updates" do
    post login_path, params: { email: @owner.email, password: "password123" }
    get org_waiting_display_path

    get org_poll_waiting_display_path, as: :turbo_stream
    assert_response :success
    assert_match "turbo-stream", response.body
    assert_match "waiting-cards", response.body
  end

  test "a member without app.queue.view is denied on first setup" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_waiting_display_path
    assert_redirected_to root_path
  end

  test "waiting display shows a scan-to-join QR code when only walk-in is enabled" do
    enable_public_portal!(@organization, :mobile_service_request)

    post login_path, params: { email: @owner.email, password: "password123" }
    get org_waiting_display_path

    assert_response :success
    assert_match "Scan to join queue", response.body
    assert_match "<svg", response.body
  end

  test "waiting display shows a combined label when walk-in and check-in are both enabled" do
    enable_public_portal!(@organization, :mobile_service_request, :online_appointment_check)

    post login_path, params: { email: @owner.email, password: "password123" }
    get org_waiting_display_path

    assert_response :success
    assert_match "Scan to check in or join the queue", response.body
  end

  test "waiting display shows a booking label when only booking is enabled" do
    enable_public_portal!(@organization, :online_appointment_booking)

    post login_path, params: { email: @owner.email, password: "password123" }
    get org_waiting_display_path

    assert_response :success
    assert_match "Scan to book your appointment", response.body
  end

  test "waiting display omits the QR code when the public portal is disabled" do
    post login_path, params: { email: @owner.email, password: "password123" }
    get org_waiting_display_path

    assert_response :success
    assert_no_match "Scan to join queue", response.body
  end

  test "waiting display omits the QR code when the public portal is enabled but no sub-feature is" do
    FeatureRegistry.sync!
    Feature.find_by!(key: "public_portal").update!(enabled: true, applies_to_all_organizations: true)

    post login_path, params: { email: @owner.email, password: "password123" }
    get org_waiting_display_path

    assert_response :success
    assert_no_match "Scan to", response.body
  end

  test "waiting display QR token rotates hourly and poll delivers the new one" do
    enable_public_portal!(@organization, :mobile_service_request)
    post login_path, params: { email: @owner.email, password: "password123" }

    first_svg = travel_to(Time.utc(2026, 1, 1, 10, 30)) do
      get org_waiting_display_path
      assert_response :success
      response.body[/<svg.*?<\/svg>/m]
    end

    second_svg = travel_to(Time.utc(2026, 1, 1, 11, 45)) do
      get org_poll_waiting_display_path, as: :turbo_stream
      assert_response :success
      response.body[/<svg.*?<\/svg>/m]
    end

    assert_not_equal first_svg, second_svg
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
end
