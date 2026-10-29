# frozen_string_literal: true

require "test_helper"

class PortalThemingTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create_personal_for!(users(:one))
  end

  test "default portal theme is classic" do
    assert_equal "kiosk-default", Organization::DEFAULT_PORTAL_THEME
    @organization.portal_theme = "invalid-theme"
    assert_equal "kiosk-default", @organization.resolved_portal_theme
  end

  test "resolved_portal_theme maps custom to kiosk-custom base theme" do
    @organization.portal_theme = "custom"
    assert_equal "kiosk-custom", @organization.resolved_portal_theme
  end

  test "portal_theme_inline_style builds css variables from custom colors" do
    @organization.portal_theme = "custom"
    @organization.portal_theme_custom = {
      "primary" => "#112233",
      "base_100" => "#ffffff"
    }

    assert_includes @organization.portal_theme_inline_style, "--color-primary: #112233;"
    assert_includes @organization.portal_theme_inline_style, "--color-base-100: #ffffff;"
  end

  test "portal_theme_inline_style applies radius overrides on preset themes" do
    @organization.portal_theme = "kiosk-violet"
    @organization.portal_theme_custom = { "radius_box" => "1rem" }

    assert_includes @organization.portal_theme_inline_style, "--radius-box: 1rem;"
    assert_not_includes @organization.portal_theme_inline_style, "--color-"
  end
end
