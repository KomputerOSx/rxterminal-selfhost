# frozen_string_literal: true

module Billing
  class Tax
    def self.collect_vat?
      ActiveModel::Type::Boolean.new.cast(
        Rails.application.credentials.dig(:stripe, :collect_vat)
      ) == true
    end
  end
end
