# frozen_string_literal: true

class UpsellTemplate < ApplicationRecord
  belongs_to :upsell_rule

  validates :title, :cta_text, presence: true
end
