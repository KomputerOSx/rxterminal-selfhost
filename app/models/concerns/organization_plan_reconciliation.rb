# frozen_string_literal: true

module OrganizationPlanReconciliation
  extend ActiveSupport::Concern

  def downgrade_to_starter_requires_reconciliation?(target_plan = Billing::Plans::STARTER)
    return false unless target_plan.key == Billing::Plans::STARTER.key

    Billing::PlanReconciliation.new(self, target_plan: target_plan, mode: :scheduled).applies?
  end

  def require_plan_reconciliation_blocking!
    update!(plan_reconciliation_blocking_at: Time.current, plan_reconciliation_completed_at: nil)
  end

  def plan_reconciliation_pending_apply?
    plan_reconciliation_choices.present? &&
      plan_reconciliation_applied_at.blank? &&
      plan_reconciliation_choices["mode"] == "scheduled"
  end

  def apply_plan_reconciliation!(choices = plan_reconciliation_choices)
    choices = choices.to_h.stringify_keys
    now = Time.current

    transaction do
      apply_reconciliation_member_removals!
      apply_reconciliation_service_archives!(Array(choices["service_ids"]))
      apply_reconciliation_upsell_archives!(choices["upsell_rule_id"])
      apply_reconciliation_kiosk_deactivations!

      update!(
        plan_reconciliation_choices: choices,
        plan_reconciliation_applied_at: now,
        plan_reconciliation_completed_at: now,
        plan_reconciliation_blocking_at: nil
      )
    end
  end

  def apply_pending_plan_reconciliation_if_needed!
    return unless current_plan&.key == Billing::Plans::STARTER.key
    return if plan_reconciliation_applied_at.present?
    return if plan_reconciliation_choices.blank?

    apply_plan_reconciliation!
  end

  def restore_plan_reconciliation_archives!
    services.where.not(archived_at: nil).update_all(archived_at: nil, active: true, updated_at: Time.current)
    upsell_rules.where.not(archived_at: nil).update_all(archived_at: nil, active: true, updated_at: Time.current)
    devices.where.not(deactivated_at: nil).update_all(deactivated_at: nil, status: "active", updated_at: Time.current)
  end

  def billable_kiosk_devices_count
    devices.where.not(status: "revoked").where(deactivated_at: nil).count
  end

  private

  def apply_reconciliation_member_removals!
    removable = memberships.includes(:roles).reject { |membership| membership.has_role?(Role::APP_OWNER, scope: :app) }
    removable.each(&:destroy!)
    organization_invitations.outstanding.destroy_all
  end

  def apply_reconciliation_service_archives!(kept_service_ids)
    kept_service_ids = Array(kept_service_ids).map(&:to_i)
    return if kept_service_ids.empty?

    services.plan_active.where.not(id: kept_service_ids).update_all(
      archived_at: Time.current,
      active: false,
      updated_at: Time.current
    )
  end

  def apply_reconciliation_upsell_archives!(kept_rule_id)
    kept_rule_id = kept_rule_id.to_i
    return if kept_rule_id.zero?

    upsell_rules.plan_active.where.not(id: kept_rule_id).update_all(
      archived_at: Time.current,
      active: false,
      updated_at: Time.current
    )
  end

  def apply_reconciliation_kiosk_deactivations!
    devices.where(deactivated_at: nil).update_all(
      deactivated_at: Time.current,
      status: "inactive",
      updated_at: Time.current
    )
  end
end
