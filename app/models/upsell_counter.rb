# frozen_string_literal: true

class UpsellCounter < ApplicationRecord
  belongs_to :organization
  belongs_to :upsell_rule

  validates :date, presence: true
  validates :organization_id, uniqueness: { scope: [ :upsell_rule_id, :date, :hour ] }

  def self.for_now(organization:, upsell_rule:)
    find_or_create_by!(
      organization: organization,
      upsell_rule: upsell_rule,
      date: Date.current,
      hour: Time.current.hour
    )
  end

  def increment_conversion!(service = nil)
    increment_outcome!(:conversion_count, service)
  end

  def increment_book_later!(service = nil)
    increment_outcome!(:book_later_count, service)
  end

  def increment_decline!
    increment!(:decline_count)
    increment!(:total_triggered)
  end

  private

  def increment_outcome!(count_field, service)
    increment!(count_field)
    increment!(:total_triggered)
    price = service&.price.to_f
    increment!(:estimated_revenue, price) if price.positive?
  end
end
