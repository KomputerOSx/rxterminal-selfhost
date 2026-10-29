require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "notification_channel_enabled? defaults to true for an optional category" do
    assert users(:one).notification_channel_enabled?("membership", "email")
    assert users(:one).notification_channel_enabled?("membership", "in_app")
  end

  test "disable_notification_channel! turns off just the given category/channel pair" do
    users(:one).disable_notification_channel!("membership", "email")

    assert_not users(:one).notification_channel_enabled?("membership", "email")
    assert users(:one).notification_channel_enabled?("membership", "in_app")
    assert users(:one).notification_channel_enabled?("billing", "email")
  end

  test "enable_notification_channel! clears a prior opt-out" do
    users(:one).disable_notification_channel!("membership", "email")
    users(:one).enable_notification_channel!("membership", "email")

    assert users(:one).notification_channel_enabled?("membership", "email")
  end

  test "always_on categories ignore preferences entirely" do
    users(:one).disable_notification_channel!("security", "email")

    assert users(:one).notification_channel_enabled?("security", "email")
  end

  test "remember_device! returns false and records the agent on the first-ever call" do
    assert_not users(:one).remember_device!("AgentOne")
    assert_equal [ "AgentOne" ], users(:one).reload.known_user_agents
  end

  test "remember_device! returns false for an already-known agent" do
    users(:one).remember_device!("AgentOne")

    assert_not users(:one).remember_device!("AgentOne")
    assert_equal [ "AgentOne" ], users(:one).reload.known_user_agents
  end

  test "remember_device! returns true and records a new agent once one is already known" do
    users(:one).remember_device!("AgentOne")

    assert users(:one).remember_device!("AgentTwo")
    assert_equal [ "AgentOne", "AgentTwo" ], users(:one).reload.known_user_agents
  end

  test "remember_device! is a no-op for a blank agent" do
    assert_not users(:one).remember_device!(nil)
    assert_empty users(:one).reload.known_user_agents
  end

  test "remember_device! caps the remembered list at 10 agents" do
    10.times { |i| users(:one).remember_device!("Agent#{i}") }

    assert users(:one).remember_device!("Agent10")
    agents = users(:one).reload.known_user_agents
    assert_equal 10, agents.size
    assert_equal "Agent10", agents.last
    assert_not_includes agents, "Agent0"
  end

  test "has_permission? without an organization only checks system-scope roles" do
    organization = Organization.create!(name: "Acme", slug: "acme")
    membership = organization.memberships.create!(user: users(:one))
    custom_role = Role.create!(scope: :app, name: "custom_role")
    permission = Permission.create!(key: "app.custom.manage")
    RolePermission.create!(role: custom_role, permission: permission)
    membership.grant_role!(custom_role)

    assert_not users(:one).has_permission?("app.custom.manage")
  end

  test "has_permission? with an organization delegates to that membership" do
    organization = Organization.create!(name: "Acme", slug: "acme")
    membership = organization.memberships.create!(user: users(:one))
    custom_role = Role.create!(scope: :app, name: "custom_role")
    permission = Permission.create!(key: "app.custom.manage")
    RolePermission.create!(role: custom_role, permission: permission)

    assert_not users(:one).has_permission?("app.custom.manage", organization: organization)

    membership.grant_role!(custom_role)

    assert users(:one).has_permission?("app.custom.manage", organization: organization)
  end

  test "has_permission? with an organization the user isn't a member of returns false" do
    organization = Organization.create!(name: "Acme", slug: "acme")

    assert_not users(:one).has_permission?("app.custom.manage", organization: organization)
  end
end
