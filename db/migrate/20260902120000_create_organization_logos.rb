class CreateOrganizationLogos < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_logos do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.text :decline_reason
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :organization_logos, [ :organization_id, :status ]
  end
end
