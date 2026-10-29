require "test_helper"

class NotificationDispatchJobTest < ActiveJob::TestCase
  setup do
    @owner = users(:one)
    @invitee = users(:two)
    @organization = Organization.create!(name: "Acme", slug: "acme")
  end

  def dispatch!
    NotificationDispatchJob.perform_now(
      event_type: "organization_invitation_sent",
      actor_id: @owner.id,
      resource_type: "Organization",
      resource_id: @organization.id,
      organization_id: @organization.id,
      metadata: { "email" => @invitee.email }
    )
  end

  test "creates an in-app notification and enqueues an email by default" do
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      dispatch!
    end

    recipient = @invitee.notification_recipients.last
    assert recipient.present?
    assert_equal "You've been invited to join Acme", recipient.notification.title
    assert_equal "/org/members", recipient.notification.url
    assert_equal "membership", recipient.notification.category
  end

  test "skips the in-app channel when the user opted out" do
    @invitee.disable_notification_channel!("membership", "in_app")

    dispatch!

    assert_nil @invitee.notification_recipients.last
  end

  test "skips the email channel when the user opted out" do
    @invitee.disable_notification_channel!("membership", "email")

    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) { dispatch! }

    assert @invitee.notification_recipients.last.present?
  end

  test "does nothing for an event type with no registered rule" do
    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      NotificationDispatchJob.perform_now(
        event_type: "login_success", actor_id: @owner.id, resource_type: nil,
        resource_id: nil, organization_id: nil, metadata: {}
      )
    end
  end

  test "does nothing when the rule has no recipients" do
    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      NotificationDispatchJob.perform_now(
        event_type: "organization_invitation_sent", actor_id: @owner.id,
        resource_type: "Organization", resource_id: @organization.id,
        organization_id: @organization.id, metadata: { "email" => "nobody@example.com" }
      )
    end
  end

  test "swallows errors from a broken rule instead of raising" do
    NotificationDispatchJob.perform_now(
      event_type: "organization_invitation_sent", actor_id: @owner.id,
      resource_type: "NotARealClass", resource_id: @organization.id,
      organization_id: @organization.id, metadata: { "email" => @invitee.email }
    )

    assert_nil @invitee.notification_recipients.last
  end
end
