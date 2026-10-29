# frozen_string_literal: true

class AppointmentNoShowJob < ApplicationJob
  queue_as :default

  def perform
    count = Appointment.where(status: "booked")
      .where("appointment_date < ?", Date.current)
      .update_all(status: "no_show", no_show_at: Time.current)

    Rails.logger.info "[AppointmentNoShowJob] Marked #{count} appointment(s) as no_show"
  end
end
