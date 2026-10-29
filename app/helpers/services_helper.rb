# frozen_string_literal: true

module ServicesHelper
  def service_icon_tag(icon_name, size: 20, extra_class: "")
    name = icon_name.presence || "medical_services"
    content_tag(:span, name,
      class: "material-symbols-outlined #{extra_class}",
      style: "font-size:#{size}px;line-height:1")
  end

  def service_price_label(service)
    if service.price.present? && service.price.positive?
      number_to_currency(service.price, unit: service.organization.service_currency_symbol)
    else
      content_tag(:span, "Free", class: "badge badge-ghost badge-sm")
    end
  end
end
