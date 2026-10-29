require "test_helper"

class Notifications::RegistryTest < ActiveSupport::TestCase
  test "for returns the registered rule class for a wired event type" do
    assert_equal Notifications::Rules::InvitationSent, Notifications::Registry.for(:organization_invitation_sent)
    assert_equal Notifications::Rules::InvitationSent, Notifications::Registry.for("organization_invitation_sent")
  end

  test "for returns nil for an event type with no rule" do
    assert_nil Notifications::Registry.for(:login_success)
    assert_nil Notifications::Registry.for(:rate_limit_triggered)
  end

  test "every registered rule declares itself under its own event_type key" do
    Notifications::Registry::RULES.each do |event_type, rule_class|
      assert_equal event_type, rule_class.event_type
    end
  end
end
