class AddUrlAndCategoryToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :url, :string
    add_column :notifications, :category, :string
    add_index :notifications, :category
  end
end
