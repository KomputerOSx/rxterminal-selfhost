# frozen_string_literal: true

# Blocks account deletion and sole-owner leave when the user is the org's last owner and the org
# still has a live subscription (§7 production_launch.md).
module SoleOwnerSubscriptionGuard
  extend ActiveSupport::Concern

  private

  def sole_owner?(org, user: current_user)
    org.membership_roles.joins(:role, :membership)
      .where(roles: { scope: "app", name: Role::APP_OWNER })
      .where.not(memberships: { user_id: user.id })
      .none?
  end

  def sole_owner_with_other_members?(org, user: current_user)
    sole_owner?(org, user: user) && org.memberships.where.not(user_id: user.id).exists?
  end

  def sole_owner_with_active_subscription?(org, user: current_user)
    sole_owner?(org, user: user) && org.active_subscription?
  end

  def organizations_blocking_account_deletion_for_active_subscription(user = current_user)
    user.organizations.select { |org| sole_owner_with_active_subscription?(org, user: user) }
  end

  def active_subscription_guard_message(organizations)
    names = Array(organizations).map(&:name)
    if names.one?
      "You can't do that while #{names.first} has an active subscription. Cancel it at /billing first."
    else
      "You can't do that while #{names.to_sentence} have active subscriptions. Cancel them at /billing first."
    end
  end

  def block_leave_for_active_subscription!(organization)
    return false unless sole_owner?(organization)
    return false if organization.memberships.where.not(user_id: current_user.id).exists?
    return false unless organization.active_subscription?

    log_audit(:owner_removal_blocked, resource: organization,
      metadata: { target_user_id: current_user.id, self_removal: true, active_subscription: true })
    redirect_to org_settings_path, alert: active_subscription_guard_message(organization) and true
  end
end
