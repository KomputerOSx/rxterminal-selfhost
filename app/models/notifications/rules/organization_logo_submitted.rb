module Notifications
  module Rules
    class OrganizationLogoSubmitted < Notifications::Rule
      def self.event_type = :organization_logo_submitted
      def self.category = :admin

      def recipients
        User.joins(roles: :permissions)
          .where(permissions: { key: "system.organization_logos.manage" })
          .distinct
      end

      def title = "New logo awaiting approval - #{organization&.name}"
      def body  = "#{actor_name} uploaded a new logo for #{organization&.name}. Review it now."
      def url   = admin_organization_logo_path(resource)
    end
  end
end
