# frozen_string_literal: true

class Calendar < ApplicationRecord
  belongs_to :organization
  has_many :services, dependent: :nullify
  has_many :appointments, dependent: :restrict_with_error
  has_many :appointment_opening_calendars, dependent: :delete_all
  has_many :appointment_blocked_date_calendars, dependent: :delete_all

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validate :default_cannot_be_archived

  scope :active, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }
  scope :ordered, -> { order(is_default: :desc, name: :asc) }

  before_validation :assign_default_if_first, on: :create

  def archivable?
    !is_default
  end

  def reassign_booking_schedule_to!(target)
    {
      openings: reassign_joins!(appointment_opening_calendars, :appointment_opening_id, target),
      blocked_dates: reassign_joins!(appointment_blocked_date_calendars, :appointment_blocked_date_id, target)
    }
  end

  private

  def reassign_joins!(joins, owner_key, target)
    owner_ids = joins.pluck(owner_key)
    return 0 if owner_ids.empty?

    already_on_target = joins.klass.where(calendar_id: target.id, owner_key => owner_ids).pluck(owner_key)
    joins.where(owner_key => already_on_target).delete_all
    joins.update_all(calendar_id: target.id, updated_at: Time.current)
    owner_ids.size
  end

  def assign_default_if_first
    return unless organization
    return if organization.calendars.where(is_default: true).exists?

    self.is_default = true
  end

  def default_cannot_be_archived
    errors.add(:base, "The default calendar cannot be archived") if is_default && archived
  end
end
