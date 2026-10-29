# frozen_string_literal: true

class Device < ApplicationRecord
  STATUSES = %w[active inactive revoked].freeze

  belongs_to :organization

  has_secure_password :api_key, validations: false

  validates :device_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :not_deactivated, -> { where(deactivated_at: nil) }
  scope :deactivated, -> { where.not(deactivated_at: nil) }
  scope :operational, -> { not_deactivated.where.not(status: "revoked") }

  def touch_last_seen
    update(last_seen_at: Time.current)
  end

  def active?
    status == "active" && deactivated_at.nil?
  end

  def revoke!
    update!(status: "revoked", token_version: token_version + 1)
  end

  def regenerate_api_key!
    raw_key = SecureRandom.hex(32)
    update!(api_key: raw_key, token_version: token_version + 1)
    raw_key
  end
end
