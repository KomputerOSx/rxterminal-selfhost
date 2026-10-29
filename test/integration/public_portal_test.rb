# frozen_string_literal: true

require "test_helper"

class PublicPortalTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @calendar = @organization.calendars.find_by!(is_default: true)
    @service = @organization.services.create!(
      internal_name: "flu_jab",
      display_name: "Flu jab",
      estimated_duration: 15,
      requires_appointment: true,
      active: true,
      calendar: @calendar
    )

    enable_public_portal!(@organization, :online_appointment_booking)
    accept_portal_privacy!
  end

  test "portal home lists bookable services" do
    get portal_root_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match "Book an appointment", response.body
    assert_match @service.display_name, response.body
    assert_match 'data-theme="kiosk-default"', response.body
    assert_no_match 'localStorage.getItem("theme")', response.body
    assert_no_match 'aria-label="Toggle theme"', response.body
  end

  test "bare appointments path renders the booking form" do
    get "/#{@organization.slug}/appointments"

    assert_response :success
    assert_match @service.display_name, response.body
  end

  test "portal applies organization theme" do
    @organization.update!(portal_theme: "kiosk-violet")

    get portal_root_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match 'data-theme="kiosk-violet"', response.body
  end

  test "portal title tag uses the organization name without the RxTerminal suffix" do
    get portal_root_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match "<title>#{@organization.name}</title>", response.body
  end

  test "portal title tag omits the RxTerminal suffix when served on a custom domain" do
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      @organization.update!(custom_domain: "shop.acme.test")
    end

    host! "shop.acme.test"
    get "/"

    assert_response :success
    assert_match "<title>#{@organization.name}</title>", response.body
    assert_match '<link rel="canonical" href="http://shop.acme.test/">', response.body
  end

  test "portal home is reachable without accepting privacy" do
    reset!

    get portal_root_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match @service.display_name, response.body
  end

  test "booking still requires accepting privacy first" do
    reset!

    get new_portal_appointment_path(organization_slug: @organization.slug)

    assert_redirected_to portal_privacy_path(organization_slug: @organization.slug)
  end

  test "portal home is indexable with canonical url, description and structured data" do
    @organization.update!(business_type: "clinic", contact_phone: "01234 567890", address_line1: "1 High Street", address_city: "Leeds")

    get portal_root_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match '<meta name="robots" content="index, follow">', response.body
    assert_match %(<link rel="canonical" href="http://www.example.com/#{@organization.slug}">), response.body
    assert_match '<meta name="description"', response.body
    assert_match '<meta property="og:title"', response.body

    json_ld = JSON.parse(Nokogiri::HTML(response.body).at_css('script[type="application/ld+json"]').text)
    assert_equal "MedicalClinic", json_ld["@type"]
    assert_equal @organization.name, json_ld["name"]
    assert_equal "01234 567890", json_ld["telephone"]
    assert_equal "Leeds", json_ld.dig("address", "addressLocality")
    assert_includes json_ld["openingHoursSpecification"].map { |spec| spec["dayOfWeek"] }, "Monday"
  end

  test "legal pages are indexable" do
    get portal_privacy_policy_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match '<meta name="robots" content="index, follow">', response.body
  end

  test "opening times and contact pages 404 when their features are off" do
    get portal_opening_times_path(organization_slug: @organization.slug)
    assert_response :not_found

    get portal_contact_path(organization_slug: @organization.slug)
    assert_response :not_found
  end

  test "portal nav is hidden when no info pages are enabled" do
    get portal_root_path(organization_slug: @organization.slug)

    assert_response :success
    assert_no_match 'aria-label="Portal"', response.body
  end

  test "opening times page lists weekly hours without the privacy prompt" do
    enable_public_portal!(@organization, :portal_opening_times)
    reset!

    get portal_opening_times_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match "<title>Opening times - #{@organization.name}</title>", response.body
    assert_match "Monday", response.body
    assert_match "9:00am - 6:00pm", response.body
    assert_match "Closed", response.body
    assert_match '<meta name="robots" content="index, follow">', response.body
    assert_match %(href="/#{@organization.slug}/opening-times"), response.body
    assert_no_match %(href="/#{@organization.slug}/contact"), response.body
  end

  test "contact page shows address, tel and mailto links" do
    enable_public_portal!(@organization, :portal_contact_page)
    @organization.update!(contact_email: "hello@acme.test", contact_phone: "+44 1234 567890", address_line1: "1 High Street", address_city: "Leeds")
    reset!

    get portal_contact_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match 'href="mailto:hello@acme.test"', response.body
    assert_match 'href="tel:+441234567890"', response.body
    assert_match "1 High Street, Leeds", response.body
    assert_match %(href="/#{@organization.slug}/contact"), response.body
  end

  test "contact page shows an empty state without details" do
    enable_public_portal!(@organization, :portal_contact_page)
    @organization.update!(contact_email: nil, contact_phone: nil, address_line1: nil, address_line2: nil, address_city: nil, address_state: nil, address_postal_code: nil, address_country: nil)

    get portal_contact_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match "No contact details yet.", response.body
  end

  test "info pages work on a custom domain" do
    enable_public_portal!(@organization, :portal_opening_times, :portal_contact_page)
    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      @organization.update!(custom_domain: "shop.acme.test")
    end
    host! "shop.acme.test"

    get "/opening-times"
    assert_response :success
    assert_match 'href="/contact"', response.body

    get "/contact"
    assert_response :success
  end

  test "flow pages are never indexable" do
    get new_portal_appointment_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match '<meta name="robots" content="noindex, nofollow">', response.body
    assert_no_match 'rel="canonical"', response.body
  end

  test "portal favicon uses the organization's uploaded logo when attached" do
    @organization.kiosk_logo.attach(
      io: StringIO.new("fake-logo"),
      filename: "logo.png",
      content_type: "image/png"
    )

    get portal_root_path(organization_slug: @organization.slug)

    assert_response :success
    logo_url = Rails.application.routes.url_helpers.rails_blob_path(@organization.kiosk_logo, only_path: true)
    assert_match %(<link rel="icon" href="#{logo_url}" type="image/png">), response.body
    assert_match %(<link rel="apple-touch-icon" href="#{logo_url}">), response.body
    assert_no_match "/icon.png", response.body
  end

  test "portal favicon falls back to the default RxTerminal icons when no logo is attached" do
    get portal_root_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match '<link rel="icon" href="/icon.png" type="image/png">', response.body
    assert_match '<link rel="icon" href="/icon.svg" type="image/svg+xml">', response.body
    assert_match '<link rel="apple-touch-icon" href="/icon.png">', response.body
  end

  test "portal returns 404 when public portal feature is disabled" do
    Feature.find_by!(key: "public_portal").update!(enabled: false)

    get portal_root_path(organization_slug: @organization.slug)

    assert_response :not_found
    assert_match "Page not found", response.body
  end

  test "customer can book an appointment through the public portal" do
    appointment_date = next_weekday(Date.current + 1.day)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { Appointment.count }, 1 do
        post portal_appointments_path(organization_slug: @organization.slug), params: {
          appointment: appointment_payload(appointment_date: appointment_date)
        }
      end
    end

    assert_redirected_to portal_appointment_confirmed_path(organization_slug: @organization.slug)

    follow_redirect!
    assert_response :success
    assert_match "Booking confirmed", response.body

    appointment = Appointment.last
    assert_equal @organization, appointment.organization
    assert_equal @service, appointment.service
    assert_equal "booked", appointment.status
    assert AuditLog.exists?(event_type: "appointment_booked_online", resource_type: "Appointment", resource_id: appointment.id)
  end

  test "appointment booking shows inline errors and preserves entered values on validation failure" do
    appointment_date = next_weekday(Date.current + 1.day)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post portal_appointments_path(organization_slug: @organization.slug), params: {
        appointment: appointment_payload(appointment_date: appointment_date).merge(
          last_name: "",
          dob: "31-13-1990",
          notes: "Prefer morning"
        )
      }
    end

    assert_response :unprocessable_entity
    assert_match "JANE", response.body
    assert_match "31-13-1990", response.body
    assert_match /prefer morning/i, response.body
    assert_no_match "alert-error", response.body
    assert_match "input-field w-full error", response.body
    assert_match "be blank", response.body.downcase
  end

  test "online booking requires an email when the organization requires it" do
    @organization.update!(require_appointment_email: true)
    appointment_date = next_weekday(Date.current + 1.day)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_no_difference -> { Appointment.count } do
        post portal_appointments_path(organization_slug: @organization.slug), params: {
          appointment: appointment_payload(appointment_date: appointment_date)
        }
      end
      assert_response :unprocessable_entity
      assert_match "be blank", response.body.downcase

      assert_difference -> { Appointment.count }, 1 do
        post portal_appointments_path(organization_slug: @organization.slug), params: {
          appointment: appointment_payload(appointment_date: appointment_date).merge(email: "jane@example.com")
        }
      end
    end
  end

  test "customer can check in for a pre-booked appointment through the public portal" do
    enable_public_portal!(@organization, :online_appointment_check)
    start_walk_in_session!

    appointment = @organization.appointments.create!(
      service: @service,
      calendar: @calendar,
      first_name: "JANE",
      last_name: "DOE",
      dob: Date.new(1990, 1, 1),
      postcode: "N1 1AA",
      appointment_date: Date.current,
      appointment_time: Time.zone.parse("09:00"),
      status: "booked"
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post portal_appointment_checkin_path(organization_slug: @organization.slug), params: {
        last_name: "Doe",
        dob: "01-01-1990"
      }
      assert_redirected_to portal_appointment_checkin_select_path(organization_slug: @organization.slug)

      follow_redirect!
      assert_response :success
      assert_match appointment.formatted_time, response.body
      assert_no_match appointment.service.display_name, response.body

      post portal_appointment_checkin_confirm_path(organization_slug: @organization.slug),
        params: { appointment_id: appointment.id }
    end

    assert_redirected_to portal_appointment_checkin_success_path(organization_slug: @organization.slug)
    assert_equal "checked_in", appointment.reload.status

    follow_redirect!
    assert_response :success
    assert_match(/queue number/i, response.body)
    assert_match appointment.reload.service_request.queue_number.to_s, response.body
  end

  test "customer can check in by name only when the organization does not collect dob" do
    @organization.update!(kiosk_collect_dob: false)
    enable_public_portal!(@organization, :online_appointment_check)
    start_walk_in_session!

    appointment = @organization.appointments.create!(
      service: @service,
      calendar: @calendar,
      first_name: "JANE",
      last_name: "DOE",
      dob: nil,
      postcode: "N1 1AA",
      appointment_date: Date.current,
      appointment_time: Time.zone.parse("09:00"),
      status: "booked"
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post portal_appointment_checkin_path(organization_slug: @organization.slug), params: {
        last_name: "Doe"
      }
      assert_redirected_to portal_appointment_checkin_select_path(organization_slug: @organization.slug)

      post portal_appointment_checkin_confirm_path(organization_slug: @organization.slug),
        params: { appointment_id: appointment.id }
    end

    assert_redirected_to portal_appointment_checkin_success_path(organization_slug: @organization.slug)
    assert_equal "checked_in", appointment.reload.status
  end

  test "customer picks the right appointment when two people share a last name" do
    @organization.update!(kiosk_collect_dob: false)
    enable_public_portal!(@organization, :online_appointment_check)
    start_walk_in_session!

    jane = @organization.appointments.create!(
      service: @service,
      calendar: @calendar,
      first_name: "JANE",
      last_name: "DOE",
      dob: nil,
      postcode: "N1 1AA",
      appointment_date: Date.current,
      appointment_time: Time.zone.parse("09:00"),
      status: "booked"
    )
    john = @organization.appointments.create!(
      service: @service,
      calendar: @calendar,
      first_name: "JOHN",
      last_name: "DOE",
      dob: nil,
      postcode: "N1 1AA",
      appointment_date: Date.current,
      appointment_time: Time.zone.parse("11:00"),
      status: "booked"
    )

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post portal_appointment_checkin_path(organization_slug: @organization.slug), params: {
        last_name: "Doe"
      }
      assert_redirected_to portal_appointment_checkin_select_path(organization_slug: @organization.slug)

      follow_redirect!
      assert_response :success
      assert_match "Please choose your appointment time.", response.body
      assert_match jane.formatted_time, response.body
      assert_match john.formatted_time, response.body
      assert_no_match jane.service.display_name, response.body

      post portal_appointment_checkin_confirm_path(organization_slug: @organization.slug),
        params: { appointment_id: john.id }
    end

    assert_redirected_to portal_appointment_checkin_success_path(organization_slug: @organization.slug)
    assert_equal "checked_in", john.reload.status
    assert_equal "booked", jane.reload.status
  end

  test "check-in form shows inline errors and preserves entered values on validation failure" do
    enable_public_portal!(@organization, :online_appointment_check)
    start_walk_in_session!

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post portal_appointment_checkin_path(organization_slug: @organization.slug), params: {
        last_name: "Smith",
        dob: "31-13-1990"
      }
    end

    assert_response :unprocessable_entity
    assert_match "Smith", response.body
    assert_match "31-13-1990", response.body
    assert_no_match "alert-error", response.body
    assert_match "input-field w-full error", response.body
    assert_match "invalid", response.body.downcase
  end

  test "second booking for the same slot is rejected" do
    appointment_date = next_weekday(Date.current + 1.day)
    payload = appointment_payload(appointment_date: appointment_date)

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post portal_appointments_path(organization_slug: @organization.slug), params: { appointment: payload }
      assert_redirected_to portal_appointment_confirmed_path(organization_slug: @organization.slug)

      assert_no_difference -> { Appointment.count } do
        post portal_appointments_path(organization_slug: @organization.slug), params: {
          appointment: payload.merge(first_name: "JOHN", last_name: "SMITH")
        }
      end
    end

    assert_response :unprocessable_entity
    assert_match /no longer available/i, response.body
  end

  test "walk-in form shows inline errors and preserves entered values on validation failure" do
    enable_public_portal!(@organization, :mobile_service_request)
    accept_portal_privacy!

    walk_in_service = @organization.services.create!(
      internal_name: "walk_in_queue",
      display_name: "Walk-in queue",
      estimated_duration: 10,
      allows_immediate: true,
      active: true,
      calendar: @calendar
    )

    start_walk_in_session!

    post portal_walk_in_path(organization_slug: @organization.slug), params: {
      service_request: {
        service_id: walk_in_service.id,
        first_name: "Jane",
        last_name: "",
        dob: "31-13-1990",
        description: "Needs help with prescription"
      }
    }

    assert_response :unprocessable_entity
    assert_match walk_in_service.display_name, response.body
    assert_match "JANE", response.body
    assert_match "31-13-1990", response.body
    assert_match /needs help with prescription/i, response.body
    assert_no_match "alert-error", response.body
    assert_match "input-field w-full error", response.body
    assert_match "be blank", response.body.downcase
  end

  test "walk-in form renders with date of birth field" do
    enable_public_portal!(@organization, :mobile_service_request)
    accept_portal_privacy!

    walk_in_service = @organization.services.create!(
      internal_name: "walk_in_flu",
      display_name: "Walk-in flu jab",
      estimated_duration: 10,
      allows_immediate: true,
      active: true,
      calendar: @calendar
    )

    start_walk_in_session!

    get new_portal_walk_in_path(organization_slug: @organization.slug, service_id: walk_in_service.id)

    assert_response :success
    assert_match "Date of birth", response.body
    assert_match 'type="date"', response.body
  end

  test "arrive page renders action tiles with valid token" do
    enable_public_portal!(@organization, :mobile_service_request, :online_appointment_check, :online_appointment_booking)
    accept_portal_privacy!

    token = Rails.application.message_verifier("walk-in").generate(
      { "org_id" => @organization.id, "org_slug" => @organization.slug }
    )

    get portal_arrive_path(organization_slug: @organization.slug, token: token)

    assert_response :success
    assert_match "Join the queue", response.body
    assert_match "Check in for appointment", response.body
    assert_match "Book appointment", response.body
  end

  test "walk-in join succeeds" do
    enable_public_portal!(@organization, :mobile_service_request)
    accept_portal_privacy!
    walk_in_service = walk_in_service!
    start_walk_in_session!

    assert_difference -> { ServiceRequest.count }, 1 do
      post portal_walk_in_path(organization_slug: @organization.slug), params: {
        service_request: walk_in_payload(walk_in_service)
      }
    end

    assert_redirected_to portal_walk_in_success_path(organization_slug: @organization.slug)
  end

  test "walk-in joins beyond the rate limit are throttled" do
    enable_public_portal!(@organization, :mobile_service_request)
    accept_portal_privacy!
    walk_in_service = walk_in_service!
    start_walk_in_session!

    5.times do
      post portal_walk_in_path(organization_slug: @organization.slug), params: {
        service_request: walk_in_payload(walk_in_service)
      }
      assert_response :redirect
    end

    post portal_walk_in_path(organization_slug: @organization.slug), params: {
      service_request: walk_in_payload(walk_in_service)
    }
    assert_response :too_many_requests
  end

  test "walk-in join redirects to the upsell prompt when a rule matches" do
    walk_in_service = seed_walk_in_upsell_rule!

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      post portal_walk_in_path(organization_slug: @organization.slug), params: {
        service_request: walk_in_payload(walk_in_service)
      }
    end

    assert_redirected_to portal_walk_in_upsell_path(organization_slug: @organization.slug)
  end

  test "walk-in upsell accept creates a second service request and shows both queue numbers" do
    walk_in_service = seed_walk_in_upsell_rule!

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      join_walk_in_for_upsell!(walk_in_service)

      assert_difference -> { ServiceRequest.count }, 1 do
        post accept_portal_walk_in_upsell_path(organization_slug: @organization.slug)
      end

      assert_redirected_to confirmed_portal_walk_in_upsell_path(organization_slug: @organization.slug)
      follow_redirect!
      assert_match walk_in_service.display_name, response.body
      assert_match @suggested.display_name, response.body
    end
  end

  test "walk-in upsell decline records the interaction and returns to confirmation" do
    walk_in_service = seed_walk_in_upsell_rule!

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      join_walk_in_for_upsell!(walk_in_service)

      assert_difference -> { UpsellInteraction.count }, 1 do
        assert_no_difference -> { ServiceRequest.count } do
          post decline_portal_walk_in_upsell_path(organization_slug: @organization.slug)
        end
      end

      assert_equal "declined", UpsellInteraction.order(:created_at).last.outcome
      assert_redirected_to confirmed_portal_walk_in_upsell_path(organization_slug: @organization.slug)
    end
  end

  test "blocked dates are disabled in the portal calendar with the reason" do
    blocked = next_weekday(Date.current + 1.day)
    @organization.appointment_blocked_dates.create!(start_date: blocked, reason: "Bank holiday")

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get portal_appointment_calendar_path(organization_slug: @organization.slug),
        params: { month: blocked.strftime("%Y-%m"), service_id: @service.id }
    end

    assert_response :success
    assert_match(/data-date="#{blocked.iso8601}"\s+data-disabled="true"\s+title="Closed: Bank holiday"/, response.body)
  end

  test "customers cannot book a blocked date" do
    blocked = next_weekday(Date.current + 1.day)
    @organization.appointment_blocked_dates.create!(start_date: blocked, reason: "Bank holiday")

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_no_difference -> { Appointment.count } do
        post portal_appointments_path(organization_slug: @organization.slug), params: {
          appointment: appointment_payload(appointment_date: blocked)
        }
      end
    end

    assert_response :unprocessable_entity
  end

  test "openings mode only offers opening dates in the portal calendar" do
    opening_date = Date.current + 5.days
    @organization.update!(appointment_booking_mode: "openings")
    @organization.appointment_openings.create!(
      start_date: opening_date, end_date: opening_date,
      bookable_times: { Organization.weekday_key(opening_date) => [ { "start" => "10:00", "end" => "11:00" } ] }
    )
    other_date = opening_date - 1.day

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      get portal_appointment_calendar_path(organization_slug: @organization.slug),
        params: { month: opening_date.strftime("%Y-%m"), service_id: @service.id }
    end

    assert_match(/data-date="#{opening_date.iso8601}"\s+data-disabled="false"/, response.body)
    assert_match(/data-date="#{other_date.iso8601}"\s+data-disabled="true"/, response.body) if other_date.month == opening_date.month
  end

  test "openings mode with no openings hides appointment services" do
    @organization.update!(appointment_booking_mode: "openings")

    get portal_root_path(organization_slug: @organization.slug)

    assert_response :success
    assert_match "No appointment services are currently available.", response.body
  end

  private

  def seed_walk_in_upsell_rule!
    enable_public_portal!(@organization, :mobile_service_request)
    accept_portal_privacy!
    walk_in_service = walk_in_service!
    start_walk_in_session!

    @suggested = @organization.services.create!(
      internal_name: "blood_pressure_#{SecureRandom.hex(4)}",
      display_name: "Blood pressure check",
      estimated_duration: 10,
      active: true,
      allows_immediate: true,
      icon: "monitor_heart"
    )

    @organization.upsell_rules.create!(
      name: "Walk-in upsell",
      trigger_service: walk_in_service,
      suggested_service: @suggested,
      frequency_type: "every_nth_customer",
      frequency_value: 2,
      visit_type: "any",
      cooldown_days: 0,
      active: true,
      upsell_templates_attributes: [
        {
          title: "Free BP check",
          description: "Quick check while you wait.",
          cta_text: "Add blood pressure check"
        }
      ]
    )

    walk_in_service
  end

  def join_walk_in_for_upsell!(walk_in_service)
    post portal_walk_in_path(organization_slug: @organization.slug), params: {
      service_request: walk_in_payload(walk_in_service)
    }
    assert_redirected_to portal_walk_in_upsell_path(organization_slug: @organization.slug)
  end

  def walk_in_service!
    @organization.services.create!(
      internal_name: "walk_in_queue_#{SecureRandom.hex(4)}",
      display_name: "Walk-in queue",
      estimated_duration: 10,
      allows_immediate: true,
      active: true,
      calendar: @calendar
    )
  end

  def walk_in_payload(service)
    {
      service_id: service.id,
      first_name: "Jane",
      last_name: "Doe",
      dob: "01-01-1990",
      postcode: "N1 1AA",
      description: "Needs help with prescription"
    }
  end

  def enable_public_portal!(organization, *feature_keys)
    FeatureRegistry.sync!

    portal = Feature.find_by!(key: "public_portal")
    portal.update!(enabled: true, applies_to_all_organizations: true)

    feature_keys.each do |key|
      feature = Feature.find_by!(key: key.to_s)
      feature.update!(enabled: true, applies_to_all_organizations: true)
      organization.update_feature!(key, enabled: true) if feature.org_opt_in_required?
    end
  end

  def start_walk_in_session!
    token = Rails.application.message_verifier("walk-in").generate(
      { "org_id" => @organization.id, "org_slug" => @organization.slug }
    )
    get portal_arrive_path(organization_slug: @organization.slug, token: token)
    assert_response :success
  end

  def accept_portal_privacy!
    get portal_privacy_path(organization_slug: @organization.slug)
    assert_response :success

    post accept_portal_privacy_path(organization_slug: @organization.slug)
    assert_redirected_to portal_root_path(organization_slug: @organization.slug)
    follow_redirect!
  end

  def appointment_payload(appointment_date:)
    {
      service_id: @service.id,
      first_name: "JANE",
      last_name: "DOE",
      dob: "01-01-1990",
      postcode: "N1 1AA",
      appointment_date: appointment_date.iso8601,
      appointment_time: "10:00"
    }
  end

  def next_weekday(date)
    date += 1.day while date.saturday? || date.sunday?
    date
  end
end
