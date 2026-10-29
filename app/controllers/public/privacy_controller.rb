# frozen_string_literal: true

module Public
  class PrivacyController < BaseController
    skip_before_action :require_privacy_accepted

    def show
    end

    def accept
      return_to = session[:public_privacy_return_to]
      reset_session
      session[:public_privacy_accepted] = true
      redirect_to return_to.presence || portal_root_path
    end
  end
end
