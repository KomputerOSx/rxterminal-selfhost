# frozen_string_literal: true

module DevicesHelper
  def device_status_badge(device)
    case device.status
    when "active"
      content_tag(:span, "Active", class: "badge badge-success badge-sm")
    when "inactive"
      content_tag(:span, "Inactive", class: "badge badge-warning badge-sm")
    when "revoked"
      content_tag(:span, "Revoked", class: "badge badge-error badge-sm")
    else
      content_tag(:span, device.status.humanize, class: "badge badge-ghost badge-sm")
    end
  end
end
