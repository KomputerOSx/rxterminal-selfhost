# frozen_string_literal: true

class AddTrialFieldsForLaunch < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :trial_granted_at, :datetime
    add_column :organizations, :trial_ends_at, :datetime
    add_column :organizations, :trial_plan_key, :string
  end
end
