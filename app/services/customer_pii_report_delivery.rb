# frozen_string_literal: true

class CustomerPiiReportDelivery
  CACHE_PREFIX = "admin/customer_pii_export"
  CACHE_TTL = 15.minutes
  CONTENT_TYPE = "text/csv"

  REPORT_LABELS = {
    "subject-access" => "Subject access request",
    "customer-erasure" => "Customer erasure"
  }.freeze

  def self.filename(report_type:)
    prefix = report_type.tr("_", "-")
    "#{prefix}-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"
  end

  def self.csv_string(results, search_criteria:, report_type:)
    SubjectAccessRequestExport.to_csv(
      results,
      search_criteria: search_criteria.merge(report_type: report_type)
    )
  end

  def self.store(content:, filename:, report_type:, appointment_ids: [], service_request_ids: [], search_criteria: {})
    token = SecureRandom.urlsafe_base64(32)
    Rails.cache.write(
      cache_key(token),
      {
        content: content,
        filename: filename,
        content_type: CONTENT_TYPE,
        report_type: report_type,
        appointment_ids: appointment_ids,
        service_request_ids: service_request_ids,
        search_criteria: search_criteria
      },
      expires_in: CACHE_TTL
    )
    token
  end

  def self.fetch(token)
    Rails.cache.read(cache_key(token))
  end

  def self.email!(recipient_email:, first_name:, total_records:, csv_data:, filename:, report_type:)
    CustomerPiiReportMailer.export(
      recipient_email: recipient_email,
      first_name: first_name,
      total_records: total_records,
      csv_data: csv_data,
      filename: filename,
      report_label: REPORT_LABELS.fetch(report_type)
    ).deliver_later
  end

  def self.mask_email(email)
    local_part, domain = email.to_s.split("@", 2)
    return "[invalid]" if local_part.blank? || domain.blank?

    "#{local_part[0]}***@#{domain}"
  end

  def self.valid_email?(email)
    email.to_s.strip.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def self.cache_key(token)
    "#{CACHE_PREFIX}/#{token}"
  end

  private_class_method :cache_key
end
