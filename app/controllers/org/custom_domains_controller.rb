# frozen_string_literal: true

module Org
  class CustomDomainsController < BaseController
    before_action :require_business_plan!
    before_action :authorize_manage, only: [ :create, :destroy ]

    def show
      skip_authorization
    end

    def create
      if Current.organization.update(custom_domain: custom_domain_param)
        log_audit(:custom_domain_updated, resource: Current.organization, metadata: { custom_domain: Current.organization.custom_domain })
        redirect_to org_custom_domain_path, notice: "Custom domain saved. Add a DNS record to finish setup."
      else
        redirect_to org_custom_domain_path, alert: Current.organization.errors.full_messages.to_sentence
      end
    end

    def destroy
      Current.organization.update!(custom_domain: nil)
      log_audit(:custom_domain_removed, resource: Current.organization)
      redirect_to org_custom_domain_path, notice: "Custom domain removed."
    end

    def status
      skip_authorization

      unless Current.organization.custom_domain.present?
        return render json: { status: "pending", message: "No domain configured." }
      end

      result = CustomDomainDnsCheck.call(Current.organization.custom_domain)
      render json: result
    end

    private

    def require_business_plan!
      return if Current.organization.custom_domain_allowed?

      alert = "Custom domains require the Business plan."
      if current_user.has_permission?("app.billing.manage", organization: Current.organization)
        redirect_to billing_path, alert: alert
      else
        redirect_to org_settings_path, alert: alert
      end
    end

    def authorize_manage
      authorize Current.organization, :update?
    end

    def custom_domain_param
      params.require(:organization).permit(:custom_domain)[:custom_domain]
    end
  end
end
