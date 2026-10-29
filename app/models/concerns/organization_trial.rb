# frozen_string_literal: true

module OrganizationTrial
  extend ActiveSupport::Concern

  TRIAL_DAYS = 30
  DEFAULT_TRIAL_PLAN_KEY = Billing::Plans::STARTER.key

  def on_trial?
    trial_ends_at.present? && trial_ends_at.future?
  end

  def trial_plan
    return nil unless on_trial? && trial_plan_key.present?

    Billing::Plans.find(trial_plan_key)
  end

  def trial_days_remaining
    return 0 unless on_trial?

    ((trial_ends_at - Time.current) / 1.day).ceil.clamp(0, TRIAL_DAYS)
  end

  def start_no_card_trial_for!(user, plan_key: DEFAULT_TRIAL_PLAN_KEY)
    raise ArgumentError, "trial already granted to this account" if user.trial_granted_at.present?

    update!(
      trial_plan_key: plan_key,
      trial_ends_at: TRIAL_DAYS.days.from_now,
      trial_used_at: Time.current
    )
    user.update!(trial_granted_at: Time.current)
  end

  def switch_trial_plan!(plan)
    raise ArgumentError, "not on trial" unless on_trial?

    update!(trial_plan_key: plan.key)
  end

  def end_trial!
    update!(trial_ends_at: Time.current) if trial_ends_at.present? && trial_ends_at.future?
  end

  def clear_trial_state!
    update!(trial_ends_at: nil, trial_plan_key: nil)
  end

  def owner_users
    memberships.joins(:roles).where(roles: { name: Role::APP_OWNER, scope: :app }).includes(:user).map(&:user)
  end
end
