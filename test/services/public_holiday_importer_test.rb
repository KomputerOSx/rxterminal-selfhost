# frozen_string_literal: true

require "test_helper"

class PublicHolidayImporterTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2027, 3, 1, 8, 0)
    @organization = Organization.create_personal_for!(users(:one))
  end

  teardown { travel_back }

  test "imports observed England and Wales bank holidays for the next 12 months" do
    result = PublicHolidayImporter.new(@organization, region: "gb_eng").call
    dates = @organization.appointment_blocked_dates.pluck(:start_date)

    assert result.created.positive?
    assert_equal 0, result.skipped
    assert_includes dates, Date.new(2027, 3, 26)
    assert_includes dates, Date.new(2027, 12, 27)
    assert_includes dates, Date.new(2027, 12, 28)
    assert_includes dates, Date.new(2028, 1, 3)
    assert @organization.appointment_blocked_dates.all? { |block| block.source == "imported" && block.reason.present? }
  end

  test "re-importing skips dates that are already blocked" do
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 12, 20), end_date: Date.new(2027, 12, 31), reason: "Christmas closure")
    first = PublicHolidayImporter.new(@organization, region: "gb_eng").call
    second = PublicHolidayImporter.new(@organization, region: "gb_eng").call

    assert_equal 2, first.skipped
    assert_equal 0, second.created
    assert_equal first.created + first.skipped, second.skipped
    assert_not @organization.appointment_blocked_dates.exists?(start_date: Date.new(2027, 12, 27))
  end

  test "imports for selected calendars and skips dates an all calendars block covers" do
    clinic = @organization.calendars.create!(name: "Clinic")
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 12, 27), reason: "Christmas")

    result = PublicHolidayImporter.new(@organization, region: "gb_eng", calendar_ids: [ clinic.id ]).call
    imported = @organization.appointment_blocked_dates.where(source: "imported").includes(:calendars)

    assert_equal 1, result.skipped
    assert imported.all? { |block| block.calendar_ids == [ clinic.id ] }
    assert_not imported.exists?(start_date: Date.new(2027, 12, 27))
  end

  test "rejects calendars from another organization" do
    other_calendar = Organization.create_personal_for!(users(:two)).calendars.first
    importer = PublicHolidayImporter.new(@organization, region: "gb_eng", calendar_ids: [ other_calendar.id ])

    assert_not importer.valid_calendars?
    assert_raises(ArgumentError) { importer.call }
  end

  test "rejects unknown regions" do
    importer = PublicHolidayImporter.new(@organization, region: "atlantis")

    assert_not importer.valid_region?
    assert_raises(ArgumentError) { importer.call }
  end
end
