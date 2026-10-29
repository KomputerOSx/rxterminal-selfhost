# frozen_string_literal: true

require "test_helper"

class OrgAnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "consultation",
      display_name: "Consultation",
      estimated_duration: 15,
      active: true
    )
  end

  test "an owner with app.analytics.view can view analytics" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_analytics_path

    assert_response :success
    assert_match "Analytics", response.body
    assert_match "No data for this period", response.body
  end

  test "analytics shows service request counts" do
    @organization.service_requests.create!(
      service: @service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 1, 15),
      postcode: "SW1A 1AA",
      status: "completed",
      request_type: "immediate",
      queue_number: "1",
      queue_date: Date.current,
      completed_at: Time.current
    )

    post login_path, params: { email: @owner.email, password: "password123" }

    get org_analytics_path

    assert_response :success
    assert_match "Consultation", response.body
    assert_match ">1<", response.body
    assert_match "Requests by service", response.body
    assert_match "Activity heatmap", response.body
    assert_match "analytics-chart", response.body
  end

  test "analytics counts a request made on the last day of the month/week, not just at midnight" do
    # Regression test: Date#all_week / Date#all_month return Date-bounded ranges
    # (unlike Date#all_day, which is special-cased to return Time bounds). A
    # Date upper bound has no time component, so a `created_at BETWEEN ... AND
    # <date>` comparison against a real timestamp on that same day used to
    # exclude everything but exact midnight. Pin "now" to the last day of a
    # month that's also a Sunday (end of week) so both bounds are exercised
    # regardless of which day the suite happens to run on.
    travel_to Time.zone.local(2026, 5, 31, 15, 0, 0) do
      @organization.service_requests.create!(
        service: @service,
        first_name: "Jane",
        last_name: "Doe",
        dob: Date.new(1990, 1, 15),
        postcode: "SW1A 1AA",
        status: "completed",
        request_type: "immediate",
        queue_number: "1",
        queue_date: Date.current,
        completed_at: Time.current
      )

      post login_path, params: { email: @owner.email, password: "password123" }

      get org_analytics_path(period: "this_month")
      assert_response :success
      assert_match ">1<", response.body

      get org_analytics_path(period: "this_week")
      assert_response :success
      assert_match ">1<", response.body
    end
  end

  test "a member without app.analytics.view is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_analytics_path
    assert_redirected_to root_path
  end
end
