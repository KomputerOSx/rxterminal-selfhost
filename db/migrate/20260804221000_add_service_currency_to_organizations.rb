# frozen_string_literal: true

class AddServiceCurrencyToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :service_currency, :string, default: "gbp", null: false
  end
end
