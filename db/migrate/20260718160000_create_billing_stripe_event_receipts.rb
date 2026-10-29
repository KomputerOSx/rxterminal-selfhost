class CreateBillingStripeEventReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_stripe_event_receipts do |t|
      t.string :stripe_event_id, null: false
      t.string :event_type, null: false
      t.datetime :received_at, null: false

      t.timestamps
    end

    add_index :billing_stripe_event_receipts, :stripe_event_id, unique: true
    add_index :billing_stripe_event_receipts, :received_at
  end
end
