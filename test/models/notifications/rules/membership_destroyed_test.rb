require "test_helper"

class Notifications::Rules::MembershipDestroyedTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Acme", slug: "acme")
  end

  test "recipients is the removed user" do
    rule = Notifications::Rules::MembershipDestroyed.new(
      actor: users(:one), resource: @organization, organization: @organization,
      metadata: { "removed_user_id" => users(:two).id }
    )

    assert_equal [ users(:two) ], rule.recipients.to_a
  end

  test "recipients is empty for self-removal" do
    rule = Notifications::Rules::MembershipDestroyed.new(
      actor: users(:two), resource: @organization, organization: @organization,
      metadata: { "removed_user_id" => users(:two).id, "self_removal" => true }
    )

    assert_empty rule.recipients
  end
end
