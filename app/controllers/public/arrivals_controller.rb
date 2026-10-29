# frozen_string_literal: true

module Public
  class ArrivalsController < BaseController
    def show
      token_valid = validate_walk_in_token(params[:token])

      if token_valid
        session[:walk_in_org_id] = @organization.id
        session[:walk_in_expires_at] = 30.minutes.from_now.iso8601
      end

      @token_valid = token_valid || walk_in_session_active?
    end

    private

    def validate_walk_in_token(token)
      return false if token.blank?

      payload = Rails.application.message_verifier("walk-in").verify(token)
      payload["org_id"] == @organization.id && payload["org_slug"] == @organization.slug
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      false
    end
  end
end
