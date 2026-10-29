# frozen_string_literal: true

class PagesController < ApplicationController
  layout "landing"

  allow_unauthenticated_access
  skip_before_action :enforce_onboarding_gate!

  def features
  end

  def security
  end
end
