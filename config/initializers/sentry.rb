# frozen_string_literal: true

Sentry.init do |config|
  config.enabled_environments = %w[production]
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.send_default_pii = false
  config.enable_logs = true
  config.enabled_patches = [ :logger ]
end
