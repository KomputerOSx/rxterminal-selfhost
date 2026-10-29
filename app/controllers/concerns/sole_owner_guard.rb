# frozen_string_literal: true

# Helpers for blocking account deletion or leaving when the user is an organization's last owner.
module SoleOwnerGuard
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
end
