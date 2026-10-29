# frozen_string_literal: true

module Public
  module PortalHelper
    def portal_service_price_label(service)
      return "Free" if service.price.nil? || service.price.zero?

      "#{service.organization.service_currency_symbol}#{"%.2f" % service.price}"
    end

    def portal_nav_links(organization)
      links = []
      links << [ "Opening times", portal_opening_times_path ] if organization.portal_opening_times_enabled?
      links << [ "Contact", portal_contact_path ] if organization.portal_contact_page_enabled?
      return [] if links.empty?

      [ [ "Home", portal_root_path ], *links ]
    end

    def portal_hours_label(hours)
      return "Closed" if hours.blank?

      "#{portal_slot_label(hours["open"])} - #{portal_slot_label(hours["close"])}"
    end

    def portal_tel_href(phone)
      "tel:#{phone.to_s.gsub(/[^\d+]/, "")}"
    end

    def portal_map_url(address)
      "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(address)}"
    end
  end
end
