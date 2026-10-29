# frozen_string_literal: true

require "test_helper"

class OrgAppointmentOpeningsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @start_date = Date.current + 3.days
    @end_date = @start_date + 30.days
    post login_path, params: { email: @owner.email, password: "password123" }
  end

  test "the new opening page shows the weekly bookable windows" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get new_org_appointment_booking_opening_path
    end

    assert_response :success
    assert_match "New opening", response.body
    assert_match(/appointment_opening\[bookable_times\]\[monday\]\[bookable_day\]/, response.body)
    assert_match "Save opening", response.body
  end

  test "an owner can add an opening with its own weekly windows" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { @organization.appointment_openings.count }, 1 do
        post org_appointment_booking_openings_path, params: {
          appointment_opening: {
            name: "Flu season",
            start_date: @start_date.iso8601,
            end_date: @end_date.iso8601,
            bookable_times: {
              "saturday" => { bookable_day: "1", "0" => { start: "09:00", end: "12:00" } },
              "monday" => { bookable_day: "0" }
            }
          }
        }
      end
    end

    assert_redirected_to org_appointment_booking_path
    opening = @organization.appointment_openings.last
    assert_equal [ "Flu season", @start_date, @end_date ], [ opening.name, opening.start_date, opening.end_date ]
    assert_equal [ { "start" => "09:00", "end" => "12:00" } ], opening.bookable_times["saturday"]
    assert_equal [], opening.bookable_times["monday"]
    assert AuditLog.exists?(event_type: "appointment_opening_created", resource_type: "AppointmentOpening", resource_id: opening.id)
  end

  test "an owner can assign an opening to several calendars" do
    clinic_a = @organization.calendars.create!(name: "Clinic A")
    clinic_b = @organization.calendars.create!(name: "Clinic B")

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get new_org_appointment_booking_opening_path
      assert_match "Selected calendars", response.body

      post org_appointment_booking_openings_path, params: {
        appointment_opening: {
          start_date: @start_date.iso8601,
          end_date: @end_date.iso8601,
          calendar_scope: "selected",
          calendar_ids: [ "", clinic_a.id, clinic_b.id ]
        }
      }
    end

    assert_redirected_to org_appointment_booking_path
    opening = @organization.appointment_openings.last
    assert_equal [ clinic_a.id, clinic_b.id ].sort, opening.calendar_ids.sort
  end

  test "editing an opening on an archived calendar keeps that calendar" do
    clinic = @organization.calendars.create!(name: "Clinic")
    opening = @organization.appointment_openings.create!(start_date: @start_date, end_date: @end_date, calendar_ids: [ clinic.id ])
    clinic.update!(archived: true)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get edit_org_appointment_booking_opening_path(opening)
      assert_match "Clinic (archived)", response.body

      patch org_appointment_booking_opening_path(opening), params: {
        appointment_opening: {
          name: "Renamed", start_date: @start_date.iso8601, end_date: @end_date.iso8601,
          calendar_scope: "selected", calendar_ids: [ "", clinic.id ]
        }
      }
    end

    assert_redirected_to org_appointment_booking_path
    assert_equal [ clinic.id ], opening.reload.calendar_ids
  end

  test "switching an opening back to all calendars clears its calendars" do
    clinic = @organization.calendars.create!(name: "Clinic")
    opening = @organization.appointment_openings.create!(start_date: @start_date, end_date: @end_date, calendar_ids: [ clinic.id ])

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      patch org_appointment_booking_opening_path(opening), params: {
        appointment_opening: { start_date: @start_date.iso8601, end_date: @end_date.iso8601, calendar_scope: "all", calendar_ids: [ "", clinic.id ] }
      }
    end

    assert opening.reload.all_calendars?
  end

  test "invalid openings re-render the form with errors" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_no_difference -> { AppointmentOpening.count } do
        post org_appointment_booking_openings_path, params: {
          appointment_opening: {
            start_date: @end_date.iso8601,
            end_date: @start_date.iso8601,
            bookable_times: { "tuesday" => { bookable_day: "1", "0" => { start: "15:00", end: "14:00" } } }
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_match "cannot be before the start date", response.body
    assert_match "Tuesday window 1 must end after it starts", response.body
  end

  test "an owner can edit an opening" do
    opening = @organization.appointment_openings.create!(name: "Spring", start_date: @start_date, end_date: @end_date)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get edit_org_appointment_booking_opening_path(opening)
      assert_response :success
      assert_match "Spring", response.body

      patch org_appointment_booking_opening_path(opening), params: {
        appointment_opening: {
          name: "Summer",
          start_date: @start_date.iso8601,
          end_date: (@end_date + 10.days).iso8601,
          bookable_times: { "sunday" => { bookable_day: "1", "0" => { start: "10:00", end: "11:00" } } }
        }
      }
    end

    assert_redirected_to org_appointment_booking_path
    opening.reload
    assert_equal "Summer", opening.name
    assert_equal @end_date + 10.days, opening.end_date
    assert_equal [ { "start" => "10:00", "end" => "11:00" } ], opening.bookable_times["sunday"]
    assert_equal @organization.bookable_times["monday"], opening.bookable_times["monday"]
    assert AuditLog.exists?(event_type: "appointment_opening_updated", resource_id: opening.id)
  end

  test "an owner can remove an opening" do
    opening = @organization.appointment_openings.create!(start_date: @start_date, end_date: @end_date)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      delete org_appointment_booking_opening_path(opening), as: :turbo_stream
    end

    assert_response :success
    assert_not AppointmentOpening.exists?(opening.id)
    assert AuditLog.exists?(event_type: "appointment_opening_deleted", resource_id: opening.id)
  end

  test "removing an opening with bookings warns but keeps the appointments" do
    @organization.update!(appointment_booking_mode: "openings")
    service = @organization.services.create!(
      internal_name: "opening_svc", display_name: "Opening Service", estimated_duration: 15,
      requires_appointment: true, active: true, calendar: @organization.calendars.first
    )
    opening = @organization.appointment_openings.create!(
      start_date: @start_date, end_date: @start_date,
      bookable_times: { Organization.weekday_key(@start_date) => [ { "start" => "10:00", "end" => "12:00" } ] }
    )
    appointment = Appointment.create!(
      organization: @organization, service: service, first_name: "JANE", last_name: "DOE",
      dob: Date.new(1990, 1, 1), postcode: "N1 1AA", appointment_date: @start_date,
      appointment_time: Time.zone.parse("10:00"), status: "booked"
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      delete org_appointment_booking_opening_path(opening), as: :turbo_stream
    end

    assert_match "1 booked appointment falls outside your booking schedule", response.body
    assert_match appointment.booking_reference, response.body
    assert_equal "booked", appointment.reload.status
  end

  test "openings from another organization cannot be edited" do
    other_org = Organization.create_personal_for!(users(:two))
    opening = other_org.appointment_openings.create!(start_date: @start_date, end_date: @end_date)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get edit_org_appointment_booking_opening_path(opening)
    end

    assert_response :not_found
  end

  test "plans without appointments are blocked" do
    @organization.switch_trial_plan!(Billing::Plans::STARTER)

    assert_no_difference -> { AppointmentOpening.count } do
      post org_appointment_booking_openings_path, params: {
        appointment_opening: { start_date: @start_date.iso8601, end_date: @end_date.iso8601 }
      }
    end

    assert_redirected_to billing_path
  end
end
