# frozen_string_literal: true

module PortalTheming
  extend ActiveSupport::Concern

  PORTAL_THEMES = KioskTheming::KIOSK_THEMES
  LEGACY_PORTAL_THEME_ALIASES = KioskTheming::LEGACY_KIOSK_THEME_ALIASES
  DEFAULT_PORTAL_THEME = KioskTheming::DEFAULT_KIOSK_THEME
  PORTAL_THEME_LABELS = KioskTheming::KIOSK_THEME_LABELS

  PORTAL_CUSTOM_COLOR_KEYS = %w[
    base_100
    base_200
    base_content
    primary
    primary_content
    success
    success_content
    warning
    warning_content
  ].freeze

  PORTAL_CUSTOM_COLOR_GROUPS = [
    { label: "Page", keys: %w[base_100 base_200 base_content] },
    { label: "Buttons & links", keys: %w[primary primary_content] },
    { label: "Success states", keys: %w[success success_content] },
    { label: "Warning states", keys: %w[warning warning_content] }
  ].freeze

  PORTAL_CUSTOM_COLOR_LABELS = {
    "base_100" => "Background",
    "base_200" => "Surface",
    "base_content" => "Text",
    "primary" => "Button",
    "primary_content" => "Button text",
    "success" => "Accent",
    "success_content" => "Accent text",
    "warning" => "Accent",
    "warning_content" => "Accent text"
  }.freeze

  PORTAL_CUSTOM_COLOR_GROUP_LABELS = {
    "Page" => {
      "base_100" => "Background",
      "base_200" => "Surface",
      "base_content" => "Text"
    },
    "Buttons & links" => {
      "primary" => "Button",
      "primary_content" => "Text"
    },
    "Success states" => {
      "success" => "Accent",
      "success_content" => "Text"
    },
    "Warning states" => {
      "warning" => "Accent",
      "warning_content" => "Text"
    }
  }.freeze

  PORTAL_CUSTOM_RADIUS_KEYS = KioskTheming::CUSTOM_RADIUS_KEYS
  PORTAL_CUSTOM_RADIUS_LABELS = KioskTheming::CUSTOM_RADIUS_LABELS
  PORTAL_CUSTOM_RADIUS_OPTIONS = KioskTheming::CUSTOM_RADIUS_OPTIONS
  PORTAL_CUSTOM_THEME_KEYS = (PORTAL_CUSTOM_COLOR_KEYS + PORTAL_CUSTOM_RADIUS_KEYS).freeze

  included do
    after_initialize do
      self.portal_theme_custom = {} if portal_theme_custom.nil?
    end

    before_validation :normalize_portal_theme

    validates :portal_theme, inclusion: { in: PORTAL_THEMES + LEGACY_PORTAL_THEME_ALIASES.keys }
    validate :portal_theme_custom_values_are_valid
  end

  def resolved_portal_theme
    return "kiosk-custom" if normalize_portal_theme_slug(portal_theme) == "custom"

    normalize_portal_theme_slug(portal_theme).presence_in(PORTAL_THEMES - [ "custom" ]) || DEFAULT_PORTAL_THEME
  end

  def portal_theme_custom_colors
    (portal_theme_custom || {}).slice(*PORTAL_CUSTOM_COLOR_KEYS).compact_blank
  end

  def portal_theme_custom_radii
    (portal_theme_custom || {}).slice(*PORTAL_CUSTOM_RADIUS_KEYS).compact_blank
  end

  def portal_theme_inline_style
    declarations = []
    declarations.concat(portal_color_inline_declarations) if normalize_portal_theme_slug(portal_theme) == "custom"
    declarations.concat(portal_radius_inline_declarations)
    declarations.join(" ")
  end

  def assign_portal_theme_custom_from_params(raw)
    return unless raw.respond_to?(:permit)

    permitted = raw.permit(*PORTAL_CUSTOM_THEME_KEYS.map(&:to_sym))
    cleaned = permitted.to_h.each_with_object({}) do |(key, value), result|
      normalized = normalize_portal_custom_token_value(key, value)
      result[key] = normalized if normalized.present?
    end

    self.portal_theme_custom = cleaned
  end

  private

  def normalize_portal_theme
    self.portal_theme = normalize_portal_theme_slug(portal_theme) if portal_theme.present?
  end

  def normalize_portal_theme_slug(theme)
    LEGACY_PORTAL_THEME_ALIASES.fetch(theme, theme)
  end

  def portal_color_inline_declarations
    portal_theme_custom_colors.map { |key, value| "--color-#{key.tr("_", "-")}: #{value};" }
  end

  def portal_radius_inline_declarations
    portal_theme_custom_radii.map { |key, value| "--#{key.tr("_", "-")}: #{value};" }
  end

  def portal_theme_custom_values_are_valid
    portal_theme_custom_colors.each do |key, value|
      next if value.match?(KioskTheming::COLOR_VALUE_FORMAT)

      label = PORTAL_CUSTOM_COLOR_LABELS.fetch(key, key.humanize)
      errors.add(:portal_theme_custom, "#{label} must be a valid color")
    end

    portal_theme_custom_radii.each do |key, value|
      next if value.match?(KioskTheming::RADIUS_VALUE_FORMAT)

      label = PORTAL_CUSTOM_RADIUS_LABELS.fetch(key, key.humanize)
      errors.add(:portal_theme_custom, "#{label} must use a rem value (e.g. 0.5rem)")
    end
  end

  def normalize_portal_custom_token_value(key, value)
    stripped = value.to_s.strip
    return nil if stripped.blank?

    if PORTAL_CUSTOM_COLOR_KEYS.include?(key)
      return stripped.downcase if stripped.start_with?("#")
    end

    stripped
  end
end
