# frozen_string_literal: true

module OrganizationSubscriptionState
  extend ActiveSupport::Concern

  # A live billing commitment: trialing, active, past_due, or canceled but still within the
  # current paid/grace period. Used for lockout (§4) and account-deletion guards (§7).
  def active_subscription?
    return true if on_trial?

    subscription = pay_subscription
    return false unless subscription

    return true if subscription.past_due?
    return true if subscription.on_grace_period?

    subscription.active?
  end

  def past_due?
    pay_subscription&.past_due? == true
  end

  # Computed lockout — not stored. past_due alone does not lock; terminal canceled/unpaid does.
  # Orgs without a live subscription (expired trial or never subscribed) are locked.
  def locked?
    return true if subscription_terminal_lockout?
    return false if active_subscription?

    true
  end

  # Phase 7: mandatory downgrade wizard after resubscribing to Starter post-lockout.
  def plan_reconciliation_required?
    plan_reconciliation_blocking_at.present? && plan_reconciliation_completed_at.blank?
  end

  def trial_ends_at
    self[:trial_ends_at] if has_attribute?(:trial_ends_at) && self[:trial_ends_at].present?
  end

  private

  def pay_subscription
    payment_processor&.subscription
  end

  def subscription_terminal_lockout?
    subscription = pay_subscription
    return false unless subscription

    return true if subscription.unpaid?

    subscription.status == "canceled" && subscription.ended?
  end
end
