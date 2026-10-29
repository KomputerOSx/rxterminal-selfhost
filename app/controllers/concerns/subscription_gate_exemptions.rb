# frozen_string_literal: true

module SubscriptionGateExemptions
  extend ActiveSupport::Concern

  LOCKOUT_EXEMPT_CONTROLLERS = %w[
    sessions
    registrations
    confirmations
    passwords
    password_resets
    profile
    email_changes
    email_preferences
    notification_recipients
    onboarding
    invitations
    org/settings
    org/members
    org/switches
    org/organizations
    org/waiting_display
  ].freeze

  private

  def subscription_gate_exempt?
    return true if controller_path.start_with?("admin/")
    return true if controller_path == "billing" || controller_path.start_with?("billing/")
    return true if LOCKOUT_EXEMPT_CONTROLLERS.include?(controller_path)

    false
  end
end
