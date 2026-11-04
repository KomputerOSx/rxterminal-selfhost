# :lax keeps the session cookie on top-level navigations from other sites (e.g. email links).
Rails.application.config.session_store :cookie_store,
  key: "_rxterminal_session",
  secure: Rails.env.production? && ENV.fetch("APP_PROTOCOL", "https") == "https",
  httponly: true,
  same_site: :lax
