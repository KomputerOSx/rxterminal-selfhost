# frozen_string_literal: true

module Admin
  module CustomerPiiReportExport
    extend ActiveSupport::Concern

    private

    def perform_report_export(report_type:, audit_event:)
      if params[:export_token].present?
        deliver_cached_report(report_type:, audit_event:)
      else
        deliver_search_report(report_type:, audit_event:)
      end
    end

    def deliver_search_report(report_type:, audit_event:)
      @search = CustomerPiiSearch.new(search_params)
      load_customer_pii_organizations

      unless @search.valid?
        flash.now[:alert] = "Fix the search criteria before exporting."
        render :new, status: :unprocessable_entity
        return
      end

      @results = @search.lookup
      if @results.appointments.empty? && @results.service_requests.empty?
        redirect_to export_redirect_path, alert: "No matching records to export."
        return
      end

      deliver_report(
        results: @results,
        report_type: report_type,
        audit_event: audit_event,
        search_criteria: search_params.to_h
      )
    end

    def deliver_cached_report(report_type:, audit_event:)
      cached = CustomerPiiReportDelivery.fetch(params[:export_token])
      unless cached && cached[:report_type] == report_type
        redirect_to export_redirect_path, alert: "That export link has expired. Run a new search."
        return
      end

      @export_token = params[:export_token]
      @erasure_complete = true if report_type == "customer-erasure"
      load_customer_pii_organizations if respond_to?(:load_customer_pii_organizations, true)

      content = cached[:content]
      filename = cached[:filename]
      total_records = cached[:appointment_ids].size + cached[:service_request_ids].size

      if email_export_requested?
        return unless validate_recipient_email!

        queue_report_email(
          content: content,
          filename: filename,
          report_type: report_type,
          total_records: total_records,
          search_criteria: cached[:search_criteria]
        )
        log_report_audit(
          audit_event,
          appointment_ids: cached[:appointment_ids],
          service_request_ids: cached[:service_request_ids],
          total_records: total_records,
          report_type: report_type,
          emailed: true
        )
        redirect_to export_redirect_path, notice: email_sent_notice(total_records)
        return
      end

      if download_requested?
        maybe_queue_report_email(
          content: content,
          filename: filename,
          report_type: report_type,
          total_records: total_records,
          search_criteria: cached[:search_criteria]
        )
        log_report_audit(
          audit_event,
          appointment_ids: cached[:appointment_ids],
          service_request_ids: cached[:service_request_ids],
          total_records: total_records,
          report_type: report_type,
          emailed: recipient_email.present?
        )
        send_download(content, filename)
      else
        redirect_to export_redirect_path, alert: "Choose download or email report."
      end
    end

    def deliver_report(results:, report_type:, audit_event:, search_criteria:)
      content = CustomerPiiReportDelivery.csv_string(
        results,
        search_criteria: search_criteria,
        report_type: report_type
      )
      filename = CustomerPiiReportDelivery.filename(report_type: report_type)
      total_records = results.appointments.size + results.service_requests.size

      if email_export_requested?
        return unless validate_recipient_email!(results: results)

        queue_report_email(
          content: content,
          filename: filename,
          report_type: report_type,
          total_records: total_records,
          search_criteria: search_criteria
        )
        log_report_audit(audit_event, results: results, total_records: total_records, report_type: report_type, emailed: true)
        redirect_to export_redirect_path, notice: email_sent_notice(total_records)
        return
      end

      if download_requested?
        maybe_queue_report_email(
          content: content,
          filename: filename,
          report_type: report_type,
          total_records: total_records,
          search_criteria: search_criteria
        )
        log_report_audit(audit_event, results: results, total_records: total_records, report_type: report_type, emailed: recipient_email.present?)
        send_download(content, filename)
      else
        redirect_to export_redirect_path, alert: "Choose download or email report."
      end
    end

    def build_export_from_records(appointments:, service_requests:, search_criteria:, report_type:)
      results = CustomerPiiLookup::Result.new(appointments:, service_requests:)
      content = CustomerPiiReportDelivery.csv_string(
        results,
        search_criteria: search_criteria,
        report_type: report_type
      )
      filename = CustomerPiiReportDelivery.filename(report_type: report_type)
      [ content, filename, results ]
    end

    def queue_report_email(content:, filename:, report_type:, total_records:, search_criteria:)
      CustomerPiiReportDelivery.email!(
        recipient_email: recipient_email,
        first_name: export_first_name(search_criteria),
        total_records: total_records,
        csv_data: content,
        filename: filename,
        report_type: report_type
      )
    end

    def export_first_name(search_criteria = nil)
      return @search.first_name if @search&.first_name.present?

      criteria = search_criteria || {}
      criteria["first_name"].presence || criteria[:first_name].presence || ""
    end

    def maybe_queue_report_email(content:, filename:, report_type:, total_records:, search_criteria:)
      return unless recipient_email.present? && CustomerPiiReportDelivery.valid_email?(recipient_email)

      queue_report_email(
        content: content,
        filename: filename,
        report_type: report_type,
        total_records: total_records,
        search_criteria: search_criteria
      )
    end

    def log_report_audit(audit_event, report_type:, total_records:, emailed:, results: nil, appointment_ids: nil, service_request_ids: nil)
      appointment_ids ||= results&.appointments&.map(&:id) || []
      service_request_ids ||= results&.service_requests&.map(&:id) || []

      log_audit(
        audit_event,
        metadata: {
          appointment_ids: appointment_ids,
          service_request_ids: service_request_ids,
          appointment_count: appointment_ids.size,
          service_request_count: service_request_ids.size,
          total_records: total_records,
          report_type: report_type,
          delivery_method: emailed ? "email" : "download",
          recipient_email_masked: emailed ? CustomerPiiReportDelivery.mask_email(recipient_email) : nil
        }.compact
      )
    end

    def send_download(content, filename)
      send_data content,
        filename: filename,
        type: CustomerPiiReportDelivery::CONTENT_TYPE,
        disposition: "attachment"
    end

    def validate_recipient_email!(results: nil)
      if recipient_email.blank? || !CustomerPiiReportDelivery.valid_email?(recipient_email)
        @results = results if results
        load_customer_pii_organizations if respond_to?(:load_customer_pii_organizations, true)
        flash.now[:alert] = "Enter a valid recipient email address."
        render :new, status: :unprocessable_entity
        return false
      end

      true
    end

    def recipient_email
      params[:recipient_email].to_s.strip
    end

    def download_requested?
      params[:export].present?
    end

    def email_export_requested?
      params[:email_export].present?
    end

    def email_sent_notice(total_records)
      "Report emailed to #{recipient_email} (#{total_records} record#{total_records == 1 ? '' : 's'})."
    end

    def export_redirect_path
      raise NotImplementedError
    end

    def report_params
      params.permit(:recipient_email, :export, :email_export, :export_token)
    end
  end
end
