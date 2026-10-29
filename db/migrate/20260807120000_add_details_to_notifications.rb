# frozen_string_literal: true

class AddDetailsToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :details, :text
  end
end
