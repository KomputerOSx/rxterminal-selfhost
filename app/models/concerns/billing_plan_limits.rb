# frozen_string_literal: true

module BillingPlanLimits
  extend ActiveSupport::Concern

  def plan_limits
    effective_limits
  end

  def within_member_limit?
    limit = plan_limits.max_users
    return true if limit.nil?

    member_count_with_pending < limit
  end

  def within_service_limit?
    limit = plan_limits.max_services
    return true if limit.nil?

    billable_services_count < limit
  end

  def within_upsell_rule_limit?
    limit = plan_limits.max_upsell_rules
    return true if limit.nil?

    billable_upsell_rules_count < limit
  end

  def within_monthly_request_limit?(at: Time.current)
    limit = plan_limits.max_monthly_requests
    return true if limit.nil?

    monthly_request_count(at: at) < limit
  end

  def monthly_request_count(at: Time.current)
    service_requests.in_calendar_month(at).count
  end

  def appointments_enabled?
    plan_limits.appointments_enabled
  end

  def calendars_enabled?
    plan_limits.calendars_enabled
  end

  def kiosk_enabled?
    plan_limits.kiosk_enabled
  end

  def custom_domain_enabled?
    plan_limits.custom_domain?
  end

  def audit_log_retention_days
    plan_limits.audit_log_retention_days
  end

  def audit_logs_scope(relation = AuditLog.all)
    retention_days = audit_log_retention_days
    return relation if retention_days.nil?

    relation.where(created_at: retention_days.days.ago..)
  end

  PlanUsageItem = Data.define(:key, :label, :kind, :used, :limit, :at_limit, :enabled, :value_label)

  def plan_usage_items
    limits = plan_limits
    [
      count_usage_item(:members, "Members", member_count_with_pending, limits.max_users, at_member_limit?),
      count_usage_item(:services, "Services", billable_services_count, limits.max_services, at_service_limit?),
      count_usage_item(:upsell_rules, "Upsell rules", billable_upsell_rules_count, limits.max_upsell_rules,
        at_upsell_rule_limit?),
      count_usage_item(:monthly_requests, "Requests this month", monthly_request_count, limits.max_monthly_requests,
        at_monthly_request_limit?),
      feature_usage_item(:appointments, "Appointments", limits.appointments_enabled),
      feature_usage_item(:calendars, "Calendars", limits.calendars_enabled),
      feature_usage_item(:kiosk, "Kiosk devices", limits.kiosk_enabled),
      feature_usage_item(:custom_domain, "Custom domain", limits.custom_domain?),
      retention_usage_item(limits.audit_log_retention_days)
    ]
  end

  def billable_services_count
    services.counting_toward_plan_limit.count
  end

  def billable_upsell_rules_count
    upsell_rules.counting_toward_plan_limit.count
  end

  private

  def effective_limits
    (current_plan || Billing::Plans::STARTER).limits
  end

  def count_usage_item(key, label, used, limit, at_limit)
    PlanUsageItem.new(key: key, label: label, kind: :count, used: used, limit: limit, at_limit: at_limit,
      enabled: nil, value_label: nil)
  end

  def feature_usage_item(key, label, enabled)
    PlanUsageItem.new(key: key, label: label, kind: :feature, used: nil, limit: nil, at_limit: false,
      enabled: enabled, value_label: nil)
  end

  def retention_usage_item(days)
    PlanUsageItem.new(
      key: :audit_logs,
      label: "Audit log history",
      kind: :retention,
      used: nil,
      limit: nil,
      at_limit: false,
      enabled: nil,
      value_label: days ? "Last #{days} days" : "Unlimited"
    )
  end
end
