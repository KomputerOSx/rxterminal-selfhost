# frozen_string_literal: true

require "test_helper"

class TrialTest < ActionDispatch::IntegrationTest
  test "first organization starts a 30-day no-card trial at signup" do
    user = User.create!(first_name: "Trial", last_name: "User", email: "trial-user@example.com",
      password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52", confirmed_at: Time.current)

    organization = Organization.create_personal_for!(user)

    assert organization.on_trial?
    assert_equal 30, Organization::TRIAL_DAYS
    assert_equal Billing::Plans::BUSINESS.key, organization.trial_plan_key
    assert user.reload.trial_granted_at.present?
    assert organization.active_subscription?
    assert_not organization.locked?
  end

  test "second organization for the same account does not get a trial" do
    user = users(:one)
    first = Organization.create_personal_for!(user)
    assert first.on_trial?

    second = Organization.create_for!(user, name: "Branch Two")

    assert_not second.on_trial?
    assert_not second.active_subscription?
    assert second.locked?
  end

  test "trial reminder job emails owners three days before trial ends" do
    organization = Organization.create_personal_for!(users(:one))
    organization.update!(trial_ends_at: 3.days.from_now)

    assert_enqueued_emails 1 do
      TrialReminderJob.perform_now
    end
  end

  test "trial reminder job emails owners on the day the trial ends" do
    organization = Organization.create_personal_for!(users(:one))
    organization.update!(trial_ends_at: Time.current)

    assert_enqueued_emails 1 do
      TrialReminderJob.perform_now
    end
  end
end
