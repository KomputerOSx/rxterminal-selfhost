class OrganizationLogo < ApplicationRecord
  MAX_PER_ORGANIZATION = 3

  belongs_to :organization
  belongs_to :uploaded_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_one_attached :image

  enum :status, { pending: "pending", approved: "approved", declined: "declined" }, default: "pending"

  validates :decline_reason, presence: true, if: :declined?
  validate :organization_within_upload_cap, on: :create

  def approve!(reviewed_by:)
    update!(status: :approved, reviewed_by: reviewed_by, reviewed_at: Time.current, decline_reason: nil)
  end

  def decline!(reviewed_by:, reason:)
    update!(status: :declined, reviewed_by: reviewed_by, reviewed_at: Time.current, decline_reason: reason)
  end

  # Whether this submission's image is the one currently live on the kiosk/portal - derived by
  # comparing blobs rather than an `active` column, so it can never drift out of sync with
  # `organization.kiosk_logo` (see Org::OrganizationLogosController#activate).
  def active?
    return false unless image.attached? && organization.kiosk_logo.attached?

    organization.kiosk_logo.blob_id == image.blob_id
  end

  private

  def organization_within_upload_cap
    return unless organization

    active_count = organization.organization_logos.where(status: %w[pending approved]).where.not(id: id).count
    errors.add(:base, "You can have at most #{MAX_PER_ORGANIZATION} logos pending or approved at a time") if active_count >= MAX_PER_ORGANIZATION
  end
end
