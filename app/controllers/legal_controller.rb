# frozen_string_literal: true

class LegalController < ApplicationController
  layout "landing"

  allow_unauthenticated_access
  skip_before_action :enforce_onboarding_gate!

  def privacy_policy
  end

  def gdpr
  end

  def terms
  end

  def cookies_policy
  end
end
