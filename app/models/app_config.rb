# frozen_string_literal: true

# Instance-level branding and contact settings, all from environment variables:
#   APP_NAME       product name shown in titles, emails and the wordmark (default "RxTerminal")
#   SUPPORT_EMAIL  contact address for emails, legal pages and the footer
#   LOGO_URL       optional image shown instead of the text wordmark
# Anything not set falls back to the primary organization's own details.
module AppConfig
  DEFAULT_NAME = "RxTerminal"
  PROJECT_URL = "https://github.com/KomputerOSx/rxterminal-selfhost"

  module_function

  def name
    ENV["APP_NAME"].presence || DEFAULT_NAME
  end

  def default_name?
    name == DEFAULT_NAME
  end

  def logo_url
    ENV["LOGO_URL"].presence
  end

  def support_email
    ENV["SUPPORT_EMAIL"].presence ||
      Organization.primary&.contact_email.presence ||
      ENV["MAIL_FROM"].to_s[/<([^>]+)>/, 1] ||
      ENV["MAIL_FROM"].presence
  end

  # The business running this install (shown as the operator in emails and the footer).
  def operator_name
    Organization.primary&.name.presence || name
  end

  def site_url
    "#{AppHost.https? ? "https" : "http"}://#{AppHost.primary_host}"
  end

  def site_domain
    AppHost.primary_host
  end
end
