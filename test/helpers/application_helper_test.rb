# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "searchable_select_data adds controller at default threshold" do
    data = searchable_select_data(option_count: 8)

    assert_includes data[:controller], "searchable-select"
    assert_equal 8, data[:searchable_select_min_options_value]
  end

  test "searchable_select_data skips below default threshold" do
    data = searchable_select_data(option_count: 7)

    assert_nil data[:controller]
  end

  test "searchable_select_data respects force" do
    data = searchable_select_data(option_count: 1, force: true)

    assert_includes data[:controller], "searchable-select"
    assert_equal 8, data[:searchable_select_min_options_value]
  end

  test "service_select_data enables search from two services" do
    data = service_select_data(option_count: 2)

    assert_includes data[:controller], "searchable-select"
    assert_equal ApplicationHelper::SEARCHABLE_SELECT_MIN_SERVICE_OPTIONS,
                 data[:searchable_select_min_options_value]
  end

  test "service_select_data skips for a single service" do
    data = service_select_data(option_count: 1)

    assert_nil data[:controller]
  end

  test "calendar_select_data enables search from four calendars" do
    data = calendar_select_data(option_count: 4)

    assert_includes data[:controller], "searchable-select"
    assert_equal ApplicationHelper::SEARCHABLE_SELECT_MIN_CALENDAR_OPTIONS,
                 data[:searchable_select_min_options_value]
  end

  test "service_options_filter_enabled? uses service threshold" do
    assert service_options_filter_enabled?(2)
    refute service_options_filter_enabled?(1)
  end

  test "options_filter_enabled? keeps default threshold for permissions-scale lists" do
    assert options_filter_enabled?(8)
    refute options_filter_enabled?(7)
  end
end
