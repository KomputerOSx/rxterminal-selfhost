# frozen_string_literal: true

module PlanReconciliationGate
  extend ActiveSupport::Concern
  include SubscriptionGateExemptions

  included do
    before_action :enforce_plan_reconciliation_gate!
  end

  private

  def enforce_plan_reconciliation_gate!
    return unless current_user
    return if plan_reconciliation_gate_exempt?
    return unless Current.organization&.plan_reconciliation_required?

    redirect_to billing_plan_reconciliation_path, alert: "Complete your plan setup to continue using this organization."
  end

  def plan_reconciliation_gate_exempt?
    subscription_gate_exempt?
  end
end
