# frozen_string_literal: true

class RobotsController < ApplicationController
  layout false

  allow_unauthenticated_access
  skip_before_action :enforce_onboarding_gate!
  skip_before_action :enforce_maintenance_mode!

  # Authenticated / internal app areas - not useful or safe to index.
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
    /auth/
  ].freeze

  def show
    @disallowed_paths = DISALLOWED_PATHS

    render layout: false
  end
end
