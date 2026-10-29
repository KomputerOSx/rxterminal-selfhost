# frozen_string_literal: true

class AddPlanReconciliationFields < ActiveRecord::Migration[8.0]
  def change
    change_table :organizations, bulk: true do |t|
      t.datetime :plan_reconciliation_blocking_at
      t.datetime :plan_reconciliation_completed_at
      t.datetime :plan_reconciliation_applied_at
      t.json :plan_reconciliation_choices, null: false, default: {}
    end

    add_column :services, :archived_at, :datetime
    add_column :upsell_rules, :archived_at, :datetime
    add_column :devices, :deactivated_at, :datetime

    add_index :services, [ :organization_id, :archived_at ]
    add_index :upsell_rules, [ :organization_id, :archived_at ]
    add_index :devices, [ :organization_id, :deactivated_at ]
  end
end
