# frozen_string_literal: true

class AppointmentReminderJob < ApplicationJob
  queue_as :default

  # Runs off the server's UTC clock (see config/recurring.yml), not each organization's own
  # time zone, so a fixed 1-day lookahead could land on the wrong local day for organizations
  # far enough west of UTC. A 2-day lookahead gives enough buffer to absorb that skew without
  # needing to run this per-organization-time-zone.
  REMINDER_LEAD_DAYS = 2

  def perform
    reminder_date = Date.current + REMINDER_LEAD_DAYS.days

    Appointment
      .where(appointment_date: reminder_date, status: "booked")
      .find_each do |appointment|
        next if appointment.email.blank?

        AppointmentMailer.reminder(appointment).deliver_later
      end

    Rails.logger.info "[AppointmentReminderJob] Reminders sent for #{reminder_date.strftime("%d %b %Y")}"
  end
end
