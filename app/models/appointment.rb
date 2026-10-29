# frozen_string_literal: true

class Appointment < ApplicationRecord
  include EncryptsDateOfBirth
  include PiiRedactable

  STATUSES = %w[booked checked_in cancelled no_show].freeze
  BOOKING_REF_CHARS = (("A".."Z").to_a - %w[I O]) + ("0".."9").to_a

  belongs_to :organization
  belongs_to :service
  belongs_to :calendar, optional: true
  belongs_to :service_request, optional: true

  encrypts :first_name
  encrypts :last_name
  encrypts :postcode
  encrypts :email
  encrypts :notes
  encrypts :cancellation_reason

  CANCELLATION_REASON_MAX_LENGTH = 500

  validates :first_name, :last_name, presence: true
  validates :dob, presence: true, unless: :dob_collection_optional?
  validates :postcode, presence: true, unless: :postcode_collection_optional?
  validates :booking_reference, presence: true, uniqueness: true
  validates :appointment_date, :appointment_time, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, presence: true, if: :email_collection_required?
  validates :cancellation_reason, length: { maximum: CANCELLATION_REASON_MAX_LENGTH }, allow_blank: true
  validate :appointment_slot_available, if: :slot_booking_details_present?
  validate :appointment_on_booking_schedule, if: :booking_schedule_check_needed?

  before_validation :generate_booking_reference, on: :create
  before_validation :assign_calendar_from_service

  scope :not_redacted, -> { where(pii_redacted_at: nil) }
  scope :active, -> { where(status: "booked") }
  scope :for_date, ->(date) { where(appointment_date: date) }
  scope :upcoming, -> { where(appointment_date: Date.current..).order(:appointment_date, :appointment_time) }
  scope :by_time, -> { order(:appointment_time) }
  scope :today, -> { for_date(Date.current) }

  def past_due?
    appointment_date < Date.current ||
      (appointment_date == Date.current && appointment_time.present? &&
       appointment_time.strftime("%H:%M") < Time.current.strftime("%H:%M"))
  end

  # submission_ip is only ever passed by the public, unauthenticated check-in flow
  # (Public::AppointmentCheckinsController). Staff/kiosk check-ins (Org::AppointmentsController,
  # Kiosk::AppointmentsController) call this with no args.
  def check_in!(submission_ip: nil)
    transaction do
      queue_number = ServiceRequest.next_queue_number_for(organization, queue_date: Date.current)

      service_request = ServiceRequest.create!(
        organization: organization,
        service: service,
        first_name: first_name,
        last_name: last_name,
        dob: dob,
        postcode: postcode,
        status: "waiting",
        request_type: "appointment",
        queue_number: queue_number,
        queue_date: Date.current,
        submission_ip: submission_ip
      )

      update!(
        service_request: service_request,
        status: "checked_in",
        checked_in_at: Time.current
      )

      service_request
    end
  end

  class RevertNotAllowedError < StandardError; end

  def revert_to_booked!
    transaction do
      if service_request
        case service_request.status
        when "waiting"
          service_request.cancel!
        when "cancelled"
          # already inactive in the queue - nothing to unwind, just detach it below
        else
          raise RevertNotAllowedError,
            "Can't return to booked - the queue entry is #{service_request.status.humanize.downcase}. " \
            "Update it from the Queue screen first."
        end
      end

      update!(status: "booked", checked_in_at: nil, service_request: nil)
    end
  end

  def cancel!(reason: nil)
    update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: reason.to_s.strip.first(CANCELLATION_REASON_MAX_LENGTH).presence)
  end

  def mark_no_show!
    update!(status: "no_show", no_show_at: Time.current)
  end

  def formatted_time
    appointment_time.strftime("%-I:%M %p") if appointment_time
  end

  def formatted_date
    appointment_date.strftime("%A, %d %B %Y") if appointment_date
  end

  def editable_by_staff?
    !status.in?(%w[cancelled no_show])
  end

  def save_with_slot_protection
    with_slot_lock { save }
  end

  def update_with_slot_protection(attributes)
    assign_attributes(attributes)
    with_slot_lock { save }
  end

  private

  def postcode_collection_optional?
    organization.kiosk_collect_postcode == false
  end

  def dob_collection_optional?
    organization.kiosk_collect_dob == false
  end

  def email_collection_required?
    organization&.require_appointment_email? && (new_record? || will_save_change_to_email?)
  end

  def redacted_attributes
    {
      first_name: REDACTED_LABEL,
      last_name: REDACTED_LABEL,
      postcode: nil,
      email: nil,
      notes: nil,
      cancellation_reason: nil,
      dob: REDACTED_DOB
    }
  end

  def assign_calendar_from_service
    self.calendar_id = service&.calendar_id
  end

  def generate_booking_reference
    return if booking_reference.present?

    loop do
      self.booking_reference = Array.new(6) { BOOKING_REF_CHARS.sample }.join
      break unless Appointment.exists?(booking_reference: booking_reference)
    end
  end

  def slot_booking_details_present?
    organization.present? && service.present? && appointment_date.present? &&
      appointment_time.present? && status == "booked"
  end

  def appointment_slot_available
    return if slot_conflict.nil?

    errors.add(:appointment_time, "is no longer available")
  end

  def booking_schedule_check_needed?
    return false unless organization.present? && appointment_date.present? && status == "booked"

    new_record? || will_save_change_to_appointment_date? || will_save_change_to_appointment_time? ||
      will_save_change_to_service_id?
  end

  def appointment_on_booking_schedule
    if appointment_date < Date.current
      errors.add(:appointment_date, "cannot be in the past")
      return
    end

    schedule = organization.booking_schedule(calendar: calendar || service&.calendar)

    if (blocked = schedule.blocked_date_for(appointment_date))
      errors.add(:appointment_date, "is not available (#{blocked.reason.presence || 'closed'})")
    elsif schedule.openings_mode?
      if schedule.periods_for(appointment_date).empty?
        errors.add(:appointment_date, "is not within an opening")
      elsif appointment_time.present? && service.present? &&
          !schedule.time_bookable?(appointment_date, appointment_time.hour * 60 + appointment_time.min, service.estimated_duration)
        errors.add(:appointment_time, "is outside the opening's bookable windows")
      end
    elsif appointment_date > schedule.window.last
      errors.add(:appointment_date, "must be within #{organization.appointment_days_ahead} days")
    end
  end

  def slot_conflict
    sibling_service_ids = blocking_service_ids
    return nil if sibling_service_ids.empty?

    requested_start = appointment_time.hour * 60 + appointment_time.min
    requested_end = requested_start + slot_duration_minutes(service)

    Appointment.active
      .for_date(appointment_date)
      .where(organization_id: organization_id, service_id: sibling_service_ids)
      .where.not(id: id)
      .joins(:service)
      .detect do |appointment|
        appointment_start = appointment.appointment_time.hour * 60 + appointment.appointment_time.min
        appointment_end = appointment_start + slot_duration_minutes(appointment.service)
        requested_start < appointment_end && appointment_start < requested_end
      end
  end

  def blocking_service_ids
    active_calendar = calendar || service&.calendar
    if active_calendar
      active_calendar.services.pluck(:id)
    elsif service_id.present?
      [ service_id ]
    else
      []
    end
  end

  def slot_duration_minutes(target_service)
    target_service.estimated_duration
  end

  def with_slot_lock
    lock_target = calendar || service&.calendar || organization
    return yield if lock_target.nil?

    lock_target.with_lock { yield }
  end
end
