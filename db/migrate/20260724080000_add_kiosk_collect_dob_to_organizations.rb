class AddKioskCollectDobToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :kiosk_collect_dob, :boolean, null: false, default: true

    change_column_null :appointments, :dob, true
    change_column_null :service_requests, :dob, true
  end
end
