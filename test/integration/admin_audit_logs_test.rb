# frozen_string_literal: true

require "test_helper"

class AdminAuditLogsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    sign_in_as_system_admin(@admin)
    @organization = Organization.create_personal_for!(@admin)
  end

  test "index defaults to last seven days and renders comprehensive filters" do
    get admin_audit_logs_path

    assert_response :redirect
    assert_match %r{/admin/audit_logs\?date_from=}, response.headers["Location"]

    follow_redirect!

    assert_response :success
    assert_select "textarea[name='json_search']"
    assert_select "input[name='event_types[]']"
    assert_select "input[name='organization_ids[]']"
    assert_select 'input[type="datetime-local"]', minimum: 2
    assert_select "turbo-frame#admin_audit_logs_results_frame"
  end

  test "index lists organization slug and id and paginates at 100" do
    101.times do |index|
      AuditLog.create!(
        event_type: :organization_updated,
        resource_type: "Organization",
        resource_id: @organization.id,
        created_at: index.minutes.ago
      )
    end

    get admin_audit_logs_path(
      date_from: 2.days.ago.strftime("%Y-%m-%dT%H:%M"),
      date_to: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M"),
      organization_ids: [ @organization.id ]
    )

    assert_response :success
    assert_match @organization.slug, response.body
    assert_match @organization.id.to_s, response.body
    assert_select "nav[aria-label='Pagination']"

    get admin_audit_logs_path(
      page: 2,
      date_from: 2.days.ago.strftime("%Y-%m-%dT%H:%M"),
      date_to: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M"),
      organization_ids: [ @organization.id ]
    )

    assert_response :success
    assert_select "turbo-frame#admin_audit_logs_results_frame"
  end

  test "resource filter from page two returns first page of matching logs" do
    101.times do |index|
      AuditLog.create!(
        event_type: :organization_updated,
        resource_type: "Organization",
        resource_id: @organization.id,
        created_at: index.minutes.ago
      )
    end

    date_from = 2.days.ago.strftime("%Y-%m-%dT%H:%M")
    date_to = 1.hour.from_now.strftime("%Y-%m-%dT%H:%M")

    get admin_audit_logs_path(
      page: 2,
      date_from: date_from,
      date_to: date_to,
      resource_type: "Organization",
      resource_id: @organization.id
    )

    assert_response :success
    assert_select "h3", text: "No results", count: 0
    assert_match @organization.id.to_s, response.body
  end

  test "resource links drop page param" do
    101.times do |index|
      AuditLog.create!(
        event_type: :organization_updated,
        resource_type: "Organization",
        resource_id: @organization.id,
        created_at: index.minutes.ago
      )
    end

    get admin_audit_logs_path(
      page: 2,
      date_from: 2.days.ago.strftime("%Y-%m-%dT%H:%M"),
      date_to: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M")
    )

    assert_response :success
    assert_select "a[href*='resource_type=Organization'][href*='resource_id=#{@organization.id}']"
    resource_link = css_select("a[href*='resource_type=Organization']").find { |node| node["href"].include?("resource_id=#{@organization.id}") }
    assert resource_link
    assert_no_match(/page=/, resource_link["href"])
  end

  test "show uses safe return_to back path" do
    log = AuditLog.create!(
      event_type: :organization_updated,
      resource_type: "Organization",
      resource_id: @organization.id
    )
    return_to = admin_audit_logs_path(page: 2, date_from: 1.day.ago.strftime("%Y-%m-%dT%H:%M"))

    get admin_audit_log_path(log, return_to: return_to)

    assert_response :success
    assert_select "a.btn", text: /Back/
    assert_select "a[href=?]", return_to
  end

  test "show rejects external return_to values" do
    log = AuditLog.create!(event_type: :login_success)

    get admin_audit_log_path(log, return_to: "https://evil.example/audit")

    assert_response :success
    assert_select "a[href=?]", admin_audit_logs_path
    assert_no_match "evil.example", response.body
  end

  private

  def sign_in_as_system_admin(user)
    role = Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_ADMIN) { |r| r.permanent = true }
    user.grant_role!(role)
    post login_path, params: { email: user.email, password: "password123" }
  end
end
