module Notifications
  module Rules
    class RoleGranted < Notifications::Rule
      def self.event_type = :role_granted
      def self.category = :membership

      # :role_granted also fires for system-scope RBAC grants (Admin::UserRolesController,
      # signup's initial owner grant) - those have no organization/membership_id and are out
      # of scope here; only the org admin-promotion path (Org::MembersController#promote)
      # has a click-through notification.
      def recipients
        return User.none if organization.blank? || metadata["membership_id"].blank?

        membership = organization.memberships.find_by(id: metadata["membership_id"])
        membership ? User.where(id: membership.user_id) : User.none
      end

      def title = "You're now an admin in #{organization.name}"
      def body  = "#{actor_name} promoted you to admin in #{organization.name}."
      def url   = org_members_path
    end
  end
end
