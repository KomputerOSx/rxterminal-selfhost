class CreateCalendars < ActiveRecord::Migration[8.1]
  def change
    create_table :calendars do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :is_default, null: false, default: false
      t.boolean :archived, null: false, default: false
      t.string :color, null: false, default: "#6366f1"

      t.timestamps
    end

    add_index :calendars, [ :organization_id, :name ], unique: true
    add_index :calendars, [ :organization_id, :archived ]
    add_index :calendars, [ :organization_id, :is_default ]

    add_reference :services, :calendar, foreign_key: true
  end
end
