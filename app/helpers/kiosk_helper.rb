# frozen_string_literal: true

module KioskHelper
  def kiosk_service_destination(service)
    appointment_only = service.requires_appointment? && !service.allows_immediate?
    both = service.requires_appointment? && service.allows_immediate?

    if both
      kiosk_choose_service_path(service)
    elsif appointment_only
      kiosk_new_appointment_path(service_id: service.id)
    else
      kiosk_new_service_request_path(service_id: service.id)
    end
  end

  def kiosk_service_mode(service)
    appointment_only = service.requires_appointment? && !service.allows_immediate?
    both = service.requires_appointment? && service.allows_immediate?

    {
      appointment_only: appointment_only,
      both: both,
      featured: service.featured?
    }
  end

  def kiosk_service_card_classes(service)
    mode = kiosk_service_mode(service)
    classes = [ "kiosk-service-card" ]
    classes << "kiosk-service-card--featured" if mode[:featured]
    classes << "kiosk-service-card--appointment" if mode[:appointment_only]
    classes << "kiosk-service-card--with-badge" if mode[:featured] || mode[:appointment_only] || mode[:both]
    classes << (mode[:appointment_only] ? "kiosk-featured-accent" : "kiosk-featured-primary") if mode[:featured]
    classes.join(" ")
  end

  def kiosk_service_icon_classes(service)
    mode = kiosk_service_mode(service)
    mode[:appointment_only] ? "kiosk-service-icon kiosk-service-icon--appointment" : "kiosk-service-icon kiosk-service-icon--default"
  end

  def kiosk_service_button_classes(service)
    mode = kiosk_service_mode(service)
    mode[:appointment_only] ? "kiosk-service-btn kiosk-service-btn--appointment" : "kiosk-service-btn kiosk-service-btn--default"
  end

  def kiosk_service_price_display(service)
    if service.price.present? && service.price.positive?
      number_to_currency(service.price, unit: service.organization.service_currency_symbol)
    else
      "Free"
    end
  end

  def kiosk_service_price_tag(service)
    if service.price.present? && service.price.positive?
      tag.span(kiosk_service_price_display(service), class: "text-2xl font-bold text-base-content")
    else
      tag.span("Free", class: "text-2xl font-black kiosk-service-price-free")
    end
  end

  def kiosk_home_grid_class(organization, featured_service:)
    show_featured = organization.kiosk_show_featured_service? && featured_service.present?
    show_services = organization.kiosk_show_services?
    show_appointments = organization.kiosk_show_appointments?
    visible_count = [ show_featured, show_services, show_appointments ].count(true)

    case visible_count
    when 1 then "flex justify-center"
    when 2 then "grid grid-cols-1 gap-6 justify-items-center md:grid-cols-2"
    else "grid grid-cols-1 gap-6 justify-items-center md:grid-cols-3"
    end
  end

  def kiosk_theme_for(organization)
    organization&.resolved_kiosk_theme || Organization::DEFAULT_KIOSK_THEME
  end

  def kiosk_custom_color_groups
    Organization::CUSTOM_COLOR_GROUPS
  end

  def kiosk_custom_color_label(group_label, key)
    Organization::CUSTOM_COLOR_GROUP_LABELS.dig(group_label, key) ||
      Organization::CUSTOM_COLOR_LABELS.fetch(key, key.humanize)
  end

  def kiosk_theme_options
    Organization::KIOSK_THEMES.map do |theme|
      [ Organization::KIOSK_THEME_LABELS.fetch(theme, theme.humanize), theme ]
    end
  end

  def kiosk_theme_preview_style(organization)
    organization.kiosk_theme_inline_style
  end

  def kiosk_preview_featured_service(organization)
    organization.kiosk_featured_service ||
      organization.services.visible.active.by_display_order.first
  end

  def kiosk_preview_services(organization)
    service = kiosk_preview_featured_service(organization)
    service ? [ service ] : []
  end

  def kiosk_theme_swatch_class(theme)
    case theme
    when "kiosk-default" then "bg-[#004FE0]"
    when "kiosk-violet" then "bg-[oklch(45%_0.24_277)]"
    when "kiosk-pastel" then "bg-[oklch(90%_0.063_307)]"
    when "kiosk-cmyk" then "bg-[oklch(72%_0.133_239)]"
    when "kiosk-acid" then "bg-[oklch(72%_0.357_331)]"
    when "kiosk-mac" then "bg-[#007aff]"
    when "kiosk-radiant-orange" then "bg-[#FF5722]"
    when "custom" then "bg-gradient-to-br from-primary to-accent"
    else "bg-base-300"
    end
  end

  def kiosk_custom_color_fallback(key)
    {
      "primary" => "#004fe0",
      "primary_content" => "#ffffff",
      "base_100" => "#f8fafc",
      "base_200" => "#ffffff",
      "base_content" => "#111827",
      "success" => "#00e069",
      "success_content" => "#002913",
      "accent" => "#ffbe0a",
      "accent_content" => "#291f00",
      "warning" => "#ffbe0a",
      "warning_content" => "#291f00",
      "upsell_bg" => "#004fe0",
      "upsell_content" => "#ffffff",
      "keyboard_bg" => "#ffffff",
      "keyboard_content" => "#111827",
      "keyboard_accent" => "#ffbe0a",
      "keyboard_delete" => "#dc2626"
    }.fetch(key, "#000000")
  end

  def hex_color_for_picker(value)
    return value if value.to_s.match?(/\A#[0-9a-fA-F]{6}\z/)

    "#000000"
  end
end
