module Notifications
  module Rules
    class SubscriptionCancelled < Notifications::Rule
      def self.event_type = :subscription_cancelled
      def self.category = :billing

      def recipients = organization_owners

      def title = "Subscription cancelled for #{organization&.name}"
      def body  = "The subscription for #{organization&.name} has been cancelled."
      def url   = billing_path
    end
  end
end
