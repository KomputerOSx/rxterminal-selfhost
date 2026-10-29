# frozen_string_literal: true

require "test_helper"

class UpsellEngineTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @trigger = @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15,
      allows_immediate: true,
      icon: "vaccines"
    )
    @suggested = @organization.services.create!(
      internal_name: "blood-pressure",
      display_name: "Blood pressure check",
      estimated_duration: 10,
      allows_immediate: true,
      icon: "monitor_heart"
    )
    @rule = @organization.upsell_rules.create!(
      name: "Flu to BP",
      trigger_service: @trigger,
      suggested_service: @suggested,
      frequency_type: "every_nth_customer",
      frequency_value: 3,
      visit_type: "any",
      cooldown_days: 0,
      active: true,
      priority: 0,
      upsell_templates_attributes: [
        { title: "Variant A", cta_text: "Accept A" },
        { title: "Variant B", cta_text: "Accept B" }
      ]
    )
    @template_a, @template_b = @rule.upsell_templates.order(:id).to_a
  end

  test "select_template returns nil when rule has no templates" do
    @rule.upsell_templates.destroy_all

    assert_nil UpsellEngine.select_template(@rule.reload)
  end

  test "select_template returns the only template when rule has one variant" do
    @template_b.destroy

    assert_equal @template_a, UpsellEngine.select_template(@rule.reload)
  end

  test "select_template explores randomly ten percent of the time" do
    record_interactions(@template_a, accepted: 10, declined: 0)
    record_interactions(@template_b, accepted: 0, declined: 10)

    without_exploration do
      assert_equal @template_a, UpsellEngine.select_template(@rule)
    end

    with_exploration(index: 1) do
      assert_equal @template_b, UpsellEngine.select_template(@rule)
    end

    with_exploration(index: 0) do
      assert_equal @template_a, UpsellEngine.select_template(@rule)
    end
  end

  test "select_template exploits the highest conversion rate" do
    record_interactions(@template_a, accepted: 2, declined: 8)
    record_interactions(@template_b, accepted: 8, declined: 2)

    without_exploration do
      assert_equal @template_b, UpsellEngine.select_template(@rule)
    end
  end

  test "select_template counts accepted appointments toward conversion rate" do
    record_interactions(@template_a, accepted: 0, booked: 10, declined: 0)
    record_interactions(@template_b, accepted: 0, booked: 0, declined: 10)

    without_exploration do
      assert_equal @template_a, UpsellEngine.select_template(@rule)
    end
  end

  test "select_template gives unseen variants a chance before data exists" do
    UpsellEngine.stub(:explore?, false) do
      UpsellEngine.stub(:exploration_tiebreak, 0.5) do
        selected = UpsellEngine.select_template(@rule)
        assert_includes [ @template_a, @template_b ], selected
      end
    end
  end

  test "explore? is true below ten percent" do
    UpsellEngine.stub(:exploration_roll, 0.05) { assert UpsellEngine.explore? }
    UpsellEngine.stub(:exploration_roll, 0.5) { assert_not UpsellEngine.explore? }
  end

  test "evaluate matches an age-unrestricted rule when dob is missing" do
    result = evaluate(customer_dob: nil)

    assert_equal @rule, result[:rule]
  end

  test "evaluate returns a customer_hash even when dob is missing" do
    result = evaluate(customer_dob: nil)

    assert result[:customer_hash].present?
  end

  test "evaluate skips age-restricted rules when dob is missing" do
    @rule.update!(min_age: 18)

    assert_nil evaluate(customer_dob: nil)
  end

  test "evaluate matches age-restricted rules when dob makes the customer eligible" do
    @rule.update!(min_age: 18, max_age: 65)

    result = evaluate(customer_dob: 30.years.ago.to_date)

    assert_equal @rule, result[:rule]
  end

  test "evaluate skips first_visit/returning rules when dob is missing" do
    @rule.update!(visit_type: "first_visit")
    assert_nil evaluate(customer_dob: nil)

    @rule.update!(visit_type: "returning")
    assert_nil evaluate(customer_dob: nil)
  end

  test "evaluate matches a first_visit rule when dob is present and no prior interaction exists" do
    @rule.update!(visit_type: "first_visit")

    result = evaluate(customer_dob: 30.years.ago.to_date)

    assert_equal @rule, result[:rule]
  end

  test "evaluate ignores the recently-shown cooldown when dob is missing" do
    hash = UpsellEngine.build_hash(nil, "Jamie", "Fox")
    UpsellInteraction.create!(
      organization: @organization,
      upsell_rule: @rule,
      customer_hash: hash,
      outcome: "declined",
      accepted: false
    )

    result = evaluate(customer_dob: nil)

    assert_equal @rule, result[:rule]
  end

  test "age_eligible? allows unknown age when the rule has no age bounds" do
    assert UpsellEngine.age_eligible?(@rule, nil)
  end

  test "age_eligible? rejects unknown age when the rule has age bounds" do
    @rule.min_age = 18

    assert_not UpsellEngine.age_eligible?(@rule, nil)
  end

  test "visit_eligible? rejects first_visit/returning rules when dob is unknown" do
    @rule.visit_type = "first_visit"
    assert_not UpsellEngine.visit_eligible?(@rule, "somehash", dob_known: false)

    @rule.visit_type = "returning"
    assert_not UpsellEngine.visit_eligible?(@rule, "somehash", dob_known: false)
  end

  test "visit_eligible? allows any-type rules regardless of dob" do
    @rule.visit_type = "any"

    assert UpsellEngine.visit_eligible?(@rule, "somehash", dob_known: false)
  end

  private

  def evaluate(customer_dob:, first_name: "Jamie", last_name: "Fox")
    UpsellEngine.evaluate(
      organization: @organization,
      service: @trigger,
      customer_dob: customer_dob,
      customer_first_name: first_name,
      customer_last_name: last_name
    )
  end

  def without_exploration(&block)
    UpsellEngine.stub(:explore?, false, &block)
  end

  def with_exploration(index:, &block)
    UpsellEngine.stub(:explore?, true) do
      UpsellEngine.stub(:exploration_index, index, &block)
    end
  end

  def record_interactions(template, accepted: 0, booked: 0, declined: 0)
    accepted.times do
      create_interaction(template, "accepted_immediate")
    end
    booked.times do
      create_interaction(template, "accepted_appointment")
    end
    declined.times do
      create_interaction(template, "declined")
    end
  end

  def create_interaction(template, outcome)
    UpsellInteraction.create!(
      organization: @organization,
      upsell_rule: @rule,
      upsell_template: template,
      customer_hash: SecureRandom.hex(16),
      outcome: outcome,
      accepted: outcome.start_with?("accepted")
    )
  end
end
