# frozen_string_literal: true

class AppointmentMailer < ApplicationMailer
  layout "appointment_mailer"

  def booking_confirmation(appointment)
    return if appointment.email.blank?

    assign_appointment_context(appointment)
    attach_calendar

    mail(
      to: appointment.email,
      subject: "Appointment Confirmed - #{@organization.name}"
    )
  end

  def cancellation(appointment)
    return if appointment.email.blank?

    assign_appointment_context(appointment)

    mail(
      to: appointment.email,
      subject: "Appointment Cancelled - #{@organization.name}"
    )
  end

  def reminder(appointment)
    return if appointment.email.blank?

    assign_appointment_context(appointment)
    attach_calendar

    mail(
      to: appointment.email,
      subject: "Reminder: Your appointment on #{appointment.appointment_date.strftime("%A, %d %B")} - #{@organization.name}"
    )
  end

  private

  def assign_appointment_context(appointment)
    @appointment = appointment
    @organization = appointment.organization
    @service = appointment.service
  end

  def attach_calendar
    attachments[AppointmentCalendarExport.filename(@appointment)] = {
      mime_type: "text/calendar",
      content: AppointmentCalendarExport.generate(@appointment)
    }
  end
end
