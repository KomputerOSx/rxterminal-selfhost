# frozen_string_literal: true

module Onboarding
  # Seeds starter Services and one demo UpsellRule for a chosen Onboarding::BusinessPresets
  # preset. Caps creation at whatever plan-limit room the organization actually has (Starter's
  # 3 services / 1 upsell rule, checked via Organization#plan_limits) rather than assuming the
  # 3-service preset shape always fits.
  class PresetApplier
    def initialize(organization)
      @organization = organization
    end

    def apply!(business_type)
      preset = BusinessPresets.find(business_type)
      return if preset.nil?

      services = create_services(preset.services)
      create_upsell_rule(preset.upsell_rule, services) if preset.upsell_rule
    end

    private

    attr_reader :organization

    def create_services(service_presets)
      capped = service_presets
      limit = organization.plan_limits.max_services
      if limit
        remaining = [ limit - organization.services.counting_toward_plan_limit.count, 0 ].max
        capped = service_presets.first(remaining)
      end

      capped.map { |preset| create_service!(preset) }
    end

    def create_service!(preset)
      organization.services.create!(
        internal_name: preset.internal_name,
        display_name: preset.display_name,
        icon: preset.icon,
        estimated_duration: preset.estimated_duration,
        allows_immediate: preset.allows_immediate,
        requires_appointment: preset.requires_appointment,
        active: true
      )
    end

    def create_upsell_rule(rule_preset, services)
      return if organization.at_upsell_rule_limit?

      trigger = services[rule_preset.trigger_index]
      suggested = services[rule_preset.suggested_index]
      return unless trigger && suggested

      rule = organization.upsell_rules.build(
        name: rule_preset.name,
        trigger_service: trigger,
        suggested_service: suggested,
        frequency_type: "every_nth_customer",
        frequency_value: 3,
        active: true
      )
      rule.upsell_templates.build(title: rule_preset.template_title, cta_text: rule_preset.template_cta)
      rule.save!
    end
  end
end
