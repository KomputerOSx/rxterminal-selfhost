# frozen_string_literal: true

module Org
  class AuditLogsController < BaseController
    before_action { authorize Current.organization, policy_class: AuditLogPolicy }
    before_action :redirect_to_default_range, only: :index
    before_action :set_audit_log, only: :show

    def index
      @result = AuditLogSearch.call(params, organization_id: Current.organization.id)
      @filters_applied = @result.filters_applied
      @matched_users = @result.matched_users
      @audit_logs = @result.audit_logs
      @sort_column = @result.sort_column
      @sort_direction = @result.sort_direction
      @filter_params = @result.filter_params
    end

    def show
      @audit_logs_back_path = audit_logs_back_path
      @related_logs = if @audit_log.user
        AuditLogSearch.organization_scope(Current.organization.id)
          .where(user: @audit_log.user)
          .where.not(id: @audit_log.id)
          .recent
          .limit(10)
      else
        AuditLog.none
      end
    end

    private

    def redirect_to_default_range
      return if params.except(:controller, :action, :page, :sort, :direction).present?

      default_days = Current.organization.audit_log_retention_days || 7
      redirect_to org_audit_logs_path(
        date_from: helpers.audit_log_filter_datetime(default_days.days.ago),
        date_to: helpers.audit_log_filter_datetime(Time.current)
      )
    end

    def set_audit_log
      @audit_log = AuditLog.find(params[:id])
      AuditLogOrganizationResolver.preload!([ @audit_log ])

      unless @audit_log.resolved_organization_id == Current.organization.id
        raise Pundit::NotAuthorizedError
      end
    end

    def audit_logs_back_path
      return_to = params[:return_to].to_s

      return return_to if return_to.start_with?(org_audit_logs_path)

      org_audit_logs_path
    end
  end
end
