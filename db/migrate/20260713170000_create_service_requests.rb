class CreateServiceRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :service_requests do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.string :status, null: false, default: "waiting"
      t.string :request_type, null: false
      t.string :queue_number, null: false
      t.date :queue_date, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :dob, null: false
      t.string :postcode
      t.text :description
      t.boolean :is_minor, null: false, default: false
      t.boolean :privacy_requested, null: false, default: false
      t.datetime :called_at
      t.datetime :completed_at
      t.datetime :appointment_datetime
      t.string :previous_status
      t.datetime :previous_called_at
      t.datetime :pii_redacted_at

      t.timestamps
    end

    add_index :service_requests, [ :organization_id, :queue_number, :queue_date ],
      unique: true,
      name: "index_service_requests_on_org_queue_number_and_date"
    add_index :service_requests, [ :organization_id, :status, :created_at ]
    add_index :service_requests, :pii_redacted_at
    add_index :service_requests, :is_minor
    add_index :service_requests, :appointment_datetime
  end
end
