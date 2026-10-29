module Notifications
  class Registry
    RULES = [
      Notifications::Rules::InvitationSent,
      Notifications::Rules::InvitationAccepted,
      Notifications::Rules::MembershipDestroyed,
      Notifications::Rules::OwnerPromoted,
      Notifications::Rules::OwnerDemoted,
      Notifications::Rules::RoleGranted,
      Notifications::Rules::RoleRevoked,
      Notifications::Rules::PasswordChanged,
      Notifications::Rules::EmailChanged,
      Notifications::Rules::NewDeviceLogin,
      Notifications::Rules::PaymentFailed,
      Notifications::Rules::SubscriptionCancelled,
      Notifications::Rules::AppointmentBookedOnline,
      Notifications::Rules::OrganizationLogoSubmitted,
      Notifications::Rules::OrganizationLogoApproved,
      Notifications::Rules::OrganizationLogoDeclined
    ].index_by { |rule| rule.event_type }.freeze

    def self.for(event_type)
      RULES[event_type.to_sym]
    end

    def self.dispatch!(event_type:, actor_id: nil, resource_type: nil, resource_id: nil, organization_id: nil, metadata: {})
      return unless self.for(event_type)

      NotificationDispatchJob.perform_later(
        event_type: event_type.to_s,
        actor_id: actor_id,
        resource_type: resource_type,
        resource_id: resource_id,
        organization_id: organization_id,
        metadata: metadata
      )
    end
  end
end
