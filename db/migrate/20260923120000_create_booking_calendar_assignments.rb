class CreateBookingCalendarAssignments < ActiveRecord::Migration[8.1]
  def up
    create_table :appointment_opening_calendars do |t|
      t.references :appointment_opening, null: false, foreign_key: true
      t.references :calendar, null: false, foreign_key: true

      t.timestamps
    end
    add_index :appointment_opening_calendars, [ :appointment_opening_id, :calendar_id ], unique: true,
      name: "index_appointment_opening_calendars_uniqueness"

    create_table :appointment_blocked_date_calendars do |t|
      t.references :appointment_blocked_date, null: false, foreign_key: true
      t.references :calendar, null: false, foreign_key: true

      t.timestamps
    end
    add_index :appointment_blocked_date_calendars, [ :appointment_blocked_date_id, :calendar_id ], unique: true,
      name: "index_appointment_blocked_date_calendars_uniqueness"

    execute <<~SQL
      INSERT INTO appointment_opening_calendars (appointment_opening_id, calendar_id, created_at, updated_at)
      SELECT id, calendar_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM appointment_openings WHERE calendar_id IS NOT NULL
    SQL
    execute <<~SQL
      INSERT INTO appointment_blocked_date_calendars (appointment_blocked_date_id, calendar_id, created_at, updated_at)
      SELECT id, calendar_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM appointment_blocked_dates WHERE calendar_id IS NOT NULL
    SQL

    remove_index :appointment_blocked_dates, name: "index_appointment_blocked_dates_uniqueness"
    remove_reference :appointment_openings, :calendar, foreign_key: true, index: true
    remove_reference :appointment_blocked_dates, :calendar, foreign_key: true, index: true
  end

  def down
    add_reference :appointment_openings, :calendar, foreign_key: true
    add_reference :appointment_blocked_dates, :calendar, foreign_key: true

    execute <<~SQL
      UPDATE appointment_openings SET calendar_id = (
        SELECT MIN(calendar_id) FROM appointment_opening_calendars
        WHERE appointment_opening_calendars.appointment_opening_id = appointment_openings.id
      )
    SQL
    execute <<~SQL
      UPDATE appointment_blocked_dates SET calendar_id = (
        SELECT MIN(calendar_id) FROM appointment_blocked_date_calendars
        WHERE appointment_blocked_date_calendars.appointment_blocked_date_id = appointment_blocked_dates.id
      )
    SQL
    add_index :appointment_blocked_dates, [ :organization_id, :calendar_id, :start_date, :end_date ],
      unique: true, name: "index_appointment_blocked_dates_uniqueness"

    drop_table :appointment_blocked_date_calendars
    drop_table :appointment_opening_calendars
  end
end
