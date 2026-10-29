# frozen_string_literal: true

class ServiceRequest < ApplicationRecord
  include EncryptsDateOfBirth
  include PiiRedactable
  include QueueBroadcasting

  STATUSES = %w[waiting in_progress completed cancelled].freeze
  REQUEST_TYPES = %w[immediate appointment].freeze

  belongs_to :organization
  belongs_to :service
  has_one :appointment, dependent: :nullify

  encrypts :first_name
  encrypts :last_name
  encrypts :postcode
  encrypts :description

  validates :first_name, :last_name, :queue_number, presence: true
  validates :dob, presence: true, unless: :dob_collection_optional?
  validates :postcode, presence: true, unless: :postcode_collection_optional?, on: :create
  validates :status, inclusion: { in: STATUSES }
  validates :request_type, inclusion: { in: REQUEST_TYPES }
  validates :queue_number, uniqueness: { scope: [ :organization_id, :queue_date ] }
  validates :queue_date, presence: true
  validates :previous_status, inclusion: { in: STATUSES }, allow_nil: true

  before_validation :set_queue_date, on: :create
  before_validation :assign_queue_number, on: :create
  before_update :store_previous_status, if: :will_save_change_to_status?

  scope :not_redacted, -> { where(pii_redacted_at: nil) }
  scope :active_queue, -> { where(status: %w[waiting in_progress]) }
  scope :for_services, ->(ids) { where(service_id: ids) if ids.present? }
  scope :today, -> { where(created_at: Date.current.all_day) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_queue_number, -> { order(:queue_number) }
  scope :by_request_type, ->(request_type) { where(request_type: request_type) if request_type.present? }
  scope :in_calendar_month, ->(time = Time.current) {
    where(created_at: time.beginning_of_month..time.end_of_month)
  }
  scope :date_range, ->(start_date, end_date) {
    return all if start_date.blank? && end_date.blank?

    if start_date.present? && end_date.present?
      where(created_at: start_date.to_date.beginning_of_day..end_date.to_date.end_of_day)
    elsif start_date.present?
      where(created_at: start_date.to_date.beginning_of_day..)
    elsif end_date.present?
      where(created_at: ..end_date.to_date.end_of_day)
    end
  }

  def self.next_queue_number_for(organization, queue_date: Date.current)
    organization.with_lock do
      existing = where(organization: organization, queue_date: queue_date).pluck(:queue_number).map(&:to_i)
      (existing.any? ? existing.max + 1 : 1).to_s
    end
  end

  def self.average_wait_minutes(organization_id, since: nil)
    scope = where(organization_id: organization_id, status: "completed", queue_date: Date.current)
              .where.not(completed_at: nil)
    scope = scope.where(completed_at: since..) if since

    pairs = scope.pluck(:created_at, :completed_at)
    return nil if pairs.empty?

    avg_seconds = pairs.sum { |created_at, completed_at| completed_at - created_at } / pairs.size.to_f
    (avg_seconds / 60.0).round
  end

  def call!
    update!(status: "in_progress", called_at: Time.current)
  end

  def complete!
    update!(status: "completed", completed_at: Time.current)
  end

  def cancel!
    update!(status: "cancelled")
  end

  def revert_to_waiting!
    update!(status: "waiting", called_at: nil)
  end

  def revert_from_completed!
    update!(
      status: previous_status || "waiting",
      called_at: previous_called_at,
      completed_at: nil
    )
  end

  private

  def redacted_attributes
    {
      first_name: REDACTED_LABEL,
      last_name: REDACTED_LABEL,
      postcode: nil,
      description: nil,
      dob: REDACTED_DOB,
      submission_ip: nil
    }
  end

  def postcode_collection_optional?
    organization.kiosk_collect_postcode == false
  end

  def dob_collection_optional?
    organization.kiosk_collect_dob == false
  end

  def set_queue_date
    self.queue_date ||= Date.current
  end

  def assign_queue_number
    return if queue_number.present?

    self.queue_number = self.class.next_queue_number_for(organization, queue_date: queue_date)
  end

  def store_previous_status
    self.previous_status = status_was
    self.previous_called_at = called_at_was if status_was == "in_progress"
  end
end
