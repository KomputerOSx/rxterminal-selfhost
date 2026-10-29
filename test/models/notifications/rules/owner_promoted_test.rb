require "test_helper"

class Notifications::Rules::OwnerPromotedTest < ActiveSupport::TestCase
  test "recipients is the promoted user" do
    organization = Organization.create!(name: "Acme", slug: "acme")
    rule = Notifications::Rules::OwnerPromoted.new(
      actor: users(:one), resource: organization, organization: organization,
      metadata: { "target_user_id" => users(:two).id }
    )

    assert_equal [ users(:two) ], rule.recipients.to_a
  end
end
