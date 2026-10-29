# frozen_string_literal: true

require "test_helper"

class KioskThemingTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create_personal_for!(users(:one))
  end

  test "default kiosk theme is classic" do
    assert_equal "kiosk-default", Organization::DEFAULT_KIOSK_THEME
    assert_equal "kiosk-default", Organization.columns_hash["kiosk_theme"].default
    @organization.kiosk_theme = "invalid-theme"
    assert_equal "kiosk-default", @organization.resolved_kiosk_theme
  end

  test "resolved_kiosk_theme returns preset name" do
    @organization.kiosk_theme = "kiosk-radiant-orange"
    assert_equal "kiosk-radiant-orange", @organization.resolved_kiosk_theme
  end

  test "legacy kiosk theme slugs map to new presets" do
    @organization.kiosk_theme = "kiosk-ocean"
    assert_equal "kiosk-cmyk", @organization.resolved_kiosk_theme

    @organization.valid?
    assert_equal "kiosk-cmyk", @organization.kiosk_theme
  end

  test "resolved_kiosk_theme maps custom to kiosk-custom base theme" do
    @organization.kiosk_theme = "custom"
    assert_equal "kiosk-custom", @organization.resolved_kiosk_theme
  end

  test "kiosk_theme_inline_style builds css variables from custom colors" do
    @organization.kiosk_theme = "custom"
    @organization.kiosk_theme_custom = {
      "primary" => "#112233",
      "accent" => "#aabbcc",
      "base_100" => "#ffffff",
      "upsell_bg" => "#445566",
      "upsell_content" => "#eeeeee"
    }

    assert_includes @organization.kiosk_theme_inline_style, "--color-primary: #112233;"
    assert_includes @organization.kiosk_theme_inline_style, "--color-accent: #aabbcc;"
    assert_includes @organization.kiosk_theme_inline_style, "--color-base-100: #ffffff;"
    assert_includes @organization.kiosk_theme_inline_style, "--color-upsell-bg: #445566;"
    assert_includes @organization.kiosk_theme_inline_style, "--color-upsell-content: #eeeeee;"
  end

  test "kiosk_theme_inline_style applies radius overrides on preset themes" do
    @organization.kiosk_theme = "light"
    @organization.kiosk_theme_custom = { "radius_box" => "1rem", "radius_field" => "0.5rem" }

    assert_includes @organization.kiosk_theme_inline_style, "--radius-box: 1rem;"
    assert_includes @organization.kiosk_theme_inline_style, "--radius-field: 0.5rem;"
    assert_not_includes @organization.kiosk_theme_inline_style, "--color-"
  end

  test "invalid custom radius is rejected" do
    @organization.kiosk_theme = "light"
    @organization.kiosk_theme_custom = { "radius_box" => "12px" }

    assert_not @organization.valid?
    assert @organization.errors[:kiosk_theme_custom].any?
  end

  test "invalid custom color is rejected" do
    @organization.kiosk_theme = "custom"
    @organization.kiosk_theme_custom = { "primary" => "not-a-color" }

    assert_not @organization.valid?
    assert @organization.errors[:kiosk_theme_custom].any?
  end
end
