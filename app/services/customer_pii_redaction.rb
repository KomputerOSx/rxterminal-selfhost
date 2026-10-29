# frozen_string_literal: true

class CustomerPiiRedaction
  Result = Data.define(:appointments, :service_requests)

  def self.call(appointment_ids: [], service_request_ids: [])
    new(appointment_ids:, service_request_ids:).call
  end

  def initialize(appointment_ids: [], service_request_ids: [])
    @appointment_ids = Array(appointment_ids).map(&:presence).compact.map(&:to_i).uniq
    @service_request_ids = Array(service_request_ids).map(&:presence).compact.map(&:to_i).uniq
  end

  def call
    redacted_appointments = []
    redacted_service_requests = []

    ActiveRecord::Base.transaction do
      appointments.each do |appointment|
        next unless appointment.redact_pii!

        redacted_appointments << appointment
      end

      service_requests.each do |service_request|
        next unless service_request.redact_pii!

        redacted_service_requests << service_request
      end
    end

    Result.new(appointments: redacted_appointments, service_requests: redacted_service_requests)
  end

  private

  def appointments
    Appointment.not_redacted.where(id: @appointment_ids)
  end

  def service_requests
    ServiceRequest.not_redacted.where(id: @service_request_ids)
  end
end
