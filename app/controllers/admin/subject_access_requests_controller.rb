# frozen_string_literal: true

module Admin
  class SubjectAccessRequestsController < BaseController
    include Admin::CustomerPiiOrganizations
    include Admin::CustomerPiiReportExport

    before_action { authorize :system, :manage_subject_access?, policy_class: SystemPolicy }

    def new
      @search = CustomerPiiSearch.new
      load_customer_pii_organizations
    end

    def create
      if params[:export].present? || params[:email_export].present?
        perform_report_export(report_type: "subject-access", audit_event: :subject_access_exported)
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

    def export_redirect_path
      new_admin_subject_access_request_path
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
