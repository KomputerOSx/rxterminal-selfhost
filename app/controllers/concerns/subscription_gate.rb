# frozen_string_literal: true

module SubscriptionGate
  extend ActiveSupport::Concern
  include SubscriptionGateExemptions

  included do
    before_action :enforce_subscription_gate!
  end

  private

  def enforce_subscription_gate!
    return unless current_user
    return if subscription_gate_exempt?
    return unless Current.organization&.locked?

    redirect_to billing_path, alert: subscription_locked_staff_message
  end

  def subscription_locked_staff_message
    "This organization's subscription has ended. Update billing to restore access."
  end
end
