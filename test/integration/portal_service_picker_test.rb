# frozen_string_literal: true

require "test_helper"

class PortalServicePickerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    calendar = @organization.calendars.find_by!(is_default: true)
    %w[Flu\ Jab Travel\ Clinic].each_with_index do |name, i|
      @organization.services.create!(
        internal_name: "svc#{i}", display_name: name, estimated_duration: 15, requires_appointment: true,
        allows_immediate: true, active: true, calendar: calendar
      )
    end
    @organization.update_feature!(:online_appointment_booking, enabled: true)
    @organization.update_feature!(:mobile_service_request, enabled: true)
  end

  test "the portal home has a search box with a list / two-column switch beside it" do
    get root_path

    assert_response :success
    assert_select "input[type=search][data-portal-search-target=input]"
    assert_select "[data-controller~=view-toggle] button[data-view-toggle-mode-param=list]"
    assert_select "[data-controller~=view-toggle] button[data-view-toggle-mode-param=card]"
    assert_select "[data-view-toggle-mode=list] a", minimum: 2
    assert_select "[data-view-toggle-mode=card].grid-cols-2 a", minimum: 2
  end

  test "the service links on the home page go to the appointment form" do
    get root_path

    assert_select "[data-view-toggle-mode=list] a[href*='/appointments/new?service_id=']", minimum: 2
  end

  test "the walk-in picker uses the same switch and links to the walk-in form" do
    accept_privacy!
    get arrive_path_for_walk_in
    assert_response :success
    assert_select "button[data-view-toggle-mode-param=card]"
    assert_select "[data-view-toggle-mode=list] a[href*='/walk-in?service_id=']", minimum: 2
  end

  test "the portal loads the stylesheet the searchable service dropdown needs" do
    accept_privacy!
    get "/appointments/new"

    assert_response :success
    assert_select "link[href*='tom-select'][rel=stylesheet]"
  end

  private

  def accept_privacy!
    get "/privacy"
    post "/privacy/accept"
  end

  def arrive_path_for_walk_in
    token = Rails.application.message_verifier("walk-in").generate(
      { "org_id" => @organization.id, "org_slug" => @organization.slug }
    )
    get "/arrive", params: { token: token }
    "/walk-in"
  end
end
