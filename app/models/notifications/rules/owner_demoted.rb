module Notifications
  module Rules
    class OwnerDemoted < Notifications::Rule
      def self.event_type = :owner_demoted
      def self.category = :membership

      # self_initiated = the owner stepped themselves down - they already know.
      def recipients
        return User.none if metadata["self_initiated"]

        User.where(id: metadata["target_user_id"])
      end

      def title = "You're now an admin of #{organization.name}"
      def body  = "#{actor_name} stepped you down from owner to admin in #{organization.name}."
      def url   = org_members_path
    end
  end
end
