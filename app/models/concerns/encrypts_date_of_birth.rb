# frozen_string_literal: true

module EncryptsDateOfBirth
  extend ActiveSupport::Concern

  included do
    encrypts :dob, deterministic: true
  end

  def dob
    value = super
    return nil if value.nil?

    value.is_a?(Date) ? value : Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
