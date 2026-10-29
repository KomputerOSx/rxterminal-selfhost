# frozen_string_literal: true

module PlanLimitsHelper
  def plan_limit_upgrade_message(limit_label, organization: Current.organization)
    plan_name = organization.current_plan&.name || Billing::Plans::STARTER.name
    "Your #{plan_name} plan's #{limit_label} limit has been reached. Upgrade to #{Billing::Plans::BUSINESS.name} on Billing to continue."
  end

  def plan_feature_upgrade_message(feature_label, organization: Current.organization)
    "Upgrade to #{Billing::Plans::BUSINESS.name} on Billing to enable #{feature_label}."
  end

  def plan_gated_nav_badge
    tag.span("Business", class: "badge badge-warning badge-xs shrink-0")
  end
end
