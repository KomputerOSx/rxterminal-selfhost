# frozen_string_literal: true

class CustomerPiiReportMailer < ApplicationMailer
  def export(recipient_email:, first_name:, total_records:, csv_data:, filename:, report_label:)
    @first_name = first_name
    @total_records = total_records
    @report_label = report_label
    @generated_at = Time.current

    attachments[filename] = {
      mime_type: CustomerPiiReportDelivery::CONTENT_TYPE,
      content: csv_data
    }

    mail(
      to: recipient_email,
      subject: "Your #{report_label} data export - RxTerminal"
    )
  end
end
