# frozen_string_literal: true

module Public
  module AppointmentsHelper
    def portal_slot_label(time_string)
      return "" if time_string.blank?

      Time.zone.strptime(time_string, "%H:%M").strftime("%-l:%M%P")
    rescue ArgumentError
      time_string
    end
  end
end
