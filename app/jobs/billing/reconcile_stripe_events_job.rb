module Billing
  class ReconcileStripeEventsJob < ApplicationJob
    queue_as :default

    LOOKBACK = 2.hours
    SUBSCRIBED_EVENT_TYPES = SubscriptionSyncHandler::EVENT_TYPE_MAP.keys.freeze

    def perform(lookback: LOOKBACK)
      return unless stripe_configured?

      window_start = lookback.ago
      local_ids = local_stripe_event_ids(window_start)
      missing = []

      each_stripe_event(since: window_start) do |stripe_event|
        next unless SUBSCRIBED_EVENT_TYPES.include?(stripe_event.type)
        next if local_ids.include?(stripe_event.id)

        missing << stripe_event
      end

      alert_missing_events(missing) if missing.any?
    end

    private

    def stripe_configured?
      Pay::Stripe.private_key.present?
    end

    def local_stripe_event_ids(since)
      webhook_ids = Pay::Webhook.where(processor: "stripe", created_at: since..).filter_map { |webhook|
        stripe_event_id(webhook)
      }
      receipt_ids = Billing::StripeEventReceipt.where(received_at: since..).pluck(:stripe_event_id)
      (webhook_ids + receipt_ids).uniq
    end

    def stripe_event_id(webhook)
      Pay::Webhook.extract_stripe_event_id(webhook.event)
    end

    def each_stripe_event(since:)
      Stripe::Event.list(created: { gte: since.to_i }, limit: 100).auto_paging_each do |stripe_event|
        yield stripe_event
      end
    end

    def alert_missing_events(events)
      summary = events.map { |event| "#{event.id} (#{event.type})" }.join(", ")
      message = "Stripe webhook reconciliation found #{events.size} missing event(s): #{summary}"

      Rails.logger.error("[Billing] #{message}")
      Sentry.capture_message(
        message,
        level: :error,
        extra: {
          missing_event_ids: events.map(&:id),
          missing_event_types: events.map(&:type)
        }
      )
    end
  end
end
