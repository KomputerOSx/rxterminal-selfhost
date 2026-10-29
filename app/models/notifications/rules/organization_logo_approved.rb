module Notifications
  module Rules
    class OrganizationLogoApproved < Notifications::Rule
      def self.event_type = :organization_logo_approved
      def self.category = :admin

      def recipients
        (organization_owners.to_a + Array(resource&.uploaded_by)).uniq
      end

      def title = "Your logo was approved"
      def body  = "#{actor_name} approved the logo you submitted for #{organization&.name}. You can now set it as your active logo."
      def url   = org_settings_path
    end
  end
end
