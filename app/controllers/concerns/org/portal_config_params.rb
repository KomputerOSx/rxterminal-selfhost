# frozen_string_literal: true

module Org
  module PortalConfigParams
    extend ActiveSupport::Concern

    TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

    private

    def build_operating_hours_from_params
      hours = Current.organization.operating_hours.deep_dup
      raw = params.dig(:organization, :operating_hours).to_unsafe_h

      Organization::WEEKDAYS.each do |day|
        next unless raw.key?(day)

        day_params = raw[day].to_h
        unless ActiveModel::Type::Boolean.new.cast(day_params["open_day"])
          hours[day] = nil
          next
        end

        open_time = day_params["open"].presence
        close_time = day_params["close"].presence
        if open_time.blank? && close_time.blank?
          hours[day] = nil
        else
          hours[day] = { "open" => open_time, "close" => close_time }
        end
      end

      hours
    end

    def build_bookable_times_from_params(scope: :organization, base: Current.organization.bookable_times)
      times = (base || {}).deep_dup
      raw = params.dig(scope, :bookable_times)&.to_unsafe_h || {}

      Organization::WEEKDAYS.each do |day|
        next unless raw.key?(day)

        day_params = raw[day].to_h
        unless ActiveModel::Type::Boolean.new.cast(day_params["bookable_day"])
          times[day] = []
          next
        end

        periods = day_params.filter_map do |key, period|
          next unless key.to_s.match?(/\A\d+\z/)

          start_time = period["start"].presence
          end_time = period["end"].presence
          next if start_time.blank? && end_time.blank?
          next if start_time.blank? || end_time.blank?

          { "start" => start_time, "end" => end_time }
        end

        times[day] = periods
      end

      times
    end

    def appointment_booking_scalar_params
      params.require(:organization).permit(:appointment_days_ahead, :appointment_booking_mode,
        :require_appointment_email, :appointment_email_message)
    end
  end
end
