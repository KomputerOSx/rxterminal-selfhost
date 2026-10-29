# frozen_string_literal: true

require "csv"

class SubjectAccessRequestExport
  APPOINTMENT_COLUMNS = [
    [ "id", :id ],
    [ "organization_id", ->(row) { row.dig(:organization, :id) } ],
    [ "organization_name", ->(row) { row.dig(:organization, :name) } ],
    [ "organization_slug", ->(row) { row.dig(:organization, :slug) } ],
    [ "service_id", ->(row) { row.dig(:service, :id) } ],
    [ "service_name", ->(row) { row.dig(:service, :display_name) } ],
    [ "booking_reference", :booking_reference ],
    [ "first_name", :first_name ],
    [ "last_name", :last_name ],
    [ "dob", :dob ],
    [ "postcode", :postcode ],
    [ "email", :email ],
    [ "notes", :notes ],
    [ "status", :status ],
    [ "appointment_date", :appointment_date ],
    [ "appointment_time", :appointment_time ],
    [ "checked_in_at", :checked_in_at ],
    [ "cancelled_at", :cancelled_at ],
    [ "no_show_at", :no_show_at ],
    [ "service_request_id", :service_request_id ],
    [ "created_at", :created_at ],
    [ "updated_at", :updated_at ]
  ].freeze

  SERVICE_REQUEST_COLUMNS = [
    [ "id", :id ],
    [ "organization_id", ->(row) { row.dig(:organization, :id) } ],
    [ "organization_name", ->(row) { row.dig(:organization, :name) } ],
    [ "organization_slug", ->(row) { row.dig(:organization, :slug) } ],
    [ "service_id", ->(row) { row.dig(:service, :id) } ],
    [ "service_name", ->(row) { row.dig(:service, :display_name) } ],
    [ "first_name", :first_name ],
    [ "last_name", :last_name ],
    [ "dob", :dob ],
    [ "postcode", :postcode ],
    [ "description", :description ],
    [ "submission_ip", :submission_ip ],
    [ "status", :status ],
    [ "request_type", :request_type ],
    [ "queue_number", :queue_number ],
    [ "queue_date", :queue_date ],
    [ "privacy_requested", :privacy_requested ],
    [ "called_at", :called_at ],
    [ "completed_at", :completed_at ],
    [ "appointment_id", :appointment_id ],
    [ "created_at", :created_at ],
    [ "updated_at", :updated_at ]
  ].freeze

  def self.build(lookup_result, search_criteria: {})
    new(lookup_result, search_criteria:).build
  end

  def self.to_csv(lookup_result, search_criteria: {})
    new(lookup_result, search_criteria:).to_csv
  end

  def initialize(lookup_result, search_criteria: {})
    @lookup_result = lookup_result
    @search_criteria = search_criteria
  end

  def build
    {
      exported_at: Time.current.iso8601,
      search_criteria: @search_criteria,
      appointments: @lookup_result.appointments.map { |appointment| serialize_appointment(appointment) },
      service_requests: @lookup_result.service_requests.map { |service_request| serialize_service_request(service_request) }
    }
  end

  def to_csv
    payload = build

    CSV.generate do |csv|
      csv << [ "exported_at", payload[:exported_at] ]
      payload[:search_criteria].each do |key, value|
        csv << [ key.to_s, value ]
      end
      csv << []

      csv << [ "Appointments" ]
      csv << APPOINTMENT_COLUMNS.map(&:first)
      payload[:appointments].each do |row|
        csv << csv_row(row, APPOINTMENT_COLUMNS)
      end

      csv << []
      csv << [ "Service requests" ]
      csv << SERVICE_REQUEST_COLUMNS.map(&:first)
      payload[:service_requests].each do |row|
        csv << csv_row(row, SERVICE_REQUEST_COLUMNS)
      end
    end
  end

  private

  def csv_row(row, columns)
    columns.map do |_header, accessor|
      value = accessor.is_a?(Proc) ? accessor.call(row) : row[accessor]
      format_csv_value(value)
    end
  end

  def format_csv_value(value)
    case value
    when nil then nil
    when TrueClass, FalseClass then value ? "yes" : "no"
    else value.to_s
    end
  end

  def serialize_appointment(appointment)
    {
      id: appointment.id,
      organization: organization_payload(appointment.organization),
      service: service_payload(appointment.service),
      booking_reference: appointment.booking_reference,
      first_name: appointment.first_name,
      last_name: appointment.last_name,
      dob: appointment.dob&.iso8601,
      postcode: appointment.postcode,
      email: appointment.email,
      notes: appointment.notes,
      status: appointment.status,
      appointment_date: appointment.appointment_date&.iso8601,
      appointment_time: appointment.appointment_time&.strftime("%H:%M"),
      checked_in_at: appointment.checked_in_at&.iso8601,
      cancelled_at: appointment.cancelled_at&.iso8601,
      no_show_at: appointment.no_show_at&.iso8601,
      service_request_id: appointment.service_request_id,
      created_at: appointment.created_at.iso8601,
      updated_at: appointment.updated_at.iso8601
    }
  end

  def serialize_service_request(service_request)
    {
      id: service_request.id,
      organization: organization_payload(service_request.organization),
      service: service_payload(service_request.service),
      first_name: service_request.first_name,
      last_name: service_request.last_name,
      dob: service_request.dob&.iso8601,
      postcode: service_request.postcode,
      description: service_request.description,
      submission_ip: service_request.submission_ip,
      status: service_request.status,
      request_type: service_request.request_type,
      queue_number: service_request.queue_number,
      queue_date: service_request.queue_date&.iso8601,
      privacy_requested: service_request.privacy_requested,
      called_at: service_request.called_at&.iso8601,
      completed_at: service_request.completed_at&.iso8601,
      appointment_id: service_request.appointment&.id,
      created_at: service_request.created_at.iso8601,
      updated_at: service_request.updated_at.iso8601
    }
  end

  def organization_payload(organization)
    {
      id: organization.id,
      name: organization.name,
      slug: organization.slug
    }
  end

  def service_payload(service)
    {
      id: service.id,
      display_name: service.display_name
    }
  end
end
