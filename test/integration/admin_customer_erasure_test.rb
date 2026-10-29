# frozen_string_literal: true

require "test_helper"

class AdminCustomerErasureTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    sign_in_as_system_admin(@admin)
    @records = create_customer_records
    @appointment = @records[:appointment]
    @service_request = @records[:service_request]
  end

  test "system admin can search and redact customer records" do
    post admin_customer_erasures_path, params: {
      customer_pii_search: {
        first_name: @appointment.first_name,
        last_name: @appointment.last_name,
        display_dob: @appointment.dob.strftime("%d-%m-%Y")
      }
    }

    assert_response :success
    assert_match @appointment.first_name, response.body

    assert_difference -> { AuditLog.where(event_type: :customer_pii_redacted).count }, 1 do
      post admin_customer_erasures_path, params: {
        confirm_erasure: "1",
        confirm: "1",
        appointment_ids: [ @appointment.id ],
        service_request_ids: [ @service_request.id ],
        customer_pii_search: {
          first_name: @appointment.first_name,
          last_name: @appointment.last_name,
          display_dob: @appointment.dob.strftime("%d-%m-%Y")
        }
      }
    end

    assert_response :success
    assert_match "Download CSV", response.body
    assert @appointment.reload.pii_redacted_at.present?
    assert @service_request.reload.pii_redacted_at.present?
  end

  test "system admin can email report after search" do
    assert_enqueued_emails 1 do
      post admin_customer_erasures_path, params: {
        email_export: "1",
        recipient_email: "recipient@example.com",
        customer_pii_search: {
          first_name: @appointment.first_name,
          last_name: @appointment.last_name,
          display_dob: @appointment.dob.strftime("%d-%m-%Y")
        }
      }
    end

    assert_redirected_to new_admin_customer_erasure_path
    assert AuditLog.exists?(event_type: :customer_pii_report_exported)
  end

  test "system user without customer erasure permission is denied" do
    sign_out
    sign_in_as_system_user(users(:two))

    get new_admin_customer_erasure_path
    assert_redirected_to root_path
  end

  private

  def sign_in_as_system_admin(user)
    role = Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_ADMIN) { |r| r.permanent = true }
    user.grant_role!(role)
    post login_path, params: { email: user.email, password: "password123" }
  end

  def sign_in_as_system_user(user)
    role = Role.find_by!(scope: :system, name: Role::SYSTEM_USER)
    user.grant_role!(role)
    post login_path, params: { email: user.email, password: "password123" }
  end

  def sign_out
    delete logout_path
  end

  def create_customer_records
    owner = users(:one)
    organization = Organization.create_personal_for!(owner)
    calendar = organization.calendars.find_by!(is_default: true)
    service = organization.services.create!(
      internal_name: "erase_svc_#{Time.current.to_i}",
      display_name: "Erasure Service",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: calendar
    )
    appointment = Appointment.create!(
      organization: organization,
      service: service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      email: "jane.doe@example.com",
      appointment_date: Date.current + 2.days,
      appointment_time: Time.zone.parse("10:00"),
      status: "booked"
    )
    service_request = ServiceRequest.create!(
      organization: organization,
      service: service,
      first_name: "Jane",
      last_name: "Doe",
      dob: Date.new(1990, 5, 15),
      postcode: "N1 1AA",
      status: "waiting",
      request_type: "immediate",
      queue_number: "1",
      queue_date: Date.current
    )

    { organization:, appointment:, service_request: }
  end
end
