module Notifications
  module Rules
    class InvitationAccepted < Notifications::Rule
      def self.event_type = :organization_invitation_accepted
      def self.category = :membership

      def recipients
        invitation = OrganizationInvitation.find_by(id: metadata["invitation_id"])
        return User.none unless invitation&.invited_by_id

        User.where(id: invitation.invited_by_id)
      end

      def title = "#{actor_name} accepted your invitation"
      def body  = "#{actor_name} joined #{organization.name}."
      def url   = org_members_path
    end
  end
end
