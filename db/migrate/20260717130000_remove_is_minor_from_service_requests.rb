# frozen_string_literal: true

class RemoveIsMinorFromServiceRequests < ActiveRecord::Migration[8.1]
  def change
    remove_index :service_requests, :is_minor, if_exists: true
    remove_column :service_requests, :is_minor, :boolean, default: false, null: false
  end
end
