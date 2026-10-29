module Notifications
  module Rules
    class OrganizationLogoDeclined < Notifications::Rule
      def self.event_type = :organization_logo_declined
      def self.category = :admin

      def recipients
        (organization_owners.to_a + Array(resource&.uploaded_by)).uniq
      end

      def title = "Your logo was declined"
      def body  = "#{actor_name} declined the logo you submitted for #{organization&.name}: #{resource&.decline_reason}"
      def url   = org_settings_path

      def details
        [ [ "Reason", resource&.decline_reason ] ]
      end
    end
  end
end
