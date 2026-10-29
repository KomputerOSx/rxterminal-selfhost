class RemoveKioskAnimationFromOrganizations < ActiveRecord::Migration[8.1]
  def change
    remove_column :organizations, :kiosk_animation, :string, null: false, default: "fade"
  end
end
