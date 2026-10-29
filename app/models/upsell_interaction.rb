# frozen_string_literal: true

class UpsellInteraction < ApplicationRecord
  OUTCOMES = %w[accepted_immediate accepted_appointment declined].freeze

  belongs_to :organization
  belongs_to :upsell_rule
  belongs_to :upsell_template, optional: true

  validates :outcome, inclusion: { in: OUTCOMES }, allow_nil: true

  def self.recently_shown?(customer_hash:, rule:)
    where(customer_hash: customer_hash, upsell_rule: rule)
      .where(created_at: rule.cooldown_days.days.ago..)
      .exists?
  end
end
