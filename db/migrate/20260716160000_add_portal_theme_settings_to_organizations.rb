# frozen_string_literal: true

class AddPortalThemeSettingsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    change_table :organizations, bulk: true do |t|
      t.string :portal_theme, null: false, default: "kiosk-default"
      t.json :portal_theme_custom, null: false, default: {}
    end
  end
end
