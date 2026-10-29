# frozen_string_literal: true

module PortalThemeHelper
  def portal_theme_for(organization)
    organization&.resolved_portal_theme || Organization::DEFAULT_PORTAL_THEME
  end

  def portal_theme_preview_style(organization)
    organization.portal_theme_inline_style
  end

  def portal_theme_options
    Organization::PORTAL_THEMES.map do |theme|
      [ Organization::PORTAL_THEME_LABELS.fetch(theme, theme.humanize), theme ]
    end
  end

  def portal_custom_color_groups
    Organization::PORTAL_CUSTOM_COLOR_GROUPS
  end

  def portal_custom_color_label(group_label, key)
    Organization::PORTAL_CUSTOM_COLOR_GROUP_LABELS.dig(group_label, key) ||
      Organization::PORTAL_CUSTOM_COLOR_LABELS.fetch(key, key.humanize)
  end

  def portal_theme_swatch_class(theme)
    kiosk_theme_swatch_class(theme)
  end

  def portal_preview_services(organization)
    organization.services.visible.active.by_display_order.limit(2)
  end

  def portal_custom_color_fallback(key)
    {
      "primary" => "#004fe0",
      "primary_content" => "#ffffff",
      "base_100" => "#f8fafc",
      "base_200" => "#ffffff",
      "base_content" => "#111827",
      "success" => "#00e069",
      "success_content" => "#002913",
      "warning" => "#ffbe0a",
      "warning_content" => "#291f00"
    }.fetch(key, "#000000")
  end
end
