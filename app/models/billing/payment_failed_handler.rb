module Billing
  class PaymentFailedHandler
    def call(event)
      pay_subscription = Pay::Subscription.find_by(processor_id: event.data.object.subscription)
      return unless pay_subscription
      return unless pay_subscription.customer.owner_type == "Organization"

      organization = pay_subscription.customer.owner

      AuditLog.log!(
        event_type: "payment_failed",
        resource: organization,
        organization: organization,
        metadata: { stripe_invoice_id: event.data.object.id }
      )
    end
  end
end
