# frozen_string_literal: true

require "test_helper"

class QueueChannelTest < ActionCable::Channel::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "subscribes when user has app.queue.view" do
    stub_connection(current_user: @owner)

    subscribe(organization_id: @organization.id)

    assert subscription.confirmed?
    assert_has_stream "organization_#{@organization.id}_queue"
  end

  test "rejects when user lacks app.queue.view" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    stub_connection(current_user: users(:two))

    subscribe(organization_id: @organization.id)

    assert subscription.rejected?
  end

  test "rejects when organization does not exist" do
    stub_connection(current_user: @owner)

    subscribe(organization_id: 0)

    assert subscription.rejected?
  end

  test "rejects when user is not signed in" do
    stub_connection(current_user: nil)

    subscribe(organization_id: @organization.id)

    assert subscription.rejected?
  end
end
