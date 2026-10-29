require "test_helper"

class Notifications::Rules::InvitationAcceptedTest < ActiveSupport::TestCase
  setup do
    @inviter = users(:one)
    @organization = Organization.create!(name: "Acme", slug: "acme")
    @role = Role.find_or_create_by!(scope: :app, name: Role::APP_USER)
    @invitation, _raw = OrganizationInvitation.generate_for!(
      organization: @organization, email: users(:two).email, role: @role, invited_by: @inviter
    )
  end

  test "recipients is the inviter" do
    rule = Notifications::Rules::InvitationAccepted.new(
      actor: users(:two), resource: @organization, organization: @organization,
      metadata: { "invitation_id" => @invitation.id }
    )

    assert_equal [ @inviter ], rule.recipients.to_a
  end

  test "recipients is empty when the invitation has no inviter or can't be found" do
    rule = Notifications::Rules::InvitationAccepted.new(
      actor: users(:two), resource: @organization, organization: @organization,
      metadata: { "invitation_id" => -1 }
    )

    assert_empty rule.recipients
  end
end
