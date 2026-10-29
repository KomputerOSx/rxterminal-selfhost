# frozen_string_literal: true

require "test_helper"

class OrganizationSubscriptionStateTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create_personal_for!(users(:one))
  end

  test "active_subscription? is false without a subscription or local trial" do
    organization = create_personal_without_trial!(users(:one))
    assert_not organization.active_subscription?
  end

  test "active_subscription? is true during a local no-card trial" do
    assert @organization.on_trial?
    assert @organization.active_subscription?
  end

  test "active_subscription? is true for trialing and active statuses" do
    with_active_subscription(@organization, Billing::Plans::STARTER) do
      assert @organization.active_subscription?

      @organization.payment_processor.subscription.update!(status: "trialing")
      assert @organization.active_subscription?
    end
  end

  test "active_subscription? is true for past_due but locked? is false" do
    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.payment_processor.subscription.update!(status: "past_due")

      assert @organization.past_due?
      assert @organization.active_subscription?
      assert_not @organization.locked?
    end
  end

  test "active_subscription? is true during a canceled grace period" do
    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.payment_processor.subscription.cancel

      assert @organization.payment_processor.subscription.on_grace_period?
      assert @organization.active_subscription?
      assert_not @organization.locked?
    end
  end

  test "locked? is true when a subscription has fully ended" do
    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.payment_processor.subscription.update!(status: "canceled", ends_at: 1.day.ago)

      assert_not @organization.active_subscription?
      assert @organization.locked?
    end
  end

  test "locked? is true for unpaid subscriptions" do
    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.payment_processor.subscription.update!(status: "unpaid", ends_at: nil)

      assert @organization.locked?
    end
  end

  test "locked? is true when local trial ended without an active subscription" do
    @organization.end_trial!
    assert @organization.locked?
  end

  test "locked? is true when org has never subscribed" do
    organization = create_personal_without_trial!(users(:one))
    assert_not organization.on_trial?
    assert_not organization.active_subscription?
    assert organization.locked?
  end

  test "plan_reconciliation_required? is true while blocking setup is pending" do
    @organization.update!(plan_reconciliation_blocking_at: Time.current)
    assert @organization.plan_reconciliation_required?

    @organization.update!(plan_reconciliation_completed_at: Time.current)
    assert_not @organization.plan_reconciliation_required?
  end
end
