# frozen_string_literal: true

module PiiRedactable
  extend ActiveSupport::Concern

  REDACTED_LABEL = "REDACTED"
  REDACTED_DOB = Date.new(1900, 1, 1)

  def pii_redacted?
    pii_redacted_at.present?
  end

  def redact_pii!
    return true if pii_redacted?

    assign_attributes(redacted_attributes)
    self.pii_redacted_at = Time.current
    save!(validate: false)
  end

  private

  def redacted_attributes
    raise NotImplementedError
  end
end
