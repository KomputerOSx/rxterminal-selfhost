# frozen_string_literal: true

class RobotsController < ApplicationController
  layout false

  allow_unauthenticated_access
  skip_before_action :enforce_onboarding_gate!
  skip_before_action :enforce_maintenance_mode!

  # Authenticated / internal app areas - not useful or safe to index.
  # Irrelevant (and left out) on custom domains, since those hosts only
  # ever serve the public organization portal.
  DISALLOWED_PATHS = %w[
    /admin/
    /api/
    /kiosk/
    /org/
    /dashboard
    /onboarding
    /profile
    /billing
    /notification_recipients
    /session
    /login
    /logout
    /signup
    /password
    /password_resets
    /confirmations
    /registration
    /invitations
    /email_preferences
    /auth/
  ].freeze

  def show
    @disallowed_paths = custom_domain_request? ? [] : DISALLOWED_PATHS

    render layout: false
  end

  private

  def custom_domain_request?
    request.env[CustomDomainResolver::ENV_KEY].present?
  end
end
