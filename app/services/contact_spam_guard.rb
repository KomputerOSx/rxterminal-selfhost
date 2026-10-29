# frozen_string_literal: true

class ContactSpamGuard
  MIN_ELAPSED_SECONDS = 3
  MAX_ELAPSED_SECONDS = 24.hours.to_i

  class << self
    def prepare_session!(session:)
      session[:contact_form_token] = SecureRandom.hex(16)
    end

    def bot_submission?(params:, session:)
      return true if params[:website].present?
      return true if params[:company].present?

      token = params[:form_token].to_s
      return true if token.blank? || token != session[:contact_form_token].to_s

      loaded_at = params[:form_loaded_at].to_i
      return true if loaded_at.zero?

      elapsed = Time.current.to_i - loaded_at
      elapsed < MIN_ELAPSED_SECONDS || elapsed > MAX_ELAPSED_SECONDS
    end
  end
end
