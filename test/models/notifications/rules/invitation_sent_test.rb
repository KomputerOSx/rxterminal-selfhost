require "test_helper"

class Notifications::Rules::InvitationSentTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create!(name: "Acme", slug: "acme")
  end

  test "recipients matches an existing user by invited email" do
    rule = Notifications::Rules::InvitationSent.new(
      actor: @owner, resource: @organization, organization: @organization,
      metadata: { "email" => users(:two).email }
    )

    assert_equal [ users(:two) ], rule.recipients.to_a
  end

  test "recipients is empty when the invited email has no account" do
    rule = Notifications::Rules::InvitationSent.new(
      actor: @owner, resource: @organization, organization: @organization,
      metadata: { "email" => "nobody@example.com" }
    )

    assert_empty rule.recipients
  end

  test "title, body, and url" do
    rule = Notifications::Rules::InvitationSent.new(
      actor: @owner, resource: @organization, organization: @organization,
      metadata: { "email" => users(:two).email }
    )

    assert_equal "You've been invited to join Acme", rule.title
    assert_includes rule.body, "Acme"
    assert_equal "/org/members", rule.url
  end
end
