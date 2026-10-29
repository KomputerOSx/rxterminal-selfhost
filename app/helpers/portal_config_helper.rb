# frozen_string_literal: true

module PortalConfigHelper
  WEEKDAY_LABELS = Organization::WEEKDAYS.index_with { |day| day.capitalize }.freeze
  MAX_BOOKABLE_PERIODS_PER_DAY = 3

  def weekday_label(day)
    WEEKDAY_LABELS.fetch(day, day.to_s.capitalize)
  end

  def time_field_value(value)
    value.presence
  end

  def day_closed?(hours)
    hours.blank?
  end

  def bookable_periods_for_day(organization, day)
    organization.bookable_times.fetch(day, [])
  end

  def day_bookable_for_appointments?(organization, day)
    bookable_periods_for_day(organization, day).any?
  end
end
