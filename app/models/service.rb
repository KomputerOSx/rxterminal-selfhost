# frozen_string_literal: true

class Service < ApplicationRecord
  belongs_to :organization
  belongs_to :calendar, optional: true
  belongs_to :deleted_by, class_name: "User", optional: true

  has_many :service_requests, dependent: :restrict_with_error
  has_many :appointments, dependent: :restrict_with_error
  has_many :upsell_rules_as_trigger, class_name: "UpsellRule", foreign_key: :trigger_service_id, dependent: :destroy
  has_many :upsell_rules_as_suggestion, class_name: "UpsellRule", foreign_key: :suggested_service_id, dependent: :destroy

  validates :internal_name, :display_name, presence: true
  validates :icon, presence: true, on: :ui_save
  validates :estimated_duration, presence: true, numericality: { greater_than: 0 }
  validates :internal_name,
    uniqueness: { scope: :organization_id, conditions: -> { where(deleted_at: nil) } },
    unless: :deleted?
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :visible, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :not_archived, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :plan_active, -> { visible.not_archived }
  scope :counting_toward_plan_limit, -> { plan_active }
  scope :by_display_order, -> { order(:display_order, :display_name) }
  scope :featured_first, -> { order(featured: :desc, display_order: :asc, display_name: :asc) }
  scope :immediate, -> { where(allows_immediate: true) }
  scope :appointment_only, -> { where(requires_appointment: true, allows_immediate: false) }

  after_initialize { self.eligibility_requirements ||= {} }

  def deleted?
    deleted_at.present?
  end

  def soft_delete!(deleted_by: nil, reason: nil)
    update!(
      active: false,
      deleted_at: Time.current,
      deleted_by: deleted_by,
      delete_reason: reason
    )
  end

  def eligibility_requirements?
    return false if eligibility_requirements.blank?

    requirements = eligibility_requirements
    requirements["eligible"]&.any?(&:present?) ||
      requirements["not_eligible"]&.any?(&:present?) ||
      requirements["additional"]&.any?(&:present?)
  end

  def move_to_calendar!(new_calendar)
    transaction do
      update!(calendar: new_calendar)
      appointments
        .where(status: %w[booked checked_in])
        .where(appointment_date: Date.current..)
        .update_all(calendar_id: new_calendar.id)
    end
  end
end
