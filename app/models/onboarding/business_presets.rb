# frozen_string_literal: true

module Onboarding
  # Seed data offered on the onboarding "business_type" step, loaded from
  # config/onboarding_business_presets.yml so presets can be edited without touching code.
  module BusinessPresets
    CONFIG_PATH = Rails.root.join("config/onboarding_business_presets.yml")

    ServicePreset = Struct.new(:internal_name, :display_name, :icon, :estimated_duration,
      :allows_immediate, :requires_appointment, keyword_init: true)

    UpsellRulePreset = Struct.new(:name, :trigger_index, :suggested_index, :template_title,
      :template_cta, keyword_init: true)

    Preset = Struct.new(:key, :label, :services, :upsell_rule, keyword_init: true)

    def self.load_all
      config = YAML.load_file(CONFIG_PATH) || {}

      config.map do |key, attrs|
        Preset.new(
          key: key.to_s,
          label: attrs.fetch("label"),
          services: Array(attrs["services"]).map { |service| build_service_preset(service) },
          upsell_rule: attrs["upsell_rule"] ? build_upsell_rule_preset(attrs["upsell_rule"]) : nil
        )
      end.freeze
    end

    def self.build_service_preset(attrs)
      ServicePreset.new(
        internal_name: attrs.fetch("internal_name"),
        display_name: attrs.fetch("display_name"),
        icon: attrs["icon"],
        estimated_duration: attrs.fetch("estimated_duration"),
        allows_immediate: attrs.fetch("allows_immediate", false),
        requires_appointment: attrs.fetch("requires_appointment", false)
      )
    end
    private_class_method :build_service_preset

    def self.build_upsell_rule_preset(attrs)
      UpsellRulePreset.new(
        name: attrs.fetch("name"),
        trigger_index: attrs.fetch("trigger_index"),
        suggested_index: attrs.fetch("suggested_index"),
        template_title: attrs.fetch("template_title"),
        template_cta: attrs.fetch("template_cta")
      )
    end
    private_class_method :build_upsell_rule_preset

    ALL = load_all

    def self.all = ALL
    def self.find(key) = ALL.find { |preset| preset.key == key.to_s }
    def self.options = ALL.map { |preset| [ preset.label, preset.key ] }
  end
end
