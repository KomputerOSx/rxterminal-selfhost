# frozen_string_literal: true

require "test_helper"

class AdminWebhookEventsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    sign_in_as_billing_admin(@admin)
  end

  test "index defaults to last seven days" do
    get admin_webhook_events_path

    assert_response :redirect
    assert_match %r{/admin/webhook_events\?date_from=}, response.headers["Location"]

    follow_redirect!

    assert_response :success
    assert_select "h1", text: "Webhook Events"
  end

  test "index has no subtitle under the page title" do
    get admin_webhook_events_path(**default_date_range)

    assert_response :success
    refute_match "Stripe webhook payloads received by Pay", response.body
  end

  test "index lists a pending webhook event with a link to its raw payload" do
    webhook = Pay::Webhook.create!(
      processor: :stripe,
      event_type: "customer.subscription.updated",
      event: { "id" => "evt_test_123", "type" => "customer.subscription.updated" }
    )

    get admin_webhook_events_path(**default_date_range, event_type: "customer.subscription.updated")

    assert_response :success
    assert_match "evt_test_123", response.body
    assert_match "Pending / failed", response.body
    assert_select "a[href=?]", admin_webhook_event_path(webhook), text: "View"
  end

  test "index lists a successfully processed event with no raw payload to view" do
    Billing::StripeEventReceipt.record!(
      stripe_event_id: "evt_processed_456",
      event_type: "customer.subscription.deleted",
      received_at: Time.current
    )

    get admin_webhook_events_path(**default_date_range)

    assert_response :success
    assert_match "evt_processed_456", response.body
    assert_match "Processed", response.body
  end

  test "status filter narrows the list" do
    Pay::Webhook.create!(
      processor: :stripe,
      event_type: "customer.subscription.updated",
      event: { "id" => "evt_pending_status" }
    )
    Billing::StripeEventReceipt.record!(
      stripe_event_id: "evt_processed_status",
      event_type: "customer.subscription.deleted",
      received_at: Time.current
    )

    get admin_webhook_events_path(**default_date_range, status: "processed")

    assert_response :success
    assert_match "evt_processed_status", response.body
    refute_match "evt_pending_status", response.body
  end

  test "show renders raw event json" do
    webhook = Pay::Webhook.create!(
      processor: :stripe,
      event_type: "customer.subscription.updated",
      event: { "id" => "evt_show_test", "type" => "customer.subscription.updated", "data" => { "object" => { "id" => "sub_1" } } }
    )

    get admin_webhook_event_path(webhook)

    assert_response :success
    assert_match "evt_show_test", response.body
    assert_match "sub_1", response.body
  end

  test "requires system.billing.manage permission" do
    sign_out
    user = users(:two)
    role = Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_USER) { |r| r.permanent = true }
    user.grant_role!(role)
    post login_path, params: { email: user.email, password: "password123" }

    get admin_webhook_events_path

    assert_redirected_to root_path
  end

  private

  def default_date_range
    { date_from: 1.day.ago.strftime("%Y-%m-%dT%H:%M"), date_to: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M") }
  end

  def sign_in_as_billing_admin(user)
    role = Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_ADMIN) { |r| r.permanent = true }
    user.grant_role!(role)
    post login_path, params: { email: user.email, password: "password123" }
  end

  def sign_out
    delete logout_path
  end
end
