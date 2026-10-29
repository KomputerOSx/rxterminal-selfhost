require "test_helper"

class Notifications::Rules::PaymentFailedTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create_personal_for!(users(:one))
  end

  test "recipients is the organization's owners" do
    rule = Notifications::Rules::PaymentFailed.new(
      actor: nil, resource: @organization, organization: @organization, metadata: {}
    )

    assert_equal [ users(:one) ], rule.recipients.to_a
  end

  test "recipients is empty without an organization" do
    rule = Notifications::Rules::PaymentFailed.new(actor: nil, resource: nil, organization: nil, metadata: {})

    assert_empty rule.recipients
  end

  test "title, body, and url" do
    rule = Notifications::Rules::PaymentFailed.new(
      actor: nil, resource: @organization, organization: @organization, metadata: {}
    )

    assert_includes rule.title, @organization.name
    assert_includes rule.body, "payment"
    assert_equal "/billing", rule.url
  end
end
