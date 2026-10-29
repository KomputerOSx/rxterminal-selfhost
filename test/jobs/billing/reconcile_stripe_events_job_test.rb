require "test_helper"

class Billing::ReconcileStripeEventsJobTest < ActiveJob::TestCase
  setup do
    @window_start = 2.hours.ago
  end

  test "no-ops when Stripe is not configured" do
    Pay::Stripe.stub(:private_key, nil) do
      assert_no_difference "Billing::StripeEventReceipt.count" do
        Billing::ReconcileStripeEventsJob.perform_now
      end
    end
  end

  test "does not alert when Stripe events are recorded locally" do
    sentry_calls = []
    stripe_event = Stripe::Event.construct_from(
      id: "evt_local_1",
      type: "customer.subscription.updated",
      created: 30.minutes.ago.to_i
    )
    fake_list = Object.new
    fake_list.define_singleton_method(:auto_paging_each) { |&block| block.call(stripe_event) }

    Billing::StripeEventReceipt.create!(
      stripe_event_id: "evt_local_1",
      event_type: "customer.subscription.updated",
      received_at: 30.minutes.ago
    )

    Pay::Stripe.stub(:private_key, "sk_test") do
      Stripe::Event.stub(:list, fake_list) do
        Sentry.stub(:capture_message, ->(*args) { sentry_calls << args }) do
          Billing::ReconcileStripeEventsJob.perform_now
        end
      end
    end

    assert_empty sentry_calls
  end

  test "alerts Sentry when Stripe has events we never received" do
    sentry_calls = []
    stripe_event = Stripe::Event.construct_from(
      id: "evt_missing_1",
      type: "customer.subscription.updated",
      created: 30.minutes.ago.to_i
    )
    fake_list = Object.new
    fake_list.define_singleton_method(:auto_paging_each) { |&block| block.call(stripe_event) }

    Pay::Stripe.stub(:private_key, "sk_test") do
      Stripe::Event.stub(:list, fake_list) do
        Sentry.stub(:capture_message, ->(*args) { sentry_calls << args }) do
          Billing::ReconcileStripeEventsJob.perform_now
        end
      end
    end

    assert_equal 1, sentry_calls.size
    assert_match "evt_missing_1", sentry_calls.first.first
  end

  test "records stripe event receipt when pay webhook is created" do
    assert_difference "Billing::StripeEventReceipt.count", 1 do
      Pay::Webhook.create!(
        processor: :stripe,
        event_type: "customer.subscription.updated",
        event: { "id" => "evt_receipt_1", "type" => "customer.subscription.updated" }
      )
    end

    receipt = Billing::StripeEventReceipt.find_by!(stripe_event_id: "evt_receipt_1")
    assert_equal "customer.subscription.updated", receipt.event_type
  end
end
