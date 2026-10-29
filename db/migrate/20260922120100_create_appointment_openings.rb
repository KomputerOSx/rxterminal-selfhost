class CreateAppointmentOpenings < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_openings do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :calendar, foreign_key: true
      t.string :name
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.json :bookable_times, default: {}, null: false

      t.timestamps
    end

    add_index :appointment_openings, [ :organization_id, :start_date, :end_date ],
      name: "index_appointment_openings_on_org_and_range"
  end
end
