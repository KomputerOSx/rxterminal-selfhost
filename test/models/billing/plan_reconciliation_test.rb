# frozen_string_literal: true

require "test_helper"

class Billing::PlanReconciliationTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create_personal_for!(users(:one))
  end

  test "applies? is false when the org already fits Starter limits" do
    wizard = Billing::PlanReconciliation.new(@organization, mode: :scheduled)
    assert_not wizard.applies?
  end

  test "applies? is true when members exceed Starter limits" do
    @organization.memberships.create!(user: users(:two))

    wizard = Billing::PlanReconciliation.new(@organization, mode: :scheduled)
    assert wizard.applies?
    assert_includes wizard.required_steps, :members
  end

  test "intro is the first required step when reconciliation applies" do
    @organization.memberships.create!(user: users(:two))

    wizard = Billing::PlanReconciliation.new(@organization, mode: :scheduled)
    assert_equal :intro, wizard.first_step
    assert_includes wizard.required_steps, :intro
    assert_includes wizard.required_steps, :members
    assert_equal :confirm, wizard.required_steps.last
  end

  test "previous_step returns the prior required step" do
    @organization.memberships.create!(user: users(:two))
    4.times do |index|
      @organization.services.create!(
        internal_name: "svc_#{index}",
        display_name: "Service #{index}",
        estimated_duration: 15,
        display_order: index
      )
    end

    wizard = Billing::PlanReconciliation.new(@organization, mode: :scheduled)
    assert_nil wizard.previous_step(:intro)
    assert_equal :intro, wizard.previous_step(:members)
    assert_equal :members, wizard.previous_step(:services)
    assert_equal :services, wizard.previous_step(:confirm)
  end

  test "selectable_upsell_rules only includes rules whose services are kept" do
    services = 4.times.map do |index|
      @organization.services.create!(
        internal_name: "svc_#{index}",
        display_name: "Service #{index}",
        estimated_duration: 15,
        display_order: index,
        allows_immediate: true
      )
    end
    viable_rule = create_upsell_rule!(
      name: "Viable rule",
      trigger_service: services[0],
      suggested_service: services[1]
    )
    create_upsell_rule!(
      name: "Archived suggested service",
      trigger_service: services[0],
      suggested_service: services[3]
    )

    wizard = Billing::PlanReconciliation.new(
      @organization,
      mode: :scheduled,
      choices: { "service_ids" => services.first(3).map(&:id) }
    )

    assert_equal [ viable_rule.id ], wizard.selectable_upsell_rules.pluck(:id)
  end

  test "changing kept services clears an invalid upsell rule choice" do
    services = 4.times.map do |index|
      @organization.services.create!(
        internal_name: "svc_#{index}",
        display_name: "Service #{index}",
        estimated_duration: 15,
        display_order: index,
        allows_immediate: true
      )
    end
    archived_suggested_rule = create_upsell_rule!(
      name: "Uses dropped service",
      trigger_service: services[0],
      suggested_service: services[3]
    )

    wizard = Billing::PlanReconciliation.new(
      @organization,
      mode: :scheduled,
      choices: {
        "service_ids" => services.map(&:id),
        "upsell_rule_id" => archived_suggested_rule.id
      }
    )

    wizard.merge_choices!(:services, service_ids: services.first(3).map(&:id))

    assert_nil wizard.choices["upsell_rule_id"]
  end

  test "apply_plan_reconciliation! archives excess services and removes members" do
    owner = users(:one)
    @organization.memberships.create!(user: users(:two))
    services = 4.times.map do |index|
      @organization.services.create!(
        internal_name: "svc_#{index}",
        display_name: "Service #{index}",
        estimated_duration: 15,
        display_order: index
      )
    end

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      @organization.apply_plan_reconciliation!(
        "service_ids" => services.first(3).map(&:id),
        "mode" => "immediate"
      )
    end

    assert_equal 1, @organization.memberships.count
    assert_equal 3, @organization.services.plan_active.count
    assert_equal 1, @organization.services.archived.count
  end

  private

  def create_upsell_rule!(name:, trigger_service:, suggested_service:)
    @organization.upsell_rules.create!(
      name: name,
      trigger_service: trigger_service,
      suggested_service: suggested_service,
      frequency_type: "every_nth_customer",
      frequency_value: 3,
      visit_type: "any",
      cooldown_days: 30,
      active: true,
      priority: 0,
      upsell_templates_attributes: [
        {
          title: "Template",
          description: "Description",
          cta_text: "Add service"
        }
      ]
    )
  end
end
