# frozen_string_literal: true

require "test_helper"

class OrgAppointmentEmailsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "email-svc",
      display_name: "Email Service",
      estimated_duration: 15,
      requires_appointment: true,
      allows_immediate: false,
      icon: "vaccines"
    )
    @appointment = @organization.appointments.create!(
      service: @service,
      first_name: "JANE",
      last_name: "DOE",
      dob: Date.new(1990, 5, 15),
      postcode: "SW1A 1AA",
      email: "jane@example.com",
      appointment_date: Date.current + 2.days,
      appointment_time: "11:00",
      status: "booked"
    )
  end

  test "creating an appointment enqueues confirmation email" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_enqueued_emails 1 do
        post org_appointments_path, params: {
          appointment: {
            service_id: @service.id,
            first_name: "alex",
            last_name: "smith",
            dob: "20-05-1985",
            postcode: "SW1A 2AA",
            email: "alex@example.com",
            appointment_date: (Date.current + 3.days).strftime("%d-%m-%Y"),
            appointment_time: "12:00"
          }
        }
      end
    end
  end

  test "cancelling an appointment enqueues cancellation email" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_enqueued_emails 1 do
      patch cancel_org_appointment_path(@appointment)
    end
  end

  test "resend confirmation enqueues booking confirmation email" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_enqueued_emails 1 do
      post resend_confirmation_org_appointment_path(@appointment)
    end

    assert_redirected_to org_appointment_path(@appointment)
    assert_equal "Confirmation email resent.", flash[:notice]
  end
end
