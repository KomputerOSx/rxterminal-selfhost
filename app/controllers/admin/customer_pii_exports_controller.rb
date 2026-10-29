# frozen_string_literal: true

module Admin
  class CustomerPiiExportsController < BaseController
    def show
      cached = CustomerPiiReportDelivery.fetch(params[:token])
      head :not_found and return unless cached

      authorize_report!(cached[:report_type])

      send_data cached[:content],
        filename: cached[:filename],
        type: cached[:content_type] || CustomerPiiReportDelivery::CONTENT_TYPE,
        disposition: "attachment"
    end

    private

    def authorize_report!(report_type)
      case report_type
      when "subject-access"
        authorize :system, :manage_subject_access?, policy_class: SystemPolicy
      when "customer-erasure"
        authorize :system, :manage_customer_erasure?, policy_class: SystemPolicy
      else
        head :not_found
      end
    end
  end
end
