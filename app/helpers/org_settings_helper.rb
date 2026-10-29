# frozen_string_literal: true

module OrgSettingsHelper
  POSTCODE_REGION_LABELS = {
    "uk" => "United Kingdom",
    "us" => "United States",
    "ca" => "Canada",
    "au" => "Australia"
  }.freeze

  SERVICE_CURRENCY_LABELS = {
    "gbp" => "British Pound (£)",
    "usd" => "US Dollar ($)",
    "eur" => "Euro (€)",
    "cad" => "Canadian Dollar (CA$)",
    "aud" => "Australian Dollar (A$)"
  }.freeze

  def organization_portal_url(organization)
    host = AppHost.primary_host
    protocol = Rails.env.production? ? "https" : "http"
    port_suffix = (Rails.env.development? && host == "localhost") ? ":#{request.port}" : ""
    "#{protocol}://#{host}#{port_suffix}/#{organization.slug}"
  end

  # The URL customers should actually be sent to: the organization's custom
  # domain when one is attached, falling back to the rxterminal-hosted portal.
  def organization_public_portal_url(organization)
    organization_custom_domain_url(organization) || organization_portal_url(organization)
  end

  def portal_arrive_url(organization, token: nil)
    url = "#{organization_public_portal_url(organization)}/arrive"
    token.present? ? "#{url}?token=#{CGI.escape(token)}" : url
  end

  def organization_custom_domain_url(organization)
    return if organization.custom_domain.blank?

    "https://#{organization.custom_domain}"
  end

  def settings_opening_hours_summary(organization)
    hours = organization.operating_hours || {}
    open_days = Organization::WEEKDAYS.count { |day| hours[day].present? }
    return "Closed every day" if open_days.zero?

    "#{open_days} #{'day'.pluralize(open_days)} open"
  end

  def postcode_region_label(region)
    POSTCODE_REGION_LABELS.fetch(region, region.to_s.upcase)
  end

  def postcode_region_options
    Organization::POSTCODE_REGIONS.map { |region| [ postcode_region_label(region), region ] }
  end

  def service_currency_label(currency)
    SERVICE_CURRENCY_LABELS.fetch(currency, currency.to_s.upcase)
  end

  def service_currency_options
    Organization::SERVICE_CURRENCIES.map { |currency| [ service_currency_label(currency), currency ] }
  end

  def can_configure_portal?
    current_user.has_permission?("app.portal.configure", organization: Current.organization)
  end
end
