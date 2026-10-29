# frozen_string_literal: true

module Public
  module PortalSeoHelper
    SCHEMA_TYPES = {
      "clinic" => "MedicalClinic",
      "salon" => "BeautySalon",
      "retail_repair" => "Store",
      "public_office" => "GovernmentOffice"
    }.freeze

    def portal_canonical_url
      suffix = custom_domain_portal_request? ? request.path : request.path.delete_prefix("/#{portal_slug}")
      suffix = "" if suffix == "/"

      if @organization.custom_domain.present?
        "#{request.scheme}://#{@organization.custom_domain}#{suffix.presence || "/"}"
      else
        "#{request.base_url}/#{portal_slug}#{suffix}"
      end
    end

    def portal_meta_description
      [ @organization.name, @organization.full_address.presence, "Book an appointment online." ].compact.join(" - ")
    end

    def portal_logo_url
      rails_blob_url(@organization.kiosk_logo) if @organization.kiosk_logo.attached?
    end

    def portal_structured_data_tag
      tag.script(json_escape(portal_structured_data.to_json).html_safe, type: "application/ld+json")
    end

    private

    def portal_structured_data
      {
        "@context" => "https://schema.org",
        "@type" => SCHEMA_TYPES.fetch(@organization.business_type.to_s, "LocalBusiness"),
        "name" => @organization.name,
        "url" => portal_canonical_url,
        "image" => portal_logo_url,
        "telephone" => @organization.contact_phone.presence,
        "email" => @organization.contact_email.presence,
        "address" => portal_postal_address,
        "openingHoursSpecification" => portal_opening_hours_specification
      }.compact
    end

    def portal_postal_address
      return if @organization.full_address.blank?

      {
        "@type" => "PostalAddress",
        "streetAddress" => [ @organization.address_line1, @organization.address_line2 ].compact_blank.join(", ").presence,
        "addressLocality" => @organization.address_city.presence,
        "addressRegion" => @organization.address_state.presence,
        "postalCode" => @organization.address_postal_code.presence,
        "addressCountry" => @organization.address_country.presence
      }.compact
    end

    def portal_opening_hours_specification
      specs = (@organization.operating_hours || {}).filter_map do |day, hours|
        next if hours.blank?

        {
          "@type" => "OpeningHoursSpecification",
          "dayOfWeek" => day.to_s.capitalize,
          "opens" => hours["open"],
          "closes" => hours["close"]
        }
      end
      specs.presence
    end
  end
end
