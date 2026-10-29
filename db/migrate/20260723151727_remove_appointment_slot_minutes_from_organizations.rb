class RemoveAppointmentSlotMinutesFromOrganizations < ActiveRecord::Migration[8.1]
  def change
    remove_column :organizations, :appointment_slot_minutes, :integer, null: false, default: 15
  end
end
