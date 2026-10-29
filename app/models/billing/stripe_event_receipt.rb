module Billing
  class StripeEventReceipt < ApplicationRecord
    self.table_name = "billing_stripe_event_receipts"

    validates :stripe_event_id, presence: true, uniqueness: true
    validates :event_type, presence: true
    validates :received_at, presence: true

    def self.record!(stripe_event_id:, event_type:, received_at: Time.current)
      find_or_create_by!(stripe_event_id: stripe_event_id) do |receipt|
        receipt.event_type = event_type
        receipt.received_at = received_at
      end
    end
  end
end
