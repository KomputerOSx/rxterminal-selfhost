module Notifications
  module Rules
    class MembershipDestroyed < Notifications::Rule
      def self.event_type = :membership_destroyed
      def self.category = :membership

      # Self-removal (leaving an org, or an org auto-destroyed when its last member leaves)
      # doesn't need a notification - the acting user already knows they left.
      def recipients
        return User.none if metadata["self_removal"]

        User.where(id: metadata["removed_user_id"])
      end

      def title = "You've been removed from #{organization.name}"
      def body  = "#{actor_name} removed you from #{organization.name}."
      def url   = root_path
    end
  end
end
