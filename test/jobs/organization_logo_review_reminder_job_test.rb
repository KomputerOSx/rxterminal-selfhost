# frozen_string_literal: true

require "test_helper"

class OrganizationLogoReviewReminderJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @admin = users(:one)
    @admin.grant_role!(Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_ADMIN) { |r| r.permanent = true })
    @organization = Organization.create_personal_for!(users(:two))
  end

  test "emails each system admin the number of pending logos" do
    2.times { OrganizationLogo.create!(organization: @organization, uploaded_by: users(:two)) }
    OrganizationLogo.create!(organization: @organization, uploaded_by: users(:two)).approve!(reviewed_by: @admin)

    assert_enqueued_email_with OrganizationLogoReviewMailer, :pending_reminder, args: [ @admin, 2 ] do
      OrganizationLogoReviewReminderJob.perform_now
    end
    assert_enqueued_emails 1
  end

  test "sends nothing when there are no pending logos" do
    OrganizationLogo.create!(organization: @organization, uploaded_by: users(:two)).approve!(reviewed_by: @admin)

    assert_no_enqueued_emails do
      OrganizationLogoReviewReminderJob.perform_now
    end
  end

  test "does not email users without the system admin role" do
    OrganizationLogo.create!(organization: @organization, uploaded_by: users(:two))
    @admin.user_roles.destroy_all

    assert_no_enqueued_emails do
      OrganizationLogoReviewReminderJob.perform_now
    end
  end
end
