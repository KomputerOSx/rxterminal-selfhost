# frozen_string_literal: true

module Kiosk
  # Stand-in for ServiceRequest during kiosk preview (no DB writes).
  class PreviewWalkIn
    def initialize(data, organization:)
      @data = data.with_indifferent_access
      @organization = organization
    end

    def first_name
      @data[:first_name]
    end

    def last_name
      @data[:last_name]
    end

    def dob
      value = @data[:dob]
      return value if value.is_a?(Date)
      return if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def postcode
      @data[:postcode]
    end

    def privacy_requested
      ActiveModel::Type::Boolean.new.cast(@data[:privacy_requested])
    end

    def service
      @service ||= @organization.services.find_by(id: @data[:service_id])
    end
  end
end
