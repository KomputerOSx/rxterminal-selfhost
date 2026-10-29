class AddAppointmentSettingsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    change_table :organizations, bulk: true do |t|
      t.integer :appointment_slot_minutes, null: false, default: 15
      t.integer :appointment_days_ahead, null: false, default: 14
      t.json :bookable_times, null: false, default: {}
      t.boolean :kiosk_collect_postcode, null: false, default: true
    end
  end
end
