require "test_helper"

class Notifications::Rules::RoleRevokedTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Acme", slug: "acme")
    @membership = @organization.memberships.create!(user: users(:two))
  end

  test "recipients is the demoted member" do
    rule = Notifications::Rules::RoleRevoked.new(
      actor: users(:one), resource: @organization, organization: @organization,
      metadata: { "membership_id" => @membership.id, "role" => Role::APP_ADMIN }
    )

    assert_equal [ users(:two) ], rule.recipients.to_a
  end

  test "recipients is empty for the system-scope RBAC revoke shape (no organization)" do
    rule = Notifications::Rules::RoleRevoked.new(
      actor: users(:one), resource: users(:two), organization: nil,
      metadata: { "role" => Role::SYSTEM_ADMIN }
    )

    assert_empty rule.recipients
  end
end
