# frozen_string_literal: true

class AppointmentOpening < ApplicationRecord
  include CalendarScoped

  MAX_SPAN_DAYS = 731

  belongs_to :organization
  calendar_scoped_through :appointment_opening_calendars, join_class: "AppointmentOpeningCalendar", foreign_key: :appointment_opening_id

  after_initialize :default_bookable_times, if: :new_record?

  validates :name, length: { maximum: 100 }, allow_blank: true
  validates :start_date, :end_date, presence: true
  validates :bookable_times, bookable_times: true
  validate :end_date_not_before_start_date
  validate :span_within_limit
  validate :end_date_not_in_past, if: -> { new_record? || will_save_change_to_end_date? }
  validate :has_a_bookable_day
  validate :does_not_overlap_existing_opening

  scope :upcoming, -> { where(end_date: Date.current..).order(:start_date) }
  scope :overlapping, ->(range) { where(start_date: ..range.last, end_date: range.first..) }
  scope :covering, ->(date) { overlapping(date..date) }

  def covers?(date)
    start_date <= date && date <= end_date
  end

  def periods_for(date)
    return [] unless covers?(date)

    Array(bookable_times&.dig(Organization.weekday_key(date)))
  end

  def display_name
    name.presence || "from #{start_date.strftime('%-d %b %Y')}"
  end

  def bookable_days
    Organization::WEEKDAYS.select { |day| Array(bookable_times&.dig(day)).any? }
  end

  private

  def default_bookable_times
    self.bookable_times = organization.bookable_times.deep_dup if bookable_times.blank? && organization
  end

  def end_date_not_before_start_date
    return unless start_date && end_date

    errors.add(:end_date, "cannot be before the start date") if end_date < start_date
  end

  def span_within_limit
    return unless start_date && end_date && end_date >= start_date

    errors.add(:end_date, "must be within 2 years of the start date") if (end_date - start_date).to_i > MAX_SPAN_DAYS
  end

  def end_date_not_in_past
    errors.add(:end_date, "cannot be in the past") if end_date && end_date < Date.current
  end

  def has_a_bookable_day
    errors.add(:bookable_times, "must include at least one bookable day") if bookable_days.empty?
  end

  def does_not_overlap_existing_opening
    return unless organization && start_date && end_date && end_date >= start_date

    candidates = organization.appointment_openings.where.not(id: id).overlapping(start_date..end_date).includes(:calendars)
    candidates.each do |other|
      shared_days = bookable_days & other.bookable_days
      next if shared_days.empty?

      if all_calendars? && other.all_calendars?
        errors.add(:base, "Overlaps the opening #{other.display_name} on #{shared_days.first.capitalize} for all calendars")
        return
      end

      shared_calendar_ids = target_calendar_ids & other.calendar_ids
      next if shared_calendar_ids.empty?

      calendar_name = organization.calendars.find_by(id: shared_calendar_ids.first)&.name
      errors.add(:base, "Overlaps the opening #{other.display_name} on #{shared_days.first.capitalize} for #{calendar_name}")
      return
    end
  end
end
