module Org
  class BaseController < ApplicationController
    include PlanLimitEnforcement

    before_action :require_current_organization!
    around_action :use_organization_time_zone
    after_action :verify_authorized

    private

    def require_current_organization!
      redirect_to dashboard_path, alert: "No organization selected." unless Current.organization
    end

    # So "today"/Date.current-driven queue and appointment logic (org/queue, org/appointments,
    # org/analytics, etc.) reflects the organization's own local day, not the server's.
    def use_organization_time_zone(&block)
      return yield unless Current.organization

      Time.use_zone(Current.organization.time_zone, &block)
    end
  end
end
