# frozen_string_literal: true

class AddKioskThemeSettingsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    change_table :organizations, bulk: true do |t|
      t.string :kiosk_theme, null: false, default: "kiosk-default"
      t.string :kiosk_animation, null: false, default: "fade"
      t.json :kiosk_theme_custom, null: false, default: {}
    end
  end
end
