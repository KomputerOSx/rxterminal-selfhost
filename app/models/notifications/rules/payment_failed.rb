module Notifications
  module Rules
    class PaymentFailed < Notifications::Rule
      def self.event_type = :payment_failed
      def self.category = :billing

      def recipients = organization_owners

      def title = "Payment failed for #{organization&.name}"
      def body  = "We couldn't process a recent payment for #{organization&.name}. Please update your payment method to avoid service interruption."
      def url   = billing_path
    end
  end
end
