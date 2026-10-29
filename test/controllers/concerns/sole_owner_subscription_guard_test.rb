# frozen_string_literal: true

require "test_helper"

class SoleOwnerSubscriptionGuardTest < ActiveSupport::TestCase
  class GuardHost
    include SoleOwnerSubscriptionGuard

    attr_accessor :current_user

    def initialize(user)
      @current_user = user
    end
  end

  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @guard = GuardHost.new(@owner)
  end

  test "sole_owner_with_active_subscription? is true for a sole owner on trial" do
    assert @guard.send(:sole_owner_with_active_subscription?, @organization)
  end

  test "sole_owner_with_active_subscription? is false when a co-owner exists" do
    co_owner = @organization.memberships.create!(user: users(:two))
    co_owner.grant_role!(Role.find_by!(scope: :app, name: Role::APP_OWNER))

    assert_not @guard.send(:sole_owner_with_active_subscription?, @organization)
    assert_empty @guard.send(:organizations_blocking_account_deletion_for_active_subscription)
  end

  test "organizations_blocking_account_deletion_for_active_subscription ignores ended subscriptions" do
    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.payment_processor.subscription.update!(status: "canceled", ends_at: 1.day.ago)

      assert_empty @guard.send(:organizations_blocking_account_deletion_for_active_subscription)
    end
  end
end
