# frozen_string_literal: true

class AddKnownUserAgentsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :known_user_agents, :json, default: [], null: false
  end
end
