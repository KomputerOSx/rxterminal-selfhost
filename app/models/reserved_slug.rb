# frozen_string_literal: true

# Single source of truth for path/subdomain labels an organization may not claim as
# its slug - either because a top-level route already lives there (see
# config/routes.rb's public-portal scope, which builds its constraint from this list)
# or because it's a conventionally reserved DNS/service label. Previously this list
# was duplicated (and had drifted) between Organization::RESERVED_SLUGS and a
# hardcoded regex in config/routes.rb.
module ReservedSlug
  WORDS = %w[
    admin org invitations login logout password confirmations registration profile
    up rails signup dashboard kiosk api billing onboarding notifications
    email_preferences internal pricing contact privacy-policy gdpr terms cookies
    www mail ftp smtp pop imap ns1 ns2 autodiscover autoconfig
  ].freeze

  def self.reserved?(slug)
    WORDS.include?(slug.to_s.downcase)
  end
end
