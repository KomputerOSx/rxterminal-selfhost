class AddAppointmentBookingModeToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :appointment_booking_mode, :string, null: false, default: "rolling"
  end
end
