# frozen_string_literal: true

class RemoveIsMinorFromAppointments < ActiveRecord::Migration[8.1]
  def change
    remove_index :appointments, :is_minor, if_exists: true
    remove_column :appointments, :is_minor, :boolean, default: false, null: false
  end
end
