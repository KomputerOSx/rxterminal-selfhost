# frozen_string_literal: true

require "test_helper"

class BillingPlanLimitsTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @organization = create_personal_without_trial!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
  end

  test "plan_limits uses starter limits when unsubscribed" do
    assert_equal Billing::Plans::STARTER_LIMITS, @organization.plan_limits
  end

  test "plan_limits follows the active subscription plan" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_equal Billing::Plans::BUSINESS_LIMITS, @organization.plan_limits
    end
  end

  test "within_member_limit? at starter boundary" do
    assert_equal 1, @organization.member_count_with_pending
    assert_not @organization.within_member_limit?
    assert @organization.at_member_limit?
  end

  test "within_member_limit? is always true on business" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert @organization.within_member_limit?
      assert_not @organization.at_member_limit?
    end
  end

  test "within_service_limit? at starter boundary" do
    create_services!(2)

    assert @organization.within_service_limit?

    create_services!(1)

    assert_not @organization.within_service_limit?
  end

  test "within_service_limit? rejects a fourth service on starter" do
    create_services!(3)

    assert_not @organization.within_service_limit?
  end

  test "within_service_limit? ignores soft-deleted services" do
    create_services!(3)
    @organization.services.visible.last.soft_delete!

    assert @organization.within_service_limit?
  end

  test "within_upsell_rule_limit? at starter boundary" do
    create_upsell_rules!(1)

    assert_not @organization.within_upsell_rule_limit?

    @organization.upsell_rules.update_all(active: false)

    assert @organization.within_upsell_rule_limit?
  end

  test "within_monthly_request_limit? at starter boundary" do
    create_service_requests!(200)

    assert_not @organization.within_monthly_request_limit?

    @organization.service_requests.last.destroy!

    assert @organization.within_monthly_request_limit?
  end

  test "monthly_request_count resets each calendar month" do
    create_service_requests!(2, at: Time.current)

    travel_to 1.month.from_now do
      assert_equal 0, @organization.monthly_request_count
    end
  end

  test "feature flags follow plan limits" do
    assert_not @organization.appointments_enabled?
    assert_not @organization.kiosk_enabled?
    assert_not @organization.custom_domain_enabled?

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert @organization.appointments_enabled?
      assert @organization.kiosk_enabled?
      assert @organization.custom_domain_enabled?
    end
  end

  test "audit_logs_scope limits starter orgs to seven days" do
    old_log = AuditLog.create!(event_type: :login_success, created_at: 10.days.ago)
    recent_log = AuditLog.create!(event_type: :login_success, created_at: 1.day.ago)

    scoped = @organization.audit_logs_scope(AuditLog.all)

    assert_includes scoped, recent_log
    assert_not_includes scoped, old_log
  end

  test "audit_logs_scope is unrestricted on business" do
    old_log = AuditLog.create!(event_type: :login_success, created_at: 10.days.ago)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_includes @organization.audit_logs_scope(AuditLog.all), old_log
      assert_nil @organization.audit_log_retention_days
    end
  end

  test "plan_usage_items summarizes starter limits and usage" do
    items = @organization.plan_usage_items.index_by(&:key)

    assert_equal 1, items[:members].used
    assert_equal 1, items[:members].limit
    assert items[:members].at_limit

    assert_equal 0, items[:services].used
    assert_equal 3, items[:services].limit

    assert_not items[:appointments].enabled
    assert_equal "Last 7 days", items[:audit_logs].value_label
  end

  test "plan_usage_items shows unlimited business limits" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      items = @organization.plan_usage_items.index_by(&:key)

      assert_nil items[:members].limit
      assert items[:appointments].enabled
      assert_equal "Unlimited", items[:audit_logs].value_label
    end
  end

  private

  def create_services!(count)
    start = @organization.services.count

    count.times do |offset|
      index = start + offset
      @organization.services.create!(
        internal_name: "service_#{index}_#{SecureRandom.hex(4)}",
        display_name: "Service #{index}",
        estimated_duration: 15,
        active: true,
        calendar: @calendar
      )
    end
  end

  def create_upsell_rules!(count)
    trigger = @organization.services.create!(
      internal_name: "trigger_#{Time.current.to_i}",
      display_name: "Trigger",
      estimated_duration: 15,
      active: true,
      calendar: @calendar
    )
    suggested = @organization.services.create!(
      internal_name: "suggested_#{Time.current.to_i}",
      display_name: "Suggested",
      estimated_duration: 15,
      active: true,
      calendar: @calendar
    )

    count.times do |index|
      rule = @organization.upsell_rules.build(
        name: "Rule #{index}",
        trigger_service: trigger,
        suggested_service: suggested,
        frequency_type: "every_nth_customer",
        frequency_value: 1,
        visit_type: "any",
        active: true
      )
      rule.upsell_templates.build(title: "Offer", description: "Details", cta_text: "Yes")
      rule.save!
    end
  end

  def create_service_requests!(count, at: Time.current)
    service = @organization.services.create!(
      internal_name: "walk_in_#{Time.current.to_i}",
      display_name: "Walk-in",
      estimated_duration: 15,
      active: true,
      calendar: @calendar
    )

    travel_to at do
      count.times do |index|
        @organization.service_requests.create!(
          service: service,
          first_name: "Pat",
          last_name: "Customer#{index}",
          dob: Date.new(1990, 1, 1),
          postcode: "NE1 1AA",
          queue_number: index + 1,
          queue_date: Date.current,
          status: "waiting",
          request_type: "immediate"
        )
      end
    end
  end
end
