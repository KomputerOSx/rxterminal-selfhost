# frozen_string_literal: true

class SlotAvailabilityService
  def initialize(organization, service, date, exclude_appointment_id: nil)
    @organization = organization
    @service = service
    @date = date
    @exclude_appointment_id = exclude_appointment_id
  end

  def available_slots
    calendar = @service.calendar
    periods = BookingSchedule.new(@organization, calendar: calendar).periods_for(@date)
    return [] if periods.empty?

    slot_minutes = @service.estimated_duration
    sibling_service_ids = calendar ? calendar.services.pluck(:id) : [ @service.id ]

    booked_scope = Appointment.active.for_date(@date).where(service_id: sibling_service_ids)
    booked_scope = booked_scope.where.not(id: @exclude_appointment_id) if @exclude_appointment_id.present?

    booked_intervals = booked_scope.joins(:service)
      .pluck("appointments.appointment_time", "services.estimated_duration")
      .map do |time, duration|
        start_min = time.hour * 60 + time.min
        [ start_min, start_min + (duration || slot_minutes) ]
      end

    now_min = if @date == Date.current
      now = Time.current
      now.hour * 60 + now.min
    end

    slots = []
    periods.each do |period|
      slot_start = minutes(period["start"])
      period_end = minutes(period["end"])
      while slot_start + slot_minutes <= period_end
        unless now_min && slot_start <= now_min
          slot_end = slot_start + slot_minutes
          available = booked_intervals.none? { |b_start, b_end| slot_start < b_end && b_start < slot_end }
          slots << { time: format("%02d:%02d", slot_start / 60, slot_start % 60), available: available }
        end
        slot_start += slot_minutes
      end
    end
    slots
  end

  private

  def minutes(value)
    hour, minute = value.to_s.split(":").map(&:to_i)
    hour * 60 + minute
  end
end
