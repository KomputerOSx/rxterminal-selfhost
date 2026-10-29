require "test_helper"

class Billing::WebhookEventSearchTest < ActiveSupport::TestCase
  setup do
    Pay::Webhook.delete_all
    Billing::StripeEventReceipt.delete_all

    # Still present in pay_webhooks => not yet processed successfully.
    @pending = Pay::Webhook.create!(
      processor: :stripe,
      event_type: "customer.subscription.updated",
      event: { "id" => "evt_pending" }
    )

    # Pay deletes the pay_webhooks row once an event is processed successfully, but the receipt
    # (written on creation, before deletion) survives - simulate that here.
    @processed_receipt = Billing::StripeEventReceipt.record!(
      stripe_event_id: "evt_processed",
      event_type: "customer.subscription.deleted",
      received_at: Time.current
    )

    @older_receipt = Billing::StripeEventReceipt.record!(
      stripe_event_id: "evt_old",
      event_type: "customer.subscription.deleted",
      received_at: 10.days.ago
    )
  end

  test "filters by event type and date range" do
    result = Billing::WebhookEventSearch.call(
      event_type: "customer.subscription.updated",
      date_from: 1.day.ago.strftime("%Y-%m-%dT%H:%M"),
      date_to: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M")
    )

    stripe_event_ids = result.webhook_events.map(&:stripe_event_id)
    assert_includes stripe_event_ids, "evt_pending"
    refute_includes stripe_event_ids, "evt_old"
  end

  test "flags events still present in pay_webhooks as pending" do
    result = Billing::WebhookEventSearch.call({})

    assert_equal @pending.id, result.pending_pay_webhook_ids["evt_pending"]
    refute result.pending_pay_webhook_ids.key?("evt_processed")
  end

  test "status filter narrows to processed events" do
    result = Billing::WebhookEventSearch.call(status: "processed")

    stripe_event_ids = result.webhook_events.map(&:stripe_event_id)
    assert_includes stripe_event_ids, "evt_processed"
    assert_includes stripe_event_ids, "evt_old"
    refute_includes stripe_event_ids, "evt_pending"
  end

  test "status filter narrows to pending events" do
    result = Billing::WebhookEventSearch.call(status: "pending")

    assert_equal [ "evt_pending" ], result.webhook_events.map(&:stripe_event_id)
  end
end
