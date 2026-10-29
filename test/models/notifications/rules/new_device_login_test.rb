require "test_helper"

class Notifications::Rules::NewDeviceLoginTest < ActiveSupport::TestCase
  test "recipients is the actor" do
    rule = Notifications::Rules::NewDeviceLogin.new(
      actor: users(:one), resource: nil, organization: nil, metadata: { "ip_address" => "1.2.3.4" }
    )

    assert_equal [ users(:one) ], rule.recipients.to_a
  end

  test "recipients is empty without an actor" do
    rule = Notifications::Rules::NewDeviceLogin.new(
      actor: nil, resource: nil, organization: nil, metadata: {}
    )

    assert_empty rule.recipients
  end

  test "body is a short, generic heads-up" do
    rule = Notifications::Rules::NewDeviceLogin.new(
      actor: users(:one), resource: nil, organization: nil, metadata: {}
    )

    assert_includes rule.body, "device we haven't seen before"
  end

  test "details lists the raw IP and full device breakdown" do
    user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.129 Safari/537.36"

    rule = Notifications::Rules::NewDeviceLogin.new(
      actor: users(:one), resource: nil, organization: nil,
      metadata: { "ip_address" => "1.2.3.4", "user_agent" => user_agent }
    )

    assert_equal [
      [ "IP address", "1.2.3.4" ],
      [ "Browser", "Chrome 120.0.6099.129" ],
      [ "Operating system", "macOS 10.15.7" ],
      [ "Device type", "Desktop" ],
      [ "User agent", user_agent ]
    ], rule.details
  end

  test "details reports Unknown for missing ip and unrecognizable user agent" do
    rule = Notifications::Rules::NewDeviceLogin.new(
      actor: users(:one), resource: nil, organization: nil,
      metadata: { "user_agent" => "SomeCustomClient/1.0" }
    )

    assert_equal [
      [ "IP address", "Unknown" ],
      [ "Browser", nil ],
      [ "Operating system", nil ],
      [ "Device type", "Desktop" ],
      [ "User agent", "SomeCustomClient/1.0" ]
    ], rule.details
  end
end
