# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  helper MailerHelper

  default from: "RxTerminal <no-reply@rxterminal.co.uk>"
  layout "mailer"

  before_action :attach_rxterminal_logo

  rescue_from StandardError do |exception|
    Rails.logger.error "[Mailer] Delivery failed: #{exception.class} - #{exception.message}"
  end

  private

  def attach_rxterminal_logo
    if MailerTheme::LOGO_PATH.exist?
      attachments.inline[MailerTheme::LOGO_FILENAME] = MailerTheme::LOGO_PATH.binread
    end

    return unless MailerTheme::LOGO_SMALL_PATH.exist?

    attachments.inline[MailerTheme::LOGO_SMALL_FILENAME] = MailerTheme::LOGO_SMALL_PATH.binread
  end
end
