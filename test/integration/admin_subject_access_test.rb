# frozen_string_literal: true

require "test_helper"

class AdminSubjectAccessRequestTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    sign_in_as_system_admin(@admin)
    @records = create_customer_records
    @appointment = @records[:appointment]
  end

  test "system admin can search with slash formatted dob" do
    post admin_subject_access_requests_path, params: {
      customer_pii_search: {
        first_name: @appointment.first_name,
        last_name: @appointment.last_name,
        display_dob: @appointment.dob.strftime("%d/%m/%Y")
      }
    }

    assert_response :success
    assert_match @appointment.first_name, response.body
  end

  test "system admin can export matching records as csv" do
    assert_difference -> { AuditLog.where(event_type: :subject_access_exported).count }, 1 do
      post admin_subject_access_requests_path, params: {
        export: "1",
        customer_pii_search: {
          first_name: @appointment.first_name,
          last_name: @appointment.last_name,
          display_dob: @appointment.dob.strftime("%d-%m-%Y")
        }
      }
    end

    assert_response :success
    assert_equal CustomerPiiReportDelivery::CONTENT_TYPE, response.media_type

    rows = CSV.parse(response.body)
    assert_includes rows.flatten, "Appointments"
    assert_includes rows.flatten, "Jane"
    assert_includes rows.flatten, @appointment.booking_reference
  end

  test "system admin can email sar report" do
    assert_enqueued_emails 1 do
      post admin_subject_access_requests_path, params: {
        email_export: "1",
        recipient_email: "recipient@example.com",
        customer_pii_search: {
          first_name: @appointment.first_name,
          last_name: @appointment.last_name,
          display_dob: @appointment.dob.strftime("%d-%m-%Y")
        }
      }
    end

    assert_redirected_to new_admin_subject_access_request_path
  end

  test "download also emails report when recipient email is provided" do
    assert_enqueued_emails 1 do
      post admin_subject_access_requests_path, params: {
        export: "1",
        recipient_email: "recipient@example.com",
        customer_pii_search: {
          first_name: @appointment.first_name,
          last_name: @appointment.last_name,
          display_dob: @appointment.dob.strftime("%d-%m-%Y")
        }
      }
    end

    assert_response :success
    assert_equal CustomerPiiReportDelivery::CONTENT_TYPE, response.media_type
  end

  test "system user without subject access permission is denied" do
    sign_out
    sign_in_as_system_user(users(:two))

    get new_admin_subject_access_request_path
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
      internal_name: "sar_svc_#{Time.current.to_i}",
      display_name: "SAR Service",
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

    { organization:, appointment: }
  end
end
