module Notifications
  module Rules
    class RoleRevoked < Notifications::Rule
      def self.event_type = :role_revoked
      def self.category = :membership

      # See Notifications::Rules::RoleGranted - :role_revoked also fires for system-scope
      # RBAC revokes (Admin::UserRolesController), which are out of scope here.
      def recipients
        return User.none if organization.blank? || metadata["membership_id"].blank?

        membership = organization.memberships.find_by(id: metadata["membership_id"])
        membership ? User.where(id: membership.user_id) : User.none
      end

      def title = "You're now a regular member of #{organization.name}"
      def body  = "#{actor_name} demoted you to member in #{organization.name}."
      def url   = org_members_path
    end
  end
end
