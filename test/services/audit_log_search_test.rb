# frozen_string_literal: true

require "test_helper"

class AuditLogSearchTest < ActiveSupport::TestCase
  setup do
    @admin = users(:one)
    @organization = Organization.create_personal_for!(@admin)
  end

  test "filters by event type and organization" do
    matching = AuditLog.create!(
      event_type: :organization_updated,
      resource_type: "Organization",
      resource_id: @organization.id,
      created_at: 1.hour.ago
    )
    AuditLog.create!(event_type: :login_success, created_at: 1.hour.ago)

    result = AuditLogSearch.call(
      ActionController::Parameters.new(
        event_types: [ "organization_updated" ],
        organization_ids: [ @organization.id.to_s ],
        date_from: 2.days.ago.strftime("%Y-%m-%dT%H:%M"),
        date_to: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M")
      )
    )

    assert_includes result.audit_logs.map(&:id), matching.id
    assert_equal 1, result.audit_logs.total_count
  end

  test "filters by partial user email search" do
    log = AuditLog.create!(event_type: :login_success, user: @admin, created_at: 1.hour.ago)

    result = AuditLogSearch.call(
      ActionController::Parameters.new(
        user_search: @admin.email.split("@").first,
        date_from: 2.days.ago.strftime("%Y-%m-%dT%H:%M"),
        date_to: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M")
      )
    )

    assert_includes result.audit_logs.map(&:id), log.id
    assert_equal [ @admin ], result.matched_users
  end

  test "filters by resource type and id" do
    matching = AuditLog.create!(
      event_type: :organization_updated,
      resource_type: "Organization",
      resource_id: @organization.id,
      created_at: 1.hour.ago
    )
    AuditLog.create!(
      event_type: :organization_updated,
      resource_type: "Organization",
      resource_id: @organization.id + 1,
      created_at: 1.hour.ago
    )

    result = AuditLogSearch.call(
      ActionController::Parameters.new(
        resource_type: "Organization",
        resource_id: @organization.id.to_s,
        date_from: 2.days.ago.strftime("%Y-%m-%dT%H:%M"),
        date_to: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M")
      )
    )

    assert_equal [ matching.id ], result.audit_logs.map(&:id)
  end

  test "organization scope always limits results to one organization" do
    matching = AuditLog.create!(
      event_type: :organization_updated,
      resource_type: "Organization",
      resource_id: @organization.id,
      created_at: 1.hour.ago
    )
    other = Organization.create_personal_for!(users(:two))
    AuditLog.create!(
      event_type: :organization_updated,
      resource_type: "Organization",
      resource_id: other.id,
      created_at: 1.hour.ago
    )

    result = AuditLogSearch.call(
      ActionController::Parameters.new(
        date_from: 2.days.ago.strftime("%Y-%m-%dT%H:%M"),
        date_to: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M")
      ),
      organization_id: @organization.id
    )

    assert_equal [ matching.id ], result.audit_logs.map(&:id)
  end
end
