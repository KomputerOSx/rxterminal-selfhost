# frozen_string_literal: true

class CustomerPiiLookup
  Result = Data.define(:appointments, :service_requests)

  def initialize(organization_ids: [], first_name: nil, last_name: nil, dob: nil, postcode: nil)
    @organization_ids = Array(organization_ids).filter_map { |id| id.presence&.to_i }.uniq
    @first_name = CustomerPiiMatcher.normalize_name(first_name)
    @last_name = CustomerPiiMatcher.normalize_name(last_name)
    @postcode = postcode.to_s.strip.presence
    @dob = dob
  end

  def call
    return empty_result unless searchable?

    appointments = matching_records(appointment_scope)
    service_requests = matching_records(service_request_scope)

    expand_linked_records!(appointments, service_requests)

    Result.new(appointments:, service_requests:)
  end

  private

  def searchable?
    return false unless @first_name.present? && @last_name.present?

    @dob.is_a?(Date) || @organization_ids.any?
  end

  def empty_result
    Result.new(appointments: [], service_requests: [])
  end

  def matching_records(scope)
    scoped = @dob.is_a?(Date) ? scope.where(dob: @dob) : scope
    sql_matches = scoped.to_a.select { |record| record_match?(record) }
    return sql_matches if sql_matches.any?

    scope.find_each.filter { |record| record_match?(record) }
  end

  def record_match?(record)
    CustomerPiiMatcher.dob_match?(record.dob, @dob) &&
      CustomerPiiMatcher.names_match?(record.first_name, record.last_name, @first_name, @last_name) &&
      CustomerPiiMatcher.postcode_match?(record.postcode, @postcode)
  end

  def expand_linked_records!(appointments, service_requests)
    appointments.dup.each do |appointment|
      linked = appointment.service_request
      next if linked.nil? || linked.pii_redacted? || service_requests.include?(linked)

      service_requests << linked
    end

    service_requests.dup.each do |service_request|
      linked = service_request.appointment
      next if linked.nil? || linked.pii_redacted? || appointments.include?(linked)

      appointments << linked
    end
  end

  def appointment_scope
    scope = Appointment.not_redacted.includes(:organization, :service, :service_request)
    scope = scope.where(organization_id: @organization_ids) if @organization_ids.any?
    scope
  end

  def service_request_scope
    scope = ServiceRequest.not_redacted.includes(:organization, :service, :appointment)
    scope = scope.where(organization_id: @organization_ids) if @organization_ids.any?
    scope
  end
end
