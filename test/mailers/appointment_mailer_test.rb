# frozen_string_literal: true

require "test_helper"

class AppointmentMailerTest < ActionMailer::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @organization.update!(name: "Green Pharmacy", address_line1: "1 High Street", address_city: "London", address_postal_code: "SW1A 1AA")
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "flu_jab_#{Time.current.to_i}",
      display_name: "Flu Jab",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: @calendar
    )
    @appointment = Appointment.create!(
      organization: @organization,
      service: @service,
      first_name: "Emily",
      last_name: "Brown",
      dob: Date.new(1990, 3, 20),
      postcode: "SW1A 1AA",
      email: "emily@example.com",
      appointment_date: Date.current + 3.days,
      appointment_time: Time.zone.parse("09:30"),
      status: "booked"
    )
  end

  test "booking confirmation is sent to customer email" do
    mail = AppointmentMailer.booking_confirmation(@appointment)
    assert_equal [ "emily@example.com" ], mail.to
  end

  test "booking confirmation has correct subject and body" do
    mail = AppointmentMailer.booking_confirmation(@appointment)
    assert_match(/Appointment Confirmed/, mail.subject)
    assert_match(/Green Pharmacy/, mail.subject)
    assert_match(/Emily/, mail.body.encoded)
    assert_match(/Flu Jab/, mail.body.encoded)
    assert_match @appointment.booking_reference, mail.body.encoded
    assert_match(/1 High Street/, mail.body.encoded)
    assert_match(/Powered by/, mail.body.encoded)
    assert_match(/rxterminal\.co\.uk/, mail.body.encoded)
    assert_match(/rxterminal-title-small\.png|RxTerminal-Title-small\.png/, mail.body.encoded)
  end

  test "booking confirmation includes calendar attachment" do
    mail = AppointmentMailer.booking_confirmation(@appointment)
    filename = AppointmentCalendarExport.filename(@appointment)
    assert mail.attachments[filename].present?
    assert_match "BEGIN:VCALENDAR", mail.attachments[filename].body.raw_source
  end

  test "cancellation is sent to customer email" do
    mail = AppointmentMailer.cancellation(@appointment)
    assert_equal [ "emily@example.com" ], mail.to
    assert_match(/Cancelled/, mail.subject)
    assert_match @appointment.booking_reference, mail.body.encoded
  end

  test "reminder is sent to customer email with calendar attachment" do
    mail = AppointmentMailer.reminder(@appointment)
    assert_equal [ "emily@example.com" ], mail.to
    assert_match(/Reminder/, mail.subject)
    assert_match(@appointment.appointment_date.strftime("%A, %d %B"), mail.subject)
    filename = AppointmentCalendarExport.filename(@appointment)
    assert mail.attachments[filename].present?
  end

  test "booking confirmation is not sent when email is blank" do
    @appointment.update_column(:email, nil)
    mail = AppointmentMailer.booking_confirmation(@appointment).message
    assert_kind_of ActionMailer::Base::NullMail, mail
  end

  test "confirmation and reminder use the default closing message when none is set" do
    [ AppointmentMailer.booking_confirmation(@appointment), AppointmentMailer.reminder(@appointment) ].each do |mail|
      assert_match "Please arrive 5 minutes before your scheduled appointment.", mail.html_part.body.decoded
      assert_match "Please arrive 5 minutes before your scheduled appointment.", mail.text_part.body.decoded
    end
  end

  test "confirmation and reminder use the organization's custom closing message" do
    @organization.update!(appointment_email_message: "Bring your inhaler.\nPark at the back <b>please</b>.")

    [ AppointmentMailer.booking_confirmation(@appointment), AppointmentMailer.reminder(@appointment) ].each do |mail|
      html = mail.html_part.body.decoded
      text = mail.text_part.body.decoded

      assert_match "Bring your inhaler.", html
      assert_match "Park at the back &lt;b&gt;please&lt;/b&gt;.", html
      assert_no_match "Please arrive 5 minutes", html
      assert_match "Bring your inhaler.\nPark at the back <b>please</b>.", text
      assert_no_match "Please arrive 5 minutes", text
    end
  end

  test "cancellation shows the reason below the appointment details and keeps the rebook line" do
    @appointment.cancel!(reason: "The pharmacist is unavailable.")

    mail = AppointmentMailer.cancellation(@appointment)
    html = mail.html_part.body.decoded
    text = mail.text_part.body.decoded

    assert_match "The pharmacist is unavailable.", html
    assert html.index(@appointment.formatted_time) < html.index("Reason for cancellation")
    assert html.index("Reason for cancellation") < html.index("rebook or have any questions")
    assert_match "The pharmacist is unavailable.", text
    assert text.index("REASON FOR CANCELLATION") < text.index("If you'd like to rebook")
  end

  test "cancellation without a reason omits the reason section" do
    @appointment.cancel!

    mail = AppointmentMailer.cancellation(@appointment)

    assert_no_match "Reason for cancellation", mail.html_part.body.decoded
    assert_no_match "REASON FOR CANCELLATION", mail.text_part.body.decoded
    assert_match "rebook or have any questions", mail.html_part.body.decoded
  end
end
