# frozen_string_literal: true

module KioskTheming
  extend ActiveSupport::Concern

  KIOSK_THEMES = %w[
    kiosk-default
    kiosk-violet
    kiosk-pastel
    kiosk-cmyk
    kiosk-acid
    kiosk-mac
    kiosk-radiant-orange
    custom
  ].freeze

  LEGACY_KIOSK_THEME_ALIASES = {
    "dark" => "kiosk-default",
    "light" => "kiosk-violet",
    "kiosk-light" => "kiosk-violet",
    "kiosk-clinical" => "kiosk-pastel",
    "kiosk-warm" => "kiosk-radiant-orange",
    "kiosk-contrast" => "kiosk-default",
    "kiosk-ocean" => "kiosk-cmyk",
    "kiosk-vivid" => "kiosk-acid",
    "kiosk-garden" => "kiosk-mac",
    "kiosk-sunset" => "kiosk-violet",
    "kiosk-bloom" => "kiosk-pastel",
    "kiosk-neon" => "kiosk-acid"
  }.freeze

  DEFAULT_KIOSK_THEME = "kiosk-default"

  KIOSK_THEME_LABELS = {
    "kiosk-default" => "Classic (default)",
    "kiosk-violet" => "Violet",
    "kiosk-pastel" => "Pastel",
    "kiosk-cmyk" => "CMYK",
    "kiosk-acid" => "Acid",
    "kiosk-mac" => "Mac",
    "kiosk-radiant-orange" => "Radiant orange",
    "custom" => "Custom colors"
  }.freeze

  CUSTOM_COLOR_KEYS = %w[
    base_100
    base_200
    base_content
    primary
    primary_content
    success
    success_content
    warning
    warning_content
    accent
    accent_content
    upsell_bg
    upsell_content
    keyboard_bg
    keyboard_content
    keyboard_accent
    keyboard_delete
  ].freeze

  CUSTOM_COLOR_GROUPS = [
    { label: "Page", keys: %w[base_100 base_200 base_content] },
    { label: "Featured service", keys: %w[primary primary_content] },
    { label: "Browse services", keys: %w[success success_content] },
    { label: "Check-in", keys: %w[warning warning_content] },
    { label: "Book appointment", keys: %w[accent accent_content] },
    { label: "Upsell screen", keys: %w[upsell_bg upsell_content] },
    { label: "Onscreen keyboard", keys: %w[keyboard_bg keyboard_content keyboard_accent keyboard_delete] }
  ].freeze

  CUSTOM_RADIUS_KEYS = %w[
    radius_field
    radius_box
    radius_selector
  ].freeze

  CUSTOM_THEME_KEYS = (CUSTOM_COLOR_KEYS + CUSTOM_RADIUS_KEYS).freeze

  CUSTOM_COLOR_LABELS = {
    "base_100" => "Background",
    "base_200" => "Surface",
    "base_content" => "Text",
    "primary" => "Button",
    "primary_content" => "Button text",
    "success" => "Button",
    "success_content" => "Button text",
    "warning" => "Button",
    "warning_content" => "Button text",
    "accent" => "Button",
    "accent_content" => "Button text",
    "upsell_bg" => "Background",
    "upsell_content" => "Text",
    "keyboard_bg" => "Key background",
    "keyboard_content" => "Key text",
    "keyboard_accent" => "Accent key",
    "keyboard_delete" => "Delete key"
  }.freeze

  CUSTOM_COLOR_GROUP_LABELS = {
    "Page" => {
      "base_100" => "Background",
      "base_200" => "Surface",
      "base_content" => "Text"
    },
    "Featured service" => {
      "primary" => "Button",
      "primary_content" => "Text"
    },
    "Browse services" => {
      "success" => "Button",
      "success_content" => "Text"
    },
    "Check-in" => {
      "warning" => "Button",
      "warning_content" => "Text"
    },
    "Book appointment" => {
      "accent" => "Button",
      "accent_content" => "Text"
    },
    "Upsell screen" => {
      "upsell_bg" => "Background",
      "upsell_content" => "Text"
    },
    "Onscreen keyboard" => {
      "keyboard_bg" => "Key background",
      "keyboard_content" => "Key text",
      "keyboard_accent" => "Accent key",
      "keyboard_delete" => "Delete key"
    }
  }.freeze

  CUSTOM_RADIUS_LABELS = {
    "radius_field" => "Buttons & inputs",
    "radius_box" => "Cards & panels",
    "radius_selector" => "Badges & pills"
  }.freeze

  CUSTOM_RADIUS_OPTIONS = [
    [ "Theme default", "" ],
    [ "Sharp (0.25rem)", "0.25rem" ],
    [ "Default (0.5rem)", "0.5rem" ],
    [ "Rounded (1rem)", "1rem" ],
    [ "Extra rounded (1.5rem)", "1.5rem" ],
    [ "Pill (2rem)", "2rem" ]
  ].freeze

  COLOR_VALUE_FORMAT = /\A(?:oklch\([\d.\-%\s\/]+\)|#[0-9a-fA-F]{3,8})\z/
  RADIUS_VALUE_FORMAT = /\A\d+(\.\d+)?rem\z/

  included do
    after_initialize do
      self.kiosk_theme_custom = {} if kiosk_theme_custom.nil?
    end

    before_validation :normalize_kiosk_theme

    validates :kiosk_theme, inclusion: { in: KIOSK_THEMES + LEGACY_KIOSK_THEME_ALIASES.keys }
    validates :kiosk_fallback_icon, presence: true, inclusion: { in: ApplicationHelper::MATERIAL_ICON_GROUPS.values.flatten }
    validate :kiosk_theme_custom_values_are_valid
  end

  def resolved_kiosk_theme
    return "kiosk-custom" if normalize_kiosk_theme_slug(kiosk_theme) == "custom"

    normalize_kiosk_theme_slug(kiosk_theme).presence_in(KIOSK_THEMES - [ "custom" ]) || DEFAULT_KIOSK_THEME
  end

  def kiosk_theme_custom_colors
    (kiosk_theme_custom || {}).slice(*CUSTOM_COLOR_KEYS).compact_blank
  end

  def kiosk_theme_custom_radii
    (kiosk_theme_custom || {}).slice(*CUSTOM_RADIUS_KEYS).compact_blank
  end

  def kiosk_theme_inline_style
    declarations = []
    declarations.concat(color_inline_declarations) if normalize_kiosk_theme_slug(kiosk_theme) == "custom"
    declarations.concat(radius_inline_declarations)
    declarations.join(" ")
  end

  def assign_kiosk_theme_custom_from_params(raw)
    return unless raw.respond_to?(:permit)

    permitted = raw.permit(*CUSTOM_THEME_KEYS.map(&:to_sym))
    cleaned = permitted.to_h.each_with_object({}) do |(key, value), result|
      normalized = normalize_custom_token_value(key, value)
      result[key] = normalized if normalized.present?
    end

    self.kiosk_theme_custom = cleaned
  end

  private

  def normalize_kiosk_theme
    self.kiosk_theme = normalize_kiosk_theme_slug(kiosk_theme) if kiosk_theme.present?
  end

  def normalize_kiosk_theme_slug(theme)
    LEGACY_KIOSK_THEME_ALIASES.fetch(theme, theme)
  end

  def color_inline_declarations
    kiosk_theme_custom_colors.map { |key, value| "--color-#{key.tr("_", "-")}: #{value};" }
  end

  def radius_inline_declarations
    kiosk_theme_custom_radii.map { |key, value| "--#{key.tr("_", "-")}: #{value};" }
  end

  def kiosk_theme_custom_values_are_valid
    kiosk_theme_custom_colors.each do |key, value|
      next if value.match?(COLOR_VALUE_FORMAT)

      label = CUSTOM_COLOR_LABELS.fetch(key, key.humanize)
      errors.add(:kiosk_theme_custom, "#{label} must be a valid color")
    end

    kiosk_theme_custom_radii.each do |key, value|
      next if value.match?(RADIUS_VALUE_FORMAT)

      label = CUSTOM_RADIUS_LABELS.fetch(key, key.humanize)
      errors.add(:kiosk_theme_custom, "#{label} must use a rem value (e.g. 0.5rem)")
    end
  end

  def normalize_custom_token_value(key, value)
    stripped = value.to_s.strip
    return nil if stripped.blank?

    if CUSTOM_COLOR_KEYS.include?(key)
      return stripped.downcase if stripped.start_with?("#")
    end

    stripped
  end
end
