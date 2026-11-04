# frozen_string_literal: true

# Placeholder root until Phase 3 defines the single-business root URL.
class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    redirect_to(authenticated? ? dashboard_path : login_path)
  end
end
