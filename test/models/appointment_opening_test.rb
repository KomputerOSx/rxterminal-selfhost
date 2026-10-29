# frozen_string_literal: true

require "test_helper"

class AppointmentOpeningTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2027, 3, 1, 8, 0)
    @organization = Organization.create_personal_for!(users(:one))
  end

  teardown { travel_back }

  test "new openings copy the organization's weekly bookable windows" do
    opening = @organization.appointment_openings.new

    assert_equal @organization.bookable_times, opening.bookable_times
  end

  test "valid opening saves" do
    opening = create_opening!(name: "Flu season")

    assert opening.persisted?
    assert_equal @organization.bookable_times["saturday"], opening.periods_for(Date.new(2027, 3, 6))
    assert_equal [], opening.periods_for(Date.new(2027, 5, 1))
  end

  test "end date cannot be before start date" do
    opening = build_opening(start_date: Date.new(2027, 3, 10), end_date: Date.new(2027, 3, 9))

    assert_not opening.valid?
    assert_includes opening.errors[:end_date], "cannot be before the start date"
  end

  test "end date cannot be in the past" do
    opening = build_opening(start_date: Date.new(2027, 2, 1), end_date: Date.new(2027, 2, 28))

    assert_not opening.valid?
    assert_includes opening.errors[:end_date], "cannot be in the past"
  end

  test "needs at least one bookable day" do
    opening = build_opening(bookable_times: Organization::WEEKDAYS.index_with { [] })

    assert_not opening.valid?
    assert_includes opening.errors[:bookable_times], "must include at least one bookable day"
  end

  test "bookable windows are validated" do
    opening = build_opening(bookable_times: { "monday" => [ { "start" => "15:00", "end" => "14:00" } ] })

    assert_not opening.valid?
    assert_includes opening.errors[:bookable_times], "Monday window 1 must end after it starts"
  end

  test "all calendars openings cannot overlap on a shared weekday" do
    create_opening!(name: "Spring", start_date: Date.new(2027, 3, 1), end_date: Date.new(2027, 3, 31))
    overlapping = build_opening(start_date: Date.new(2027, 3, 31), end_date: Date.new(2027, 4, 30))
    after = build_opening(start_date: Date.new(2027, 4, 1), end_date: Date.new(2027, 4, 30))

    assert_not overlapping.valid?
    assert_match "Overlaps the opening Spring", overlapping.errors[:base].first
    assert after.valid?
  end

  test "openings can be assigned to several calendars" do
    clinic_a = @organization.calendars.create!(name: "Clinic A")
    clinic_b = @organization.calendars.create!(name: "Clinic B")
    opening = build_opening
    opening.assign_calendars(scope: "selected", ids: [ clinic_a.id, clinic_b.id ])
    opening.save!

    assert_equal [ clinic_a.id, clinic_b.id ].sort, opening.reload.calendar_ids.sort
    assert_equal "Clinic A, Clinic B", opening.calendar_label
    assert opening.applies_to?(clinic_a)
    assert_not opening.applies_to?(@organization.calendars.find_by!(is_default: true))
  end

  test "selected calendars must be chosen and belong to the organization" do
    other_org = Organization.create_personal_for!(users(:two))
    none = build_opening.tap { |opening| opening.assign_calendars(scope: "selected", ids: []) }
    foreign = build_opening.tap { |opening| opening.assign_calendars(scope: "selected", ids: [ other_org.calendars.first.id ]) }

    assert_not none.valid?
    assert_includes none.errors[:calendar_ids], "choose at least one calendar"
    assert_not foreign.valid?
    assert_includes foreign.errors[:calendar_ids], "is not valid"
  end

  test "specific openings only clash when they share a calendar and a weekday" do
    clinic_a = @organization.calendars.create!(name: "Clinic A")
    clinic_b = @organization.calendars.create!(name: "Clinic B")
    saturdays = { "saturday" => [ { "start" => "10:00", "end" => "12:00" } ] }
    mondays = { "monday" => [ { "start" => "13:00", "end" => "15:00" } ] }
    create_opening!(name: "Weekend", bookable_times: saturdays, calendar_ids: [ clinic_a.id, clinic_b.id ])

    same_calendar_same_day = build_opening(bookable_times: saturdays, calendar_ids: [ clinic_a.id ])
    same_calendar_other_day = build_opening(bookable_times: mondays, calendar_ids: [ clinic_a.id ])
    other_calendar = build_opening(bookable_times: saturdays, calendar_ids: [ @organization.calendars.create!(name: "Clinic C").id ])
    all_calendars = build_opening(bookable_times: saturdays)

    assert_not same_calendar_same_day.valid?
    assert_match "Overlaps the opening Weekend on Saturday for Clinic A", same_calendar_same_day.errors[:base].first
    assert same_calendar_other_day.valid?
    assert other_calendar.valid?
    assert all_calendars.valid?
  end

  test "an opening that has started can still be edited" do
    opening = create_opening!(start_date: Date.new(2027, 3, 1), end_date: Date.new(2027, 3, 31))
    travel_to Time.zone.local(2027, 3, 15, 8, 0)

    assert opening.update(name: "Renamed")
  end

  private

  def build_opening(**attrs)
    @organization.appointment_openings.new({ start_date: Date.new(2027, 3, 1), end_date: Date.new(2027, 4, 30) }.merge(attrs))
  end

  def create_opening!(**attrs)
    build_opening(**attrs).tap(&:save!)
  end
end
