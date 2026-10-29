class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :internal_name, null: false
      t.string :display_name, null: false
      t.text :description
      t.string :icon
      t.boolean :active, null: false, default: true
      t.boolean :featured, null: false, default: false
      t.integer :display_order, null: false, default: 0
      t.integer :estimated_duration, null: false
      t.decimal :price, precision: 8, scale: 2
      t.boolean :allows_immediate, null: false, default: true
      t.boolean :requires_appointment, null: false, default: false
      t.boolean :allows_private_consultation, null: false, default: false
      t.json :eligibility_requirements, null: false, default: {}
      t.datetime :deleted_at
      t.references :deleted_by, foreign_key: { to_table: :users }
      t.text :delete_reason

      t.timestamps
    end

    add_index :services, [ :organization_id, :active, :display_order ]
    add_index :services, [ :organization_id, :deleted_at ]
    add_index :services, [ :organization_id, :internal_name ],
      unique: true,
      where: "deleted_at IS NULL",
      name: "index_services_on_organization_id_and_internal_name_visible"
  end
end
