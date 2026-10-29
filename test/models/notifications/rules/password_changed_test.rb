require "test_helper"

class Notifications::Rules::PasswordChangedTest < ActiveSupport::TestCase
  test "recipients is the actor when the change succeeded" do
    rule = Notifications::Rules::PasswordChanged.new(
      actor: users(:one), resource: nil, organization: nil, metadata: { "success" => true }
    )

    assert_equal [ users(:one) ], rule.recipients.to_a
  end

  test "recipients is empty when the change failed" do
    rule = Notifications::Rules::PasswordChanged.new(
      actor: users(:one), resource: nil, organization: nil, metadata: { "success" => false, "reason" => "incorrect_current_password" }
    )

    assert_empty rule.recipients
  end

  test "recipients is empty without an actor even if metadata claims success" do
    rule = Notifications::Rules::PasswordChanged.new(
      actor: nil, resource: nil, organization: nil, metadata: { "success" => true }
    )

    assert_empty rule.recipients
  end

  test "title, body, and url" do
    rule = Notifications::Rules::PasswordChanged.new(
      actor: users(:one), resource: nil, organization: nil, metadata: { "success" => true }
    )

    assert_equal "Your password was changed", rule.title
    assert_includes rule.body, "password"
    assert_equal "/profile", rule.url
  end
end
