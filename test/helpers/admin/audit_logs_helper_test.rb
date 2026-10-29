# frozen_string_literal: true

require "test_helper"

class AdminAuditLogsHelperTest < ActionView::TestCase
  include Admin::AuditLogsHelper

  test "audit_log_time_ago shows minutes under one hour" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      assert_equal "12 minutes ago", audit_log_time_ago(12.minutes.ago)
    end
  end

  test "audit_log_time_ago shows hours and minutes" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      assert_equal "2 hours 15 minutes ago", audit_log_time_ago(Time.zone.local(2026, 7, 17, 9, 45, 0))
    end
  end

  test "audit_log_time_ago shows hours only when minutes are zero" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      assert_equal "3 hours ago", audit_log_time_ago(Time.zone.local(2026, 7, 17, 9, 0, 0))
    end
  end

  test "audit_log_time_ago shows just now for recent timestamps" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      assert_equal "just now", audit_log_time_ago(30.seconds.ago)
    end
  end

  test "audit_log_time_ago shows yesterday and days" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      assert_equal "yesterday", audit_log_time_ago(Time.zone.local(2026, 7, 16, 12, 0, 0))
      assert_equal "3 days ago", audit_log_time_ago(Time.zone.local(2026, 7, 14, 12, 0, 0))
    end
  end

  test "audit_log_time_ago shows weeks" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      assert_equal "2 weeks ago", audit_log_time_ago(Time.zone.local(2026, 7, 3, 12, 0, 0))
    end
  end

  test "audit_log_time_ago shows months" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      assert_equal "3 months ago", audit_log_time_ago(Time.zone.local(2026, 4, 17, 12, 0, 0))
    end
  end

  test "audit_log_time_ago shows years" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      assert_equal "2 years ago", audit_log_time_ago(Time.zone.local(2024, 7, 17, 12, 0, 0))
      assert_equal "1 year 2 months ago", audit_log_time_ago(Time.zone.local(2025, 5, 17, 12, 0, 0))
    end
  end

  test "audit_log_resource_filter_params drops page" do
    params = audit_log_resource_filter_params(
      AuditLog.new(resource_type: "Organization", resource_id: 3),
      { "page" => "2", "date_from" => "2026-07-10 14:27", "sort" => "created_at" }
    )

    assert_equal({ "date_from" => "2026-07-10 14:27", "sort" => "created_at", resource_type: "Organization", resource_id: 3 }, params)
  end

  test "audit_log_filter_datetime_value normalizes datetime-local params" do
    assert_equal "2026-07-17T14:26", audit_log_filter_datetime_value("2026-07-17T14:26")
  end

  test "audit_log_filter_datetime_value strips duplicated time segments" do
    assert_equal "2026-07-16T22:03", audit_log_filter_datetime_value("2026-07-16 22:03 22:03")
  end
end
