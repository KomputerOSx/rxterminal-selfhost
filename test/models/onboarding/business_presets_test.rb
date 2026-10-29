# frozen_string_literal: true

require "test_helper"

module Onboarding
  class BusinessPresetsTest < ActiveSupport::TestCase
    test "loads presets from config/onboarding_business_presets.yml" do
      assert BusinessPresets.all.any?
      assert_equal Rails.root.join("config/onboarding_business_presets.yml"), BusinessPresets::CONFIG_PATH
    end

    test "find returns the preset matching a key, or nil for an unknown key" do
      preset = BusinessPresets.find("clinic")

      assert_equal "Medical / Clinic", preset.label
      assert_equal 3, preset.services.size
      assert_equal "Consultation", preset.services.first.display_name
      assert_nil BusinessPresets.find("not-a-real-preset")
    end

    test "general preset has no services and no upsell rule" do
      preset = BusinessPresets.find("general")

      assert_equal [], preset.services
      assert_nil preset.upsell_rule
    end

    test "options returns label/key pairs for every preset" do
      assert_includes BusinessPresets.options, [ "Medical / Clinic", "clinic" ]
      assert_includes BusinessPresets.options, [ "General / Other", "general" ]
    end
  end
end
