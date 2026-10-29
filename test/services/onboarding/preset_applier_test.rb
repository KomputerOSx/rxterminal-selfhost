# frozen_string_literal: true

require "test_helper"

module Onboarding
  class PresetApplierTest < ActiveSupport::TestCase
    setup do
      @organization = Organization.create_personal_for!(users(:one))
    end

    test "seeds the preset's services and one upsell rule linking two of them" do
      PresetApplier.new(@organization).apply!("clinic")

      services = @organization.services.order(:id)
      assert_equal 3, services.count
      assert_equal %w[Consultation Vaccination Follow-up\ appointment], services.pluck(:display_name)

      rule = @organization.upsell_rules.sole
      assert_equal services.first, rule.trigger_service
      assert_equal services.third, rule.suggested_service
      assert rule.upsell_templates.exists?
    end

    test "does nothing for an unknown preset key" do
      assert_no_difference -> { @organization.services.count } do
        PresetApplier.new(@organization).apply!("not-a-real-preset")
      end
    end

    test "does nothing for the general preset" do
      PresetApplier.new(@organization).apply!("general")

      assert_equal 0, @organization.services.count
      assert_equal 0, @organization.upsell_rules.count
    end

    test "caps seeded services at the organization's remaining plan-limit room" do
      with_active_subscription(@organization, Billing::Plans::STARTER) do
        @organization.services.create!(
          internal_name: "existing", display_name: "Existing", estimated_duration: 15, active: true
        )

        PresetApplier.new(@organization).apply!("clinic")

        # Starter allows 3 services total; 1 already existed, so only 2 more get seeded.
        assert_equal 3, @organization.services.count
      end
    end

    test "skips the upsell rule when the organization is already at its upsell rule limit" do
      with_active_subscription(@organization, Billing::Plans::STARTER) do
        trigger = @organization.services.create!(
          internal_name: "trigger", display_name: "Trigger", estimated_duration: 15, active: true
        )
        suggested = @organization.services.create!(
          internal_name: "suggested", display_name: "Suggested", estimated_duration: 15, active: true
        )
        existing_rule = @organization.upsell_rules.build(
          name: "Existing rule", trigger_service: trigger, suggested_service: suggested,
          frequency_type: "every_nth_customer", frequency_value: 1, active: true
        )
        existing_rule.upsell_templates.build(title: "Offer", cta_text: "Yes")
        existing_rule.save!

        assert_no_difference -> { @organization.upsell_rules.count } do
          PresetApplier.new(@organization).apply!("public_office")
        end
      end
    end
  end
end
