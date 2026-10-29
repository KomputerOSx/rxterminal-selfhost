# frozen_string_literal: true

class BookableTimesValidator < ActiveModel::EachValidator
  TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  def validate_each(record, attribute, value)
    return if value.blank?

    value.each do |day, periods|
      unless Organization::WEEKDAYS.include?(day)
        record.errors.add(attribute, "includes unknown day #{day}")
        next
      end

      unless periods.is_a?(Array)
        record.errors.add(attribute, "#{day} must be a list of booking windows")
        next
      end

      periods.each_with_index { |period, index| validate_period(record, attribute, day, period, index) }
    end
  end

  private

  def validate_period(record, attribute, day, period, index)
    label = "#{day.capitalize} window #{index + 1}"
    unless period.is_a?(Hash)
      record.errors.add(attribute, "#{label} is invalid")
      return
    end

    start_time = period["start"]
    end_time = period["end"]
    invalid_format = false
    { "start" => start_time, "end" => end_time }.each do |edge, time|
      next if time.blank? || time.match?(TIME_FORMAT)

      record.errors.add(attribute, "#{label} #{edge} must use HH:MM format")
      invalid_format = true
    end

    return if invalid_format || start_time.blank? || end_time.blank?

    record.errors.add(attribute, "#{label} must end after it starts") if minutes(start_time) >= minutes(end_time)
  end

  def minutes(value)
    hour, minute = value.split(":").map(&:to_i)
    hour * 60 + minute
  end
end
