class AddOrgSettingsExtensionsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    change_table :organizations, bulk: true do |t|
      t.json :operating_hours, null: false, default: {}
      t.string :postcode_region, null: false, default: "uk"
      t.boolean :kiosk_show_featured_service, null: false, default: false
      t.boolean :kiosk_show_services, null: false, default: true
      t.boolean :kiosk_show_appointments, null: false, default: true
      t.references :kiosk_featured_service, foreign_key: { to_table: :services, on_delete: :nullify }
    end
  end
end
