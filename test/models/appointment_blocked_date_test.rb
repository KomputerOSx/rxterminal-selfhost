# frozen_string_literal: true

require "test_helper"

class AppointmentBlockedDateTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2027, 3, 1, 8, 0)
    @organization = Organization.create_personal_for!(users(:one))
  end

  teardown { travel_back }

  test "end date defaults to start date" do
    block = @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 5), reason: "Training")

    assert_equal Date.new(2027, 3, 5), block.end_date
    assert block.single_day?
  end

  test "end date cannot be before start date" do
    block = @organization.appointment_blocked_dates.build(start_date: Date.new(2027, 3, 5), end_date: Date.new(2027, 3, 4))

    assert_not block.valid?
    assert_includes block.errors[:end_date], "cannot be before the start date"
  end

  test "span is limited" do
    block = @organization.appointment_blocked_dates.build(start_date: Date.new(2027, 3, 5), end_date: Date.new(2028, 6, 1))

    assert_not block.valid?
    assert block.errors[:end_date].any?
  end

  test "the same range cannot be blocked twice for the same calendars" do
    clinic = @organization.calendars.create!(name: "Clinic")
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 5))
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 6), calendar_ids: [ clinic.id ])
    duplicate_all = @organization.appointment_blocked_dates.build(start_date: Date.new(2027, 3, 5))
    duplicate_clinic = @organization.appointment_blocked_dates.build(start_date: Date.new(2027, 3, 6), calendar_ids: [ clinic.id ])
    clinic_only = @organization.appointment_blocked_dates.build(start_date: Date.new(2027, 3, 5), calendar_ids: [ clinic.id ])

    assert_not duplicate_all.valid?
    assert_includes duplicate_all.errors[:start_date], "is already blocked"
    assert_not duplicate_clinic.valid?
    assert clinic_only.valid?
  end

  test "for_calendar includes all calendars blocks and blocks for that calendar" do
    clinic = @organization.calendars.create!(name: "Clinic")
    other = @organization.calendars.create!(name: "Other")
    all = @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 5))
    mine = @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 6), calendar_ids: [ clinic.id, other.id ])
    theirs = @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 7), calendar_ids: [ other.id ])

    scoped = @organization.appointment_blocked_dates.for_calendar(clinic)

    assert_includes scoped, all
    assert_includes scoped, mine
    assert_not_includes scoped, theirs
    assert_equal [ all ], @organization.appointment_blocked_dates.for_calendar(nil).to_a
  end

  test "source must be known" do
    block = @organization.appointment_blocked_dates.build(start_date: Date.new(2027, 3, 5), source: "robot")

    assert_not block.valid?
  end

  test "covering and overlapping scopes" do
    range_block = @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 10), end_date: Date.new(2027, 3, 12))

    assert_includes @organization.appointment_blocked_dates.covering(Date.new(2027, 3, 11)), range_block
    assert_not_includes @organization.appointment_blocked_dates.covering(Date.new(2027, 3, 13)), range_block
    assert_includes @organization.appointment_blocked_dates.overlapping(Date.new(2027, 3, 12)..Date.new(2027, 3, 20)), range_block
  end
end
