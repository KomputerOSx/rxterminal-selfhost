# frozen_string_literal: true

class CustomDomainConstraint
  def self.matches?(request)
    return false if reserved_path?(request.path)

    AppHost.custom_domain?(request.host)
  end

  def self.reserved_path?(path)
    path = path.to_s
    # "/rails/" covers Active Storage (blob/representation redirects, direct
    # uploads), Action Mailbox, and Action Text - the app's own config/routes.rb
    # is drawn before any engine's routes, so without this the custom-domain
    # catch-all below would swallow those requests first (e.g. every
    # organization logo <img> on a custom domain 404/500ing).
    path == "/up" || path.start_with?("/internal/") || path.start_with?("/rails/")
  end
end
