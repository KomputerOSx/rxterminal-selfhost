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
  end
end
