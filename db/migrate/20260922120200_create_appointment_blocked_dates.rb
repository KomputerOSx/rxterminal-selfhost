class CreateAppointmentBlockedDates < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_blocked_dates do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :calendar, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :reason
      t.string :source, null: false, default: "manual"

      t.timestamps
    end

    add_index :appointment_blocked_dates, [ :organization_id, :start_date, :end_date ],
      name: "index_appointment_blocked_dates_on_org_and_range"
    add_index :appointment_blocked_dates, [ :organization_id, :calendar_id, :start_date, :end_date ],
      unique: true, name: "index_appointment_blocked_dates_uniqueness"
  end
end
