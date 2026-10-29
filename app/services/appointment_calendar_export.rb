# frozen_string_literal: true

class AppointmentCalendarExport
  def self.generate(appointment)
    new(appointment).generate
  end

  def self.filename(appointment)
    "appointment-#{appointment.booking_reference}.ics"
  end

  def initialize(appointment)
    @appointment = appointment
    @organization = appointment.organization
    @service = appointment.service
  end

  def generate
    calendar_body = <<~ICS
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:-//RxTerminal//EN
      CALSCALE:GREGORIAN
      METHOD:PUBLISH
      BEGIN:VEVENT
      UID:#{@appointment.booking_reference}@rxterminal
      DTSTART:#{start_dt.utc.strftime("%Y%m%dT%H%M%SZ")}
      DTEND:#{end_dt.utc.strftime("%Y%m%dT%H%M%SZ")}
      SUMMARY:#{@service.display_name} at #{@organization.name}
      DESCRIPTION:Booking reference: #{@appointment.booking_reference}
      STATUS:CONFIRMED
      END:VEVENT
      END:VCALENDAR
    ICS

    calendar_body.gsub("\n", "\r\n")
  end

  private

  def start_dt
    Time.zone.local(
      @appointment.appointment_date.year,
      @appointment.appointment_date.month,
      @appointment.appointment_date.day,
      @appointment.appointment_time.hour,
      @appointment.appointment_time.min
    )
  end

  def end_dt
    start_dt + (@service.estimated_duration || 15).minutes
  end
end
