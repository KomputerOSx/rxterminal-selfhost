# frozen_string_literal: true

require "test_helper"

# with_lock is a no-op row lock on SQLite. Double-booking protection relies on Rails opening
# write transactions with BEGIN IMMEDIATE (save wraps validation and INSERT in one), so only
# one writer runs at a time. These tests run real concurrent writers with transactional
# tests off.
class AppointmentConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  THREADS = 5

  # Widens the gap between the availability check and the INSERT so an unprotected
  # check-then-insert reliably double-books.
  module SlowSlotCheck
    class << self
      attr_accessor :enabled
    end

    private

    def appointment_slot_available
      super
      sleep 0.2 if SlowSlotCheck.enabled
    end
  end

  setup do
    Appointment.prepend(SlowSlotCheck) unless Appointment.include?(SlowSlotCheck)
    SlowSlotCheck.enabled = true
    @owner = User.create!(
      email: "concurrency-#{SecureRandom.hex(4)}@example.com", password: "Tr8kMvln52",
      password_confirmation: "Tr8kMvln52", confirmed_at: Time.current
    )
    @organization = Organization.create_personal_for!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "concurrent_svc_#{SecureRandom.hex(4)}",
      display_name: "Concurrent Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: @calendar
    )
  end

  teardown do
    SlowSlotCheck.enabled = false
    Appointment.where(organization_id: @organization.id).delete_all
    @organization.destroy
    @owner.destroy
  end

  test "only one of several concurrent bookings for the same slot succeeds" do
    results = book_concurrently(THREADS) { build_appointment }

    assert_equal 1, results.count(true), "expected exactly one booking to win, got #{results.inspect}"
    assert_equal 1, Appointment.where(organization_id: @organization.id).count
  end

  test "concurrent bookings for different slots all succeed" do
    index = Concurrent::AtomicFixnum.new(-1)
    results = book_concurrently(THREADS) do
      build_appointment(time: Time.zone.parse("09:00") + (index.increment * 15).minutes)
    end

    assert_equal [ true ] * THREADS, results
  end

  private

  def book_concurrently(count)
    ready = Queue.new
    start = Queue.new
    threads = Array.new(count) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          appointment = yield
          ready << true
          start.pop
          appointment.save_with_slot_protection
        end
      end
    end
    count.times { ready.pop }
    count.times { start << true }
    threads.map(&:value)
  end

  def build_appointment(time: Time.zone.parse("10:00"))
    Appointment.new(
      organization: @organization,
      service: @service,
      first_name: "JANE",
      last_name: "DOE",
      dob: Date.new(1990, 1, 1),
      postcode: "N1 1AA",
      appointment_date: Date.current + 1.day,
      appointment_time: time,
      status: "booked"
    )
  end
end
