# frozen_string_literal: true

module Kiosk
  # Stand-in for Appointment during kiosk preview (no DB writes).
  class PreviewAppointment
    def initialize(data)
      @data = data.with_indifferent_access
    end

    def service
      @service ||= OpenStruct.new(display_name: @data[:service_name])
    end

    def formatted_date
      @data[:formatted_date]
    end

    def formatted_time
      @data[:formatted_time]
    end

    def booking_reference
      @data[:booking_reference]
    end
  end
end
