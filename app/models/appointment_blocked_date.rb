# frozen_string_literal: true

class AppointmentBlockedDate < ApplicationRecord
  include CalendarScoped

  SOURCES = %w[manual imported].freeze
  MAX_SPAN_DAYS = 366

  belongs_to :organization
  calendar_scoped_through :appointment_blocked_date_calendars, join_class: "AppointmentBlockedDateCalendar", foreign_key: :appointment_blocked_date_id

  before_validation :default_end_date

  validates :start_date, :end_date, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :reason, length: { maximum: 255 }, allow_blank: true
  validate :end_date_not_before_start_date
  validate :span_within_limit
  validate :not_a_duplicate

  scope :upcoming, -> { where(end_date: Date.current..).order(:start_date) }
  scope :overlapping, ->(range) { where(start_date: ..range.last, end_date: range.first..) }
  scope :covering, ->(date) { overlapping(date..date) }

  def covers?(date)
    start_date <= date && date <= end_date
  end

  def range
    start_date..end_date
  end

  def single_day?
    start_date == end_date
  end

  private

  def default_end_date
    self.end_date = start_date if end_date.blank?
  end

  def end_date_not_before_start_date
    return unless start_date && end_date

    errors.add(:end_date, "cannot be before the start date") if end_date < start_date
  end

  def span_within_limit
    return unless start_date && end_date && end_date >= start_date

    errors.add(:end_date, "must be within #{MAX_SPAN_DAYS} days of the start date") if (end_date - start_date).to_i > MAX_SPAN_DAYS
  end

  def not_a_duplicate
    return unless organization && start_date && end_date

    duplicate = organization.appointment_blocked_dates
      .where(start_date: start_date, end_date: end_date)
      .where.not(id: id)
      .includes(:calendars)
      .any? { |other| other.calendar_ids.sort == target_calendar_ids.sort }
    errors.add(:start_date, "is already blocked") if duplicate
  end
end
