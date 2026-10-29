class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :calendar, foreign_key: true
      t.references :service_request, foreign_key: true
      t.string :booking_reference, null: false
      t.date :appointment_date, null: false
      t.time :appointment_time, null: false
      t.string :status, null: false, default: "booked"
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :dob, null: false
      t.string :postcode
      t.string :email
      t.text :notes
      t.boolean :is_minor, null: false, default: false
      t.datetime :checked_in_at
      t.datetime :cancelled_at
      t.datetime :no_show_at
      t.datetime :pii_redacted_at

      t.timestamps
    end

    add_index :appointments, :booking_reference, unique: true
    add_index :appointments, [ :organization_id, :appointment_date ]
    add_index :appointments, [ :organization_id, :service_id, :appointment_date ]
    add_index :appointments, [ :organization_id, :status ]
    add_index :appointments, :pii_redacted_at
    add_index :appointments, :is_minor
  end
end
