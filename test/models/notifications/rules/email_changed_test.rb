require "test_helper"

class Notifications::Rules::EmailChangedTest < ActiveSupport::TestCase
  test "recipients is the actor" do
    rule = Notifications::Rules::EmailChanged.new(
      actor: users(:one), resource: nil, organization: nil, metadata: { "email" => "new@example.com" }
    )

    assert_equal [ users(:one) ], rule.recipients.to_a
  end

  test "recipients is empty without an actor" do
    rule = Notifications::Rules::EmailChanged.new(
      actor: nil, resource: nil, organization: nil, metadata: { "email" => "new@example.com" }
    )

    assert_empty rule.recipients
  end

  test "channels is in_app only" do
    assert_equal [ :in_app ], Notifications::Rules::EmailChanged.channels
  end

  test "title, body, and url" do
    rule = Notifications::Rules::EmailChanged.new(
      actor: users(:one), resource: nil, organization: nil, metadata: { "email" => "new@example.com" }
    )

    assert_equal "Your email address was changed", rule.title
    assert_includes rule.body, "new@example.com"
    assert_equal "/profile", rule.url
  end
end
