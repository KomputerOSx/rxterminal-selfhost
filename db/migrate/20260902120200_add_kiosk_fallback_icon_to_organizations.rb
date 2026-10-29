class AddKioskFallbackIconToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :kiosk_fallback_icon, :string, null: false, default: "favorite"
  end
end
