# frozen_string_literal: true

class ChangeKioskThemeDefaultToClassic < ActiveRecord::Migration[8.0]
  def change
    change_column_default :organizations, :kiosk_theme, from: "light", to: "kiosk-default"
  end
end
