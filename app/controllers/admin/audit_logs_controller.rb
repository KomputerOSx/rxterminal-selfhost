# frozen_string_literal: true

module Admin
  class AuditLogsController < BaseController
    before_action { authorize :system, :view_audit_logs?, policy_class: SystemPolicy }
    before_action :redirect_to_default_range, only: :index

    def index
      @organizations = Organization.order(:name)
      @result = AuditLogSearch.call(params)
      @filters_applied = @result.filters_applied
      @matched_users = @result.matched_users
      @audit_logs = @result.audit_logs
      @sort_column = @result.sort_column
      @sort_direction = @result.sort_direction
      @filter_params = @result.filter_params
    end

    def show
      @audit_log = AuditLog.find(params[:id])
      AuditLogOrganizationResolver.preload!([ @audit_log ])
      @audit_logs_back_path = audit_logs_back_path
      @related_logs = if @audit_log.user
        AuditLog.where(user: @audit_log.user).where.not(id: @audit_log.id).recent.limit(10)
      else
        AuditLog.none
      end
    end

    private

    def redirect_to_default_range
      return if params.except(:controller, :action, :page, :sort, :direction).present?

      redirect_to admin_audit_logs_path(
        date_from: helpers.audit_log_filter_datetime(7.days.ago),
        date_to: helpers.audit_log_filter_datetime(Time.current)
      )
    end

    def audit_logs_back_path
      return_to = params[:return_to].to_s

      return return_to if return_to.start_with?(admin_audit_logs_path)

      admin_audit_logs_path
    end
  end
end
