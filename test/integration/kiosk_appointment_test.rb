# frozen_string_literal: true

require "test_helper"

class KioskAppointmentTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @api_key = SecureRandom.hex(32)
    @device = @organization.devices.create!(
      device_id: "lobby_kiosk_appt",
      name: "Lobby",
      api_key: @api_key,
      status: "active"
    )

    @service = @organization.services.create!(
      internal_name: "bp_check",
      display_name: "Blood pressure check",
      estimated_duration: 15,
      active: true,
      display_order: 0,
      requires_appointment: true,
      allows_immediate: false
    )
  end

  test "GET new with service_id renders wizard" do
    with_authenticated_kiosk do
      get kiosk_new_appointment_path(service_id: @service.id)
      assert_response :success
      assert_match "kiosk-appointment", response.body
      assert_match @service.display_name, response.body
    end
  end

  test "POST create with valid data creates appointment" do
    with_authenticated_kiosk do
    appointment_date = next_bookable_date

    assert_difference -> { Appointment.count }, 1 do
      post kiosk_appointments_path,
        params: {
          appointment: {
            service_id: @service.id,
            first_name: "jane",
            last_name: "doe",
            dob: "1985-03-20",
            postcode: "SW1A 1AA",
            email: "jane@example.com",
            appointment_date: appointment_date.iso8601,
            appointment_time: "10:00",
            notes: "Wheelchair access"
          }
        },
        as: :json
    end

    assert_response :success

    body = JSON.parse(response.body)
    assert body["redirect_to"].present?

    appointment = Appointment.last
    assert_equal @organization, appointment.organization
    assert_equal @service, appointment.service
    assert_equal "JANE", appointment.first_name
    assert_equal "DOE", appointment.last_name
    assert_equal appointment_date, appointment.appointment_date
    assert_equal "booked", appointment.status
    assert appointment.booking_reference.present?
    end
  end

  test "GET confirmation with session works" do
    with_authenticated_kiosk do
    appointment_date = next_bookable_date

    post kiosk_appointments_path,
      params: {
        appointment: {
          service_id: @service.id,
          first_name: "jane",
          last_name: "doe",
          dob: "1985-03-20",
          postcode: "SW1A 1AA",
          appointment_date: appointment_date.iso8601,
          appointment_time: "10:00"
        }
      },
      as: :json

    assert_response :success
    body = JSON.parse(response.body)

    get body["redirect_to"]
    assert_response :success
    assert_match Appointment.last.booking_reference, response.body
    assert_match @service.display_name, response.body
    end
  end

  test "calendar disables blocked dates" do
    blocked = Date.current + 1.day
    blocked += 1.day while blocked.saturday? || blocked.sunday?
    @organization.appointment_blocked_dates.create!(start_date: blocked, reason: "Staff training")

    with_authenticated_kiosk do
      get calendar_kiosk_appointments_path(month: blocked.strftime("%Y-%m"), service_id: @service.id)
    end

    assert_response :success
    assert_match(/data-date="#{blocked.iso8601}"\s+data-disabled="true"/, response.body)
    assert_match "Closed: Staff training", response.body
  end

  test "POST create without an email is rejected when the organization requires one" do
    @organization.update!(require_appointment_email: true)

    with_authenticated_kiosk do
      get kiosk_new_appointment_path(service_id: @service.id)
      assert_match "Required", response.body
      assert_no_match "kiosk-appointment#emailSkip", response.body

      assert_no_difference -> { Appointment.count } do
        post kiosk_appointments_path,
          params: {
            appointment: {
              service_id: @service.id,
              first_name: "jane",
              last_name: "doe",
              dob: "1985-03-20",
              postcode: "SW1A 1AA",
              appointment_date: next_bookable_date.iso8601,
              appointment_time: "10:00"
            }
          },
          as: :json
      end

      assert_response :unprocessable_entity
      assert_includes JSON.parse(response.body)["errors"], "Email can't be blank"
    end
  end

  private

  def with_authenticated_kiosk
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      authenticate_kiosk!
      yield
    end
  end

  def authenticate_kiosk!
    post kiosk_setup_configure_path, params: {
      device_id: @device.device_id,
      api_key: @api_key
    }
    post kiosk_setup_authenticate_path
    follow_redirect!
  end

  def next_bookable_date
    date = Date.current
    14.times do
      day_key = date.strftime("%A").downcase
      return date if @organization.bookable_times[day_key].present?
      date += 1.day
    end
    Date.current + 1.day
  end
end
