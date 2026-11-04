# frozen_string_literal: true

class DataRetentionJob < ApplicationJob
  queue_as :default

  RETENTION_PERIOD = 90.days

  def perform
    cutoff = RETENTION_PERIOD.ago
    purge_old_audit_logs

    service_requests_redacted = redact_service_requests(cutoff)
    appointments_redacted = redact_appointments(cutoff)

    Rails.logger.info(
      "[DataRetentionJob] PII redacted - " \
      "#{service_requests_redacted} service_requests, #{appointments_redacted} appointments"
    )
  end

  private

  # AUDIT_LOG_RETENTION_DAYS unset (the default) keeps audit logs forever.
  def purge_old_audit_logs
    days = ENV["AUDIT_LOG_RETENTION_DAYS"].to_i
    return unless days.positive?

    AuditLog.where("created_at < ?", days.days.ago).delete_all
  end

  def redact_service_requests(cutoff)
    count = 0
    ServiceRequest.not_redacted
      .where("created_at < ?", cutoff)
      .find_each do |service_request|
        count += 1 if service_request.redact_pii!
      end
    count
  end

  def redact_appointments(cutoff)
    count = 0
    Appointment.not_redacted
      .where("created_at < ?", cutoff)
      .find_each do |appointment|
        count += 1 if appointment.redact_pii!
      end
    count
  end
end
