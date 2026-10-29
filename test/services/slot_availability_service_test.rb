# frozen_string_literal: true

require "test_helper"

class SlotAvailabilityServiceTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2027, 3, 1, 8, 0)
    @organization = Organization.create_personal_for!(users(:one))
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "slot_svc", display_name: "Slot Service", estimated_duration: 25,
      requires_appointment: true, active: true, calendar: @calendar
    )
    @organization.update!(bookable_times: @organization.bookable_times.merge("tuesday" => [ { "start" => "10:00", "end" => "11:00" } ]))
  end

  teardown { travel_back }

  test "only offers slots that finish by the end of the window" do
    slots = SlotAvailabilityService.new(@organization, @service, Date.new(2027, 3, 2)).available_slots

    assert_equal %w[10:00 10:25], slots.map { |slot| slot[:time] }
  end

  test "returns no slots on a blocked date" do
    @organization.appointment_blocked_dates.create!(start_date: Date.new(2027, 3, 2))

    assert_empty SlotAvailabilityService.new(@organization, @service, Date.new(2027, 3, 2)).available_slots
  end

  test "openings mode offers slots only inside openings" do
    @organization.update!(appointment_booking_mode: "openings")
    @organization.appointment_openings.create!(
      start_date: Date.new(2027, 3, 6), end_date: Date.new(2027, 3, 6),
      bookable_times: { "saturday" => [ { "start" => "14:00", "end" => "15:00" } ] }
    )

    assert_equal %w[14:00 14:25], SlotAvailabilityService.new(@organization, @service, Date.new(2027, 3, 6)).available_slots.map { |slot| slot[:time] }
    assert_empty SlotAvailabilityService.new(@organization, @service, Date.new(2027, 3, 2)).available_slots
  end

  test "slot times do not depend on the server time zone" do
    original_tz = ENV["TZ"]
    ENV["TZ"] = "America/New_York"
    slots = SlotAvailabilityService.new(@organization, @service, Date.new(2027, 3, 2)).available_slots

    assert_equal %w[10:00 10:25], slots.map { |slot| slot[:time] }
  ensure
    ENV["TZ"] = original_tz
  end
end
