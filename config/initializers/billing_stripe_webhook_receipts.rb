# Pay deletes Pay::Webhook rows after successful processing, but ops reconciliation
# needs a durable record of every Stripe event we received.
Rails.application.config.to_prepare do
  Pay::Webhook.class_eval do
    after_create_commit :record_billing_stripe_event_receipt, if: -> { processor.to_s == "stripe" }

    def self.extract_stripe_event_id(event)
      event.is_a?(Hash) ? event["id"] : event.try(:id)
    end

    private

    def record_billing_stripe_event_receipt
      event_id = self.class.extract_stripe_event_id(event)
      return if event_id.blank?

      Billing::StripeEventReceipt.record!(
        stripe_event_id: event_id,
        event_type: event_type,
        received_at: created_at
      )
    end
  end
end
