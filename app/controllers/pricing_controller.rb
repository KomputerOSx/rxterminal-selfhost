# frozen_string_literal: true

class PricingController < ApplicationController
  layout "landing"

  allow_unauthenticated_access
  skip_before_action :enforce_onboarding_gate!

  def index
    redirect_to dashboard_path if authenticated?

    @currency = "gbp"
    @plans = Billing::Plans::PAID
  end
end
