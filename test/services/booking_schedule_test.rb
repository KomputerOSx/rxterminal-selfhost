# frozen_string_literal: true

require "test_helper"

class BookingScheduleTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2027, 3, 1, 8, 0)
    @organization = Organization.create_personal_for!(users(:one))
    @calendar = @organization.calendars.find_by!(is_default: true)
    @other_calendar = @organization.calendars.create!(name: "Clinic")
    @service = @organization.services.create!(
      internal_name: "schedule_svc", display_name: "Schedule Service", estimated_duration: 30,
      requires_appointment: true, active: true, calendar: @calendar
    )
    @organization.update!(appointment_days_ahead: 14)
  end

  teardown { travel_back }

  test "rolling mode uses the weekly bookable windows inside the booking window" do
    schedule = BookingSchedule.new(@organization, calendar: @calendar)

    assert_equal Date.new(2027, 3, 1)..Date.new(2027, 3, 15), schedule.window
    assert_equal @organization.bookable_times["tuesday"], schedule.periods_for(Date.new(2027, 3, 2))
    assert_equal [], schedule.periods_for(Date.new(2027, 3, 7))
    assert_equal [], schedule.periods_for(Date.new(2027, 3, 16))
  end

  test "blocked dates remove whole days and ranges in rolling mode" do
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 3), reason: "Training")
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 8), end_date: Date.new(2027, 3, 10))
    schedule = BookingSchedule.new(@organization, calendar: @calendar)

    assert_equal [], schedule.periods_for(Date.new(2027, 3, 3))
    assert_equal [], schedule.periods_for(Date.new(2027, 3, 9))
    assert schedule.bookable_date?(Date.new(2027, 3, 4))
    assert_equal "Training", schedule.blocked_date_for(Date.new(2027, 3, 3)).reason
  end

  test "calendar specific blocked dates only affect that calendar" do
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 3), calendar_ids: [ @other_calendar.id ])

    assert BookingSchedule.new(@organization, calendar: @calendar).bookable_date?(Date.new(2027, 3, 3))
    assert_not BookingSchedule.new(@organization, calendar: @other_calendar).bookable_date?(Date.new(2027, 3, 3))
  end

  test "bookable_dates_in skips closed weekdays, blocked dates and dates outside the window" do
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 3))
    dates = BookingSchedule.new(@organization, calendar: @calendar).bookable_dates_in(Date.new(2027, 3, 1)..Date.new(2027, 3, 31))

    assert_includes dates, Date.new(2027, 3, 2)
    assert_not_includes dates, Date.new(2027, 3, 3)
    assert_not_includes dates, Date.new(2027, 3, 7)
    assert_not_includes dates, Date.new(2027, 3, 16)
  end

  test "closures_in maps blocked dates to their reasons" do
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 3), end_date: Date.new(2027, 3, 4), reason: "Refit")
    closures = BookingSchedule.new(@organization).closures_in(Date.new(2027, 3, 1)..Date.new(2027, 3, 31))

    assert_equal({ Date.new(2027, 3, 3) => "Refit", Date.new(2027, 3, 4) => "Refit" }, closures)
  end

  test "openings mode replaces the booking window with openings and their own weekly windows" do
    @organization.update!(appointment_booking_mode: "openings")
    @organization.appointment_openings.create!(
      start_date: Date.new(2027, 3, 20), end_date: Date.new(2027, 4, 30),
      bookable_times: { "saturday" => [ { "start" => "10:00", "end" => "12:00" } ] }
    )
    @organization.appointment_openings.create!(
      start_date: Date.new(2027, 3, 20), end_date: Date.new(2027, 3, 27), calendar_ids: [ @calendar.id ],
      bookable_times: { "saturday" => [ { "start" => "11:00", "end" => "13:00" } ], "monday" => [ { "start" => "09:00", "end" => "10:00" } ] }
    )
    @organization.appointment_openings.create!(
      start_date: Date.new(2027, 3, 1), end_date: Date.new(2027, 3, 10), calendar_ids: [ @other_calendar.id ],
      bookable_times: { "tuesday" => [ { "start" => "09:00", "end" => "10:00" } ] }
    )
    schedule = BookingSchedule.new(@organization, calendar: @calendar)

    assert_equal Date.new(2027, 3, 1)..Date.new(2027, 4, 30), schedule.window
    assert_equal [ { "start" => "11:00", "end" => "13:00" } ], schedule.periods_for(Date.new(2027, 3, 20))
    assert_equal [ { "start" => "10:00", "end" => "12:00" } ], schedule.periods_for(Date.new(2027, 4, 3))
    assert_equal [ { "start" => "09:00", "end" => "10:00" } ], schedule.periods_for(Date.new(2027, 3, 22))
    assert_equal [], schedule.periods_for(Date.new(2027, 3, 2))
    assert_equal Date.new(2027, 3, 20), schedule.first_bookable_date
    assert_includes schedule.bookable_dates_in(Date.new(2027, 4, 1)..Date.new(2027, 4, 30)), Date.new(2027, 4, 24)
    assert_not_includes schedule.bookable_dates_in(Date.new(2027, 4, 1)..Date.new(2027, 4, 30)), Date.new(2027, 4, 26)
  end

  test "a calendar's own opening overrides all calendars openings only on its weekdays" do
    @organization.update!(appointment_booking_mode: "openings")
    clinic_a = @organization.calendars.create!(name: "Clinic A")
    clinic_b = @organization.calendars.create!(name: "Clinic B")
    weekdays = %w[monday tuesday wednesday thursday friday].index_with { [ { "start" => "09:00", "end" => "17:00" } ] }
    @organization.appointment_openings.create!(start_date: Date.new(2027, 3, 1), end_date: Date.new(2027, 3, 31), bookable_times: weekdays)
    @organization.appointment_openings.create!(
      start_date: Date.new(2027, 3, 1), end_date: Date.new(2027, 3, 31), calendar_ids: [ clinic_a.id, clinic_b.id ],
      bookable_times: { "saturday" => [ { "start" => "10:00", "end" => "12:00" } ] }
    )
    @organization.appointment_openings.create!(
      start_date: Date.new(2027, 3, 1), end_date: Date.new(2027, 3, 31), calendar_ids: [ clinic_a.id ],
      bookable_times: { "monday" => [ { "start" => "13:00", "end" => "15:00" } ] }
    )
    clinic_a_schedule = BookingSchedule.new(@organization, calendar: clinic_a)
    clinic_b_schedule = BookingSchedule.new(@organization, calendar: clinic_b)
    default_schedule = BookingSchedule.new(@organization, calendar: @calendar)
    monday = Date.new(2027, 3, 8)
    tuesday = Date.new(2027, 3, 9)
    saturday = Date.new(2027, 3, 13)

    assert_equal [ { "start" => "13:00", "end" => "15:00" } ], clinic_a_schedule.periods_for(monday)
    assert_equal [ { "start" => "09:00", "end" => "17:00" } ], clinic_a_schedule.periods_for(tuesday)
    assert_equal [ { "start" => "10:00", "end" => "12:00" } ], clinic_a_schedule.periods_for(saturday)
    assert_equal [ { "start" => "09:00", "end" => "17:00" } ], clinic_b_schedule.periods_for(monday)
    assert_equal [ { "start" => "10:00", "end" => "12:00" } ], clinic_b_schedule.periods_for(saturday)
    assert_equal [ { "start" => "09:00", "end" => "17:00" } ], default_schedule.periods_for(monday)
    assert_equal [], default_schedule.periods_for(saturday)
  end

  test "blocked dates also apply inside openings" do
    @organization.update!(appointment_booking_mode: "openings")
    @organization.appointment_openings.create!(start_date: Date.new(2027, 3, 1), end_date: Date.new(2027, 3, 31))
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 2), reason: "Training")
    schedule = BookingSchedule.new(@organization, calendar: @calendar)

    assert_equal [], schedule.periods_for(Date.new(2027, 3, 2))
    assert schedule.bookable_date?(Date.new(2027, 3, 3))
    assert_equal({ Date.new(2027, 3, 2) => "Training" }, schedule.closures_in(Date.new(2027, 3, 1)..Date.new(2027, 3, 31)))
  end

  test "openings mode with no openings has an empty window" do
    @organization.update!(appointment_booking_mode: "openings")
    schedule = BookingSchedule.new(@organization)

    assert_nil schedule.first_bookable_date
    assert_empty schedule.bookable_dates_in(Date.new(2027, 3, 1)..Date.new(2027, 3, 31))
  end

  test "time_bookable requires the whole booking to fit in a window" do
    schedule = BookingSchedule.new(@organization, calendar: @calendar)
    tuesday = Date.new(2027, 3, 2)

    assert schedule.time_bookable?(tuesday, 12 * 60 + 30, 30)
    assert_not schedule.time_bookable?(tuesday, 12 * 60 + 45, 30)
  end

  test "conflicting_appointments lists booked appointments that no longer fit" do
    fitting = book!(Date.new(2027, 3, 2), "10:00")
    blocked = book!(Date.new(2027, 3, 4), "10:00")
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 4))

    conflicts = BookingSchedule.conflicting_appointments(@organization)

    assert_includes conflicts, blocked
    assert_not_includes conflicts, fitting
    assert blocked.reload.status == "booked"
  end

  private

  def book!(date, time)
    Appointment.create!(
      organization: @organization, service: @service, first_name: "JANE", last_name: "DOE",
      dob: Date.new(1990, 1, 1), postcode: "N1 1AA", appointment_date: date,
      appointment_time: Time.zone.parse(time), status: "booked"
    )
  end
end
