# frozen_string_literal: true

class DefaultOrganizationsPreferredCurrencyToGbp < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE organizations SET preferred_currency = 'gbp' WHERE preferred_currency != 'gbp'
    SQL
    change_column_default :organizations, :preferred_currency, from: "usd", to: "gbp"
  end

  def down
    change_column_default :organizations, :preferred_currency, from: "gbp", to: "usd"
  end
end
