# frozen_string_literal: true

module Admin
  class CustomerErasuresController < BaseController
    include Admin::CustomerPiiOrganizations
    include Admin::CustomerPiiReportExport

    before_action { authorize :system, :manage_customer_erasure?, policy_class: SystemPolicy }

    def new
      @search = CustomerPiiSearch.new
      load_customer_pii_organizations
    end

    def create
      if params[:export].present? || params[:email_export].present?
        perform_report_export(report_type: "customer-erasure", audit_event: :customer_pii_report_exported)
      elsif params[:confirm_erasure].present?
        perform_erasure
      else
        perform_search
      end
    end

    private

    def perform_search
      @search = CustomerPiiSearch.new(search_params)
      load_customer_pii_organizations

      if @search.valid?
        @results = @search.lookup
        render :new
      else
        render :new, status: :unprocessable_entity
      end
    end

    def perform_erasure
      unless params[:confirm].present?
        redirect_to new_admin_customer_erasure_path, alert: "Confirm that you understand this action is irreversible."
        return
      end

      appointments = Appointment.not_redacted
        .where(id: Array(params[:appointment_ids]).map(&:presence).compact)
        .includes(:organization, :service)
      service_requests = ServiceRequest.not_redacted
        .where(id: Array(params[:service_request_ids]).map(&:presence).compact)
        .includes(:organization, :service)

      if appointments.none? && service_requests.none?
        redirect_to new_admin_customer_erasure_path, alert: "No records were redacted. They may already have been erased."
        return
      end

      content, filename, export_results = build_export_from_records(
        appointments: appointments.to_a,
        service_requests: service_requests.to_a,
        search_criteria: search_params.to_h,
        report_type: "customer-erasure"
      )

      redacted_appointments = []
      redacted_service_requests = []

      ActiveRecord::Base.transaction do
        appointments.each do |appointment|
          redacted_appointments << appointment if appointment.redact_pii!
        end
        service_requests.each do |service_request|
          redacted_service_requests << service_request if service_request.redact_pii!
        end
      end

      log_audit(
        :customer_pii_redacted,
        metadata: {
          appointment_ids: redacted_appointments.map(&:id),
          service_request_ids: redacted_service_requests.map(&:id),
          appointment_count: redacted_appointments.size,
          service_request_count: redacted_service_requests.size
        }
      )

      @export_token = CustomerPiiReportDelivery.store(
        content: content,
        filename: filename,
        report_type: "customer-erasure",
        appointment_ids: export_results.appointments.map(&:id),
        service_request_ids: export_results.service_requests.map(&:id),
        search_criteria: search_params.to_h
      )
      @search = CustomerPiiSearch.new(search_params)
      load_customer_pii_organizations
      @erasure_complete = true
      flash.now[:notice] =
        "Redacted PII on #{redacted_appointments.size} appointment(s) and #{redacted_service_requests.size} queue record(s). " \
        "Download or email the report below if needed."
      render :new
    end

    def export_redirect_path
      new_admin_customer_erasure_path
    end

    def search_params
      params.fetch(:customer_pii_search, {}).permit(
        :first_name,
        :last_name,
        :display_dob,
        :postcode,
        organization_ids: []
      )
    end
  end
end
