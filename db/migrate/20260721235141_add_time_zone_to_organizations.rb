class AddTimeZoneToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :time_zone, :string, null: false, default: "UTC"
  end
end
