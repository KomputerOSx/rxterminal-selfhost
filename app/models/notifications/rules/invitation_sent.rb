module Notifications
  module Rules
    class InvitationSent < Notifications::Rule
      def self.event_type = :organization_invitation_sent
      def self.category = :membership

      # Only fires when the invited email already belongs to an account - a brand-new
      # invitee has no User row to notify yet (they get the invite email either way).
      def recipients
        User.where(email: metadata["email"])
      end

      def title = "You've been invited to join #{organization.name}"
      def body  = "#{actor_name} invited you to join #{organization.name}."
      def url   = org_members_path
    end
  end
end
