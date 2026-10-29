# frozen_string_literal: true

require "test_helper"

class CleanupExpiredSessionsJobTest < ActiveJob::TestCase
  test "cleans up expired sessions" do
    user = users(:one)
    Current.user_agent = "Test"
    Current.ip_address = "127.0.0.1"
    expired = Session.create!(user: user)
    expired.update_column(:expires_at, 1.hour.ago)
    active = Session.create!(user: user, expires_at: 1.hour.from_now)

    CleanupExpiredSessionsJob.perform_now

    refute Session.exists?(expired.id)
    assert Session.exists?(active.id)
  end
end
