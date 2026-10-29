class CreateUpsells < ActiveRecord::Migration[8.1]
  def change
    create_table :upsell_rules do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :trigger_service, null: false, foreign_key: { to_table: :services }
      t.references :suggested_service, null: false, foreign_key: { to_table: :services }
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.string :frequency_type, null: false
      t.integer :frequency_value, null: false
      t.integer :cooldown_days, null: false, default: 30
      t.string :visit_type, null: false, default: "any"
      t.integer :min_age
      t.integer :max_age
      t.date :active_from
      t.date :active_until
      t.integer :active_hours_start
      t.integer :active_hours_end
      t.integer :priority, null: false, default: 0
      t.integer :daily_limit
      t.integer :hourly_limit

      t.timestamps
    end

    add_index :upsell_rules, [ :organization_id, :trigger_service_id, :active ]

    create_table :upsell_templates do |t|
      t.references :upsell_rule, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :cta_text, null: false
      t.string :image_url

      t.timestamps
    end

    create_table :upsell_counters do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :upsell_rule, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :hour
      t.integer :total_eligible, null: false, default: 0
      t.integer :total_triggered, null: false, default: 0
      t.integer :conversion_count, null: false, default: 0
      t.integer :book_later_count, null: false, default: 0
      t.integer :decline_count, null: false, default: 0
      t.decimal :estimated_revenue, precision: 8, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_index :upsell_counters, [ :organization_id, :upsell_rule_id, :date, :hour ],
      unique: true,
      name: "index_upsell_counters_unique"

    create_table :upsell_interactions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :upsell_rule, null: false, foreign_key: true
      t.references :upsell_template, foreign_key: true
      t.string :customer_hash, null: false
      t.string :outcome
      t.boolean :accepted, null: false, default: false

      t.timestamps
    end

    add_index :upsell_interactions, [ :customer_hash, :upsell_rule_id ]
  end
end
