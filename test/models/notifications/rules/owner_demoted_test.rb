require "test_helper"

class Notifications::Rules::OwnerDemotedTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Acme", slug: "acme")
  end

  test "recipients is the demoted user" do
    rule = Notifications::Rules::OwnerDemoted.new(
      actor: users(:one), resource: @organization, organization: @organization,
      metadata: { "target_user_id" => users(:two).id }
    )

    assert_equal [ users(:two) ], rule.recipients.to_a
  end

  test "recipients is empty when the owner steps themselves down" do
    rule = Notifications::Rules::OwnerDemoted.new(
      actor: users(:two), resource: @organization, organization: @organization,
      metadata: { "target_user_id" => users(:two).id, "self_initiated" => true }
    )

    assert_empty rule.recipients
  end
end
