module Notifications
  module Rules
    class OwnerPromoted < Notifications::Rule
      def self.event_type = :owner_promoted
      def self.category = :membership

      def recipients
        User.where(id: metadata["target_user_id"])
      end

      def title = "You're now an owner of #{organization.name}"
      def body  = "#{actor_name} promoted you to owner of #{organization.name}."
      def url   = org_members_path
    end
  end
end
