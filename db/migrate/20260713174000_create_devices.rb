class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :device_id, null: false
      t.string :api_key_digest, null: false
      t.string :status, null: false, default: "active"
      t.integer :token_version, null: false, default: 0
      t.string :registered_ip
      t.string :name
      t.string :serial_number
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :devices, :device_id, unique: true
    add_index :devices, :status
  end
end
