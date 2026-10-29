require "test_helper"

class Notifications::Rules::RoleGrantedTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Acme", slug: "acme")
    @membership = @organization.memberships.create!(user: users(:two))
  end

  test "recipients is the promoted member for the org admin-promotion shape" do
    rule = Notifications::Rules::RoleGranted.new(
      actor: users(:one), resource: @organization, organization: @organization,
      metadata: { "membership_id" => @membership.id, "role" => Role::APP_ADMIN }
    )

    assert_equal [ users(:two) ], rule.recipients.to_a
  end

  test "recipients is empty for the system-scope RBAC grant shape (no organization)" do
    role = Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_ADMIN)
    rule = Notifications::Rules::RoleGranted.new(
      actor: users(:one), resource: role, organization: nil,
      metadata: { "role" => role.name }
    )

    assert_empty rule.recipients
  end

  test "recipients is empty when membership_id doesn't resolve" do
    rule = Notifications::Rules::RoleGranted.new(
      actor: users(:one), resource: @organization, organization: @organization,
      metadata: { "membership_id" => -1 }
    )

    assert_empty rule.recipients
  end
end
