class AddAppointmentEmailSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :require_appointment_email, :boolean, default: false, null: false
    add_column :organizations, :appointment_email_message, :text
    add_column :appointments, :cancellation_reason, :text
  end
end
