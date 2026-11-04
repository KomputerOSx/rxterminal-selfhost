# frozen_string_literal: true

# The privacy policy, terms of use, data protection statement and cookies policy shown to
# patients/visitors. Each is an HTML template with {{placeholders}} filled from the organization.
#
# Defaults ship in config/legal/<name>.html. To customise, put a file of the same name in
# LEGAL_DIR (default storage/legal/, inside the persistent volume) - it takes precedence and is
# read on every request, so no restart is needed. `bin/rails selfhost:legal:export` copies the
# defaults there. These are templates, not legal advice: have them reviewed for your jurisdiction.
class LegalDocument
  TITLES = {
    "privacy_policy" => "Privacy Policy",
    "terms" => "Terms of Use",
    "gdpr" => "Data Protection Statement",
    "cookies_policy" => "Cookies Policy"
  }.freeze

  PLACEHOLDER = /\{\{\s*(\w+)\s*\}\}/
  ALLOWED_TAGS = %w[h2 h3 h4 p ul ol li a strong em b i br table thead tbody tr th td section code span div].freeze
  ALLOWED_ATTRIBUTES = %w[href target rel class].freeze

  class << self
    def names = TITLES.keys

    def title(name) = TITLES.fetch(name.to_s)

    def default_dir = Rails.root.join("config/legal")

    def override_dir = Pathname.new(ENV["LEGAL_DIR"].presence || Rails.root.join("storage/legal").to_s)

    def path_for(name)
      raise ArgumentError, "unknown legal document #{name.inspect}" unless TITLES.key?(name.to_s)

      override = override_dir.join("#{name}.html")
      override.file? ? override : default_dir.join("#{name}.html")
    end

    def customised?(name) = override_dir.join("#{name}.html").file?

    # Returns safe HTML with placeholders filled in (values are HTML-escaped).
    def render(name, organization: nil, view: ApplicationController.helpers)
      values = placeholders(organization)
      filled = File.read(path_for(name)).gsub(PLACEHOLDER) do
        ERB::Util.html_escape(values.fetch(Regexp.last_match(1), ""))
      end
      view.sanitize(filled, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
    end

    def placeholders(organization = nil)
      organization ||= Organization.primary
      {
        "organization_name" => organization&.name.presence || AppConfig.operator_name,
        "organization_address" => organization ? address_for(organization) : "",
        "contact_email" => organization&.contact_email.presence || AppConfig.support_email.to_s,
        "contact_phone" => organization&.contact_phone.to_s,
        "app_name" => AppConfig.name,
        "site_url" => AppConfig.site_url,
        "site_domain" => AppConfig.site_domain,
        "pii_retention_days" => DataRetentionJob::RETENTION_PERIOD.in_days.to_i.to_s
      }
    end

    private

    def address_for(organization)
      [ organization.address_line1, organization.address_line2, organization.address_city,
        organization.address_state, organization.address_postal_code, organization.address_country ].compact_blank.join(", ")
    end
  end
end
