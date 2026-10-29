Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
    provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"], scope: "email,profile"
  end

  if ENV["GITHUB_CLIENT_ID"].present? && ENV["GITHUB_CLIENT_SECRET"].present?
    provider :github, ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"], scope: "user:email"
  end
end

# omniauth-rails_csrf_protection requires the request phase (/auth/:provider) to be a
# POST with a valid Rails CSRF token, mitigating login CSRF (CVE-2015-9284). Views must
# use `button_to`, not `link_to`, to hit these paths.
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true

# Route failures (denied consent, provider errors) through our own controller so they
# get a normal Rails response (flash, layout) instead of OmniAuth's default Rack app.
# Deferred to `to_prepare` since the controller isn't autoloadable this early in boot.
Rails.application.config.to_prepare do
  OmniAuth.config.on_failure = OmniauthCallbacksController.action(:failure)
end
