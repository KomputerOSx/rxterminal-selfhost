# frozen_string_literal: true

class UpsellRule < ApplicationRecord
  VISIT_TYPES = %w[any first_visit returning].freeze

  belongs_to :organization
  belongs_to :trigger_service, class_name: "Service"
  belongs_to :suggested_service, class_name: "Service"
  has_many :upsell_counters, dependent: :destroy
  has_many :upsell_templates, dependent: :destroy
  has_many :upsell_interactions, dependent: :destroy

  accepts_nested_attributes_for :upsell_templates, allow_destroy: true, reject_if: :all_blank

  scope :by_priority, -> { order(priority: :desc, id: :asc) }
  scope :not_archived, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :plan_active, -> { where(active: true, archived_at: nil) }
  scope :counting_toward_plan_limit, -> { plan_active }

  validates :name, presence: true
  validates :frequency_type, inclusion: { in: %w[every_nth_customer percentage_based] }
  validates :frequency_value, presence: true, numericality: { greater_than: 0 }
  validates :cooldown_days, numericality: { greater_than_or_equal_to: 0 }
  validates :visit_type, inclusion: { in: VISIT_TYPES }
  validates :active_hours_start, numericality: { in: 0..23, allow_nil: true }
  validates :active_hours_end, numericality: { in: 0..23, allow_nil: true }
  validate :hours_range_valid
  validate :services_belong_to_organization
  validate :trigger_differs_from_suggested
  validate :must_have_template

  private

  def services_belong_to_organization
    [ trigger_service, suggested_service ].compact.each do |service|
      next if service.organization_id == organization_id

      errors.add(:base, "Services must belong to this organization")
      break
    end
  end

  def trigger_differs_from_suggested
    return unless trigger_service_id.present? && suggested_service_id.present?
    return unless trigger_service_id == suggested_service_id

    errors.add(:suggested_service_id, "must differ from the trigger service")
  end

  def must_have_template
    remaining = upsell_templates.reject(&:marked_for_destruction?)
    return if remaining.any?

    errors.add(:base, "At least one presentation template is required")
  end

  def hours_range_valid
    return unless active_hours_start.present? && active_hours_end.present?

    errors.add(:active_hours_end, "must be after start hour") if active_hours_end <= active_hours_start
  end
end
