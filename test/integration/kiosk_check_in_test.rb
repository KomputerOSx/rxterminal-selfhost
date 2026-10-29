# frozen_string_literal: true

require "test_helper"

class KioskCheckInTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @api_key = SecureRandom.hex(32)
    @device = @organization.devices.create!(
      device_id: "lobby_kiosk_checkin",
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

    @appointment = @organization.appointments.create!(
      service: @service,
      first_name: "JANE",
      last_name: "DOE",
      dob: Date.new(1985, 3, 20),
      postcode: "SW1A 1AA",
      appointment_date: Date.current,
      appointment_time: "10:00",
      status: "booked"
    )

    authenticate_kiosk!
  end

  test "GET check_in renders old-repo structure" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get kiosk_check_in_appointments_path
      assert_response :success
      assert_match "kiosk-check-in", response.body
      assert_match "kiosk-services-topbar", response.body
      assert_match "kiosk-services-back-btn", response.body
      assert_match "Booking Reference", response.body
      assert_match "kiosk-input-field", response.body
      assert_match "Last Name", response.body
    end
  end

  test "POST process_check_in with booking reference checks in appointment" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { ServiceRequest.count }, 1 do
        post process_check_in_kiosk_appointments_path,
          params: { booking_reference: @appointment.booking_reference }
      end

      assert_redirected_to kiosk_appointment_checked_in_path
      follow_redirect!
      assert_response :success
      assert_no_match @appointment.service.display_name, response.body
      assert_match @appointment.reload.service_request.queue_number.to_s, response.body
      assert_match "You're Checked In!", response.body
      assert_match "checkin-result--success", response.body
    end
  end

  test "GET check_in_candidates returns appointments matching last name and dob" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get check_in_candidates_kiosk_appointments_path,
        params: { last_name: "doe", dob: "1985-03-20" }

      assert_response :success
      assert_match @appointment.formatted_time, response.body
      assert_no_match @service.display_name, response.body
      assert_match "data-appointment-id=\"#{@appointment.id}\"", response.body
    end
  end

  test "GET check_in_candidates returns 404 when nothing matches" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get check_in_candidates_kiosk_appointments_path,
        params: { last_name: "nobody", dob: "1985-03-20" }

      assert_response :not_found
      assert_empty response.body
    end
  end

  test "POST process_check_in with last name, dob and appointment_id checks in the selected appointment" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { ServiceRequest.count }, 1 do
        post process_check_in_kiosk_appointments_path,
          params: {
            last_name: "doe",
            dob: "1985-03-20",
            appointment_id: @appointment.id
          }
      end

      assert_redirected_to kiosk_appointment_checked_in_path
      assert_equal "checked_in", @appointment.reload.status
    end
  end

  test "POST process_check_in with last name and dob but no appointment_id does not check anyone in" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_no_difference -> { ServiceRequest.count } do
        post process_check_in_kiosk_appointments_path,
          params: { last_name: "doe", dob: "1985-03-20" }
      end

      assert_response :unprocessable_entity
      assert_match "Appointment not found", response.body
      assert_equal "booked", @appointment.reload.status
    end
  end

  test "customer picks the right appointment on kiosk when two people share a last name" do
    john = @organization.appointments.create!(
      service: @service,
      first_name: "JOHN",
      last_name: "DOE",
      dob: Date.new(1979, 6, 2),
      postcode: "SW1A 1AA",
      appointment_date: Date.current,
      appointment_time: "11:00",
      status: "booked"
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get check_in_candidates_kiosk_appointments_path, params: { last_name: "doe" }
      assert_response :success
      assert_match "data-appointment-id=\"#{@appointment.id}\"", response.body
      assert_match "data-appointment-id=\"#{john.id}\"", response.body
      assert_no_match @service.display_name, response.body

      post process_check_in_kiosk_appointments_path,
        params: { last_name: "doe", appointment_id: john.id }

      assert_redirected_to kiosk_appointment_checked_in_path
    end

    assert_equal "checked_in", john.reload.status
    assert_equal "booked", @appointment.reload.status
  end

  test "POST process_check_in with wrong reference re-renders check_in with alert" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post process_check_in_kiosk_appointments_path,
        params: { booking_reference: "ZZZZZZ" }

      assert_response :unprocessable_entity
      assert_match "Appointment not found", response.body
      assert_match "reference", response.body
    end
  end

  test "POST process_check_in when already checked in shows alert" do
    @appointment.check_in!

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post process_check_in_kiosk_appointments_path,
        params: { booking_reference: @appointment.booking_reference }

      assert_response :unprocessable_entity
      assert_match "already been checked in", response.body
    end
  end

  test "POST process_check_in for future appointment renders early screen" do
    future = @organization.appointments.create!(
      service: @service,
      first_name: "ALICE",
      last_name: "SMITH",
      dob: Date.new(1990, 1, 1),
      postcode: "SW1A 1AA",
      appointment_date: Date.current + 1.day,
      appointment_time: "11:00",
      status: "booked"
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post process_check_in_kiosk_appointments_path,
        params: { booking_reference: future.booking_reference }

      assert_response :success
      assert_match "Your appointment isn't today", response.body
      assert_match "checkin-result--early", response.body
      assert_match future.formatted_date, response.body
    end
  end

  test "POST process_check_in for past appointment renders late screen" do
    past = @organization.appointments.create!(
      service: @service,
      first_name: "BOB",
      last_name: "JONES",
      dob: Date.new(1990, 1, 1),
      postcode: "SW1A 1AA",
      appointment_date: Date.current + 1.day,
      appointment_time: "11:00",
      status: "booked"
    )
    past.update_columns(appointment_date: Date.current - 1.day)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post process_check_in_kiosk_appointments_path,
        params: { booking_reference: past.booking_reference }

      assert_response :success
      assert_match past.formatted_date, response.body
      assert_match "missed your slot", response.body
      assert_match "checkin-result--late", response.body
    end
  end

  private

  def authenticate_kiosk!
    post kiosk_setup_configure_path, params: {
      device_id: @device.device_id,
      api_key: @api_key
    }
    post kiosk_setup_authenticate_path
    follow_redirect!
  end
end
