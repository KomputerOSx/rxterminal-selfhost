# frozen_string_literal: true

module SubscriptionLockout
  extend ActiveSupport::Concern

  private

  def enforce_subscription_lockout!
    organization = subscription_lockout_organization
    return unless organization&.locked?

    respond_to_subscription_lockout!
  end

  def subscription_lockout_organization
    raise NotImplementedError
  end

  def respond_to_subscription_lockout!
    message = subscription_lockout_public_message

    if request.format.json?
      render json: { error: message }, status: :service_unavailable
    else
      render "shared/subscription_unavailable",
        status: :service_unavailable,
        layout: subscription_lockout_layout,
        locals: { message: message, organization: subscription_lockout_organization }
    end
  end

  def subscription_lockout_layout
    false
  end

  def subscription_lockout_public_message
    "This service is temporarily unavailable. Please contact the pharmacy for assistance."
  end
end
