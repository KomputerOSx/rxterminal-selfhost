# frozen_string_literal: true

class BookingSchedule
  def initialize(organization, calendar: nil)
    @organization = organization
    @calendar = calendar
  end

  def openings_mode?
    @organization.booking_mode_openings?
  end

  def window
    @window ||= begin
      today = Date.current
      if openings_mode?
        last_date = openings_scope.where(end_date: today..).maximum(:end_date)
        today..(last_date || today - 1.day)
      else
        today..(today + @organization.appointment_days_ahead.days)
      end
    end
  end

  def first_bookable_date
    bookable_dates_in(window).min
  end

  def periods_for(date, within_window: true)
    return [] if within_window && !window.cover?(date)
    return [] if blocked_date_for(date)

    weekly_periods_for(date, openings)
  end

  def bookable_date?(date)
    periods_for(date).any?
  end

  def bookable_dates_in(range)
    first = [ range.first, window.first ].max
    last = [ range.last, window.last ].min
    return Set.new if first > last

    dates = first..last
    blocks = blocked_dates_scope.overlapping(dates).to_a
    range_openings = openings_mode? ? openings_scope.overlapping(dates).includes(:calendars).to_a : nil
    dates.select do |date|
      blocks.none? { |block| block.covers?(date) } && weekly_periods_for(date, range_openings).any?
    end.to_set
  end

  def closures_in(range)
    blocked_dates_scope.overlapping(range).order(:start_date).each_with_object({}) do |block, closures|
      ([ block.start_date, range.first ].max..[ block.end_date, range.last ].min).each do |date|
        closures[date] ||= block.reason.presence || "Closed"
      end
    end
  end

  def blocked_date_for(date)
    blocked_dates.find { |block| block.covers?(date) }
  end

  def time_bookable?(date, start_minutes, duration_minutes, within_window: true)
    periods_for(date, within_window: within_window).any? do |period|
      start_minutes >= minutes(period["start"]) && start_minutes + duration_minutes <= minutes(period["end"])
    end
  end

  def self.conflicting_appointments(organization, dates: nil)
    scope = organization.appointments.active.includes(:service, :calendar)
      .where(appointment_date: dates || (Date.current..))
      .order(:appointment_date, :appointment_time)
    schedules = {}

    scope.reject do |appointment|
      calendar = appointment.calendar || appointment.service&.calendar
      schedule = schedules[calendar&.id] ||= new(organization, calendar: calendar)
      start_minutes = appointment.appointment_time.hour * 60 + appointment.appointment_time.min
      schedule.time_bookable?(appointment.appointment_date, start_minutes, appointment.service.estimated_duration, within_window: false)
    end
  end

  private

  def openings_scope
    @organization.appointment_openings.for_calendar(@calendar)
  end

  def blocked_dates_scope
    @organization.appointment_blocked_dates.for_calendar(@calendar)
  end

  def openings
    @openings ||= openings_scope.where(end_date: Date.current..).includes(:calendars).to_a
  end

  def weekly_periods_for(date, candidate_openings)
    return Array(@organization.bookable_times&.dig(Organization.weekday_key(date))) unless openings_mode?

    covering = candidate_openings.select { |opening| opening.periods_for(date).any? }
    specific = covering.select { |opening| opening.specifically_for?(@calendar) }
    chosen = specific.any? ? specific : covering.select(&:all_calendars?)

    merge_periods(chosen.flat_map do |opening|
      opening.periods_for(date).map { |period| [ minutes(period["start"]), minutes(period["end"]) ] }
    end)
  end

  def blocked_dates
    @blocked_dates ||= blocked_dates_scope.where(end_date: Date.current..).to_a
  end

  def merge_periods(intervals)
    intervals.sort.each_with_object([]) do |(start_min, end_min), merged|
      if merged.any? && start_min <= merged.last[1]
        merged.last[1] = [ merged.last[1], end_min ].max
      else
        merged << [ start_min, end_min ]
      end
    end.map { |start_min, end_min| { "start" => format_minutes(start_min), "end" => format_minutes(end_min) } }
  end

  def minutes(value)
    hour, minute = value.to_s.split(":").map(&:to_i)
    hour * 60 + minute
  end

  def format_minutes(total)
    format("%02d:%02d", total / 60, total % 60)
  end
end
