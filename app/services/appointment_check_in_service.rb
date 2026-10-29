# frozen_string_literal: true

class AppointmentCheckInService
  def self.find_by_reference(organization, raw_reference)
    reference = raw_reference.to_s.strip.upcase
    return nil if reference.blank?

    organization.appointments.not_redacted.find_by(booking_reference: reference)
  end

  def self.find_candidates(organization:, last_name:, dob: nil)
    name = last_name.to_s.strip
    return [] if name.blank?

    scope = organization.appointments.not_redacted
      .where(status: "booked")
      .includes(:service)
    scope = scope.where(dob: dob) if dob.is_a?(Date)

    scope.to_a
      .select { |appointment| appointment.last_name.to_s.casecmp?(name) }
      .sort_by { |appointment| [ appointment.appointment_date, appointment.appointment_time ] }
  end
end
