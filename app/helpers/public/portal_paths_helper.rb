# frozen_string_literal: true

module Public
  module PortalPathsHelper
    def custom_domain_portal_request?
      request.env[CustomDomainResolver::ENV_KEY].present?
    end

    def portal_slug
      @organization.slug
    end

    def portal_root_path(**options)
      portal_path("", **options)
    end

    def portal_privacy_path(**options)
      portal_path("privacy", **options)
    end

    def accept_portal_privacy_path(**options)
      portal_path("privacy/accept", **options)
    end

    def portal_arrive_path(**options)
      portal_path("arrive", **options)
    end

    # Where the navbar org name / a page's "Back" button should return to: the QR-scanned
    # arrival route while that walk-in session is still active (started via the QR code and
    # not yet 30 minutes old), otherwise the plain portal root.
    def portal_back_path(**options)
      walk_in_session_active? ? portal_arrive_path(**options) : portal_root_path(**options)
    end

    def walk_in_session_active?
      session[:walk_in_org_id] == @organization&.id &&
        session[:walk_in_expires_at].present? &&
        Time.zone.parse(session[:walk_in_expires_at]) > Time.current
    rescue ArgumentError, TypeError
      false
    end

    def new_portal_walk_in_path(**options)
      portal_path("walk-in", **options)
    end

    def portal_walk_in_path(**options)
      portal_path("walk-in", **options)
    end

    def portal_walk_in_success_path(**options)
      portal_path("walk-in/success", **options)
    end

    def portal_walk_in_my_queue_path(**options)
      portal_path("walk-in/my-queue", **options)
    end

    def new_portal_appointment_checkin_path(**options)
      portal_path("appointment-checkin", **options)
    end

    def portal_appointment_checkin_path(**options)
      portal_path("appointment-checkin", **options)
    end

    def portal_appointment_checkin_early_path(**options)
      portal_path("appointment-checkin/early", **options)
    end

    def portal_appointment_checkin_late_path(**options)
      portal_path("appointment-checkin/late", **options)
    end

    def portal_walk_in_upsell_path(**options)
      portal_path("walk-in/upsell", **options)
    end

    def accept_portal_walk_in_upsell_path(**options)
      portal_path("walk-in/upsell/accept", **options)
    end

    def book_later_portal_walk_in_upsell_path(**options)
      portal_path("walk-in/upsell/book-later", **options)
    end

    def decline_portal_walk_in_upsell_path(**options)
      portal_path("walk-in/upsell/decline", **options)
    end

    def confirmed_portal_walk_in_upsell_path(**options)
      portal_path("walk-in/upsell/confirmed", **options)
    end

    def portal_privacy_policy_path(**options)
      portal_path("privacy-policy", **options)
    end

    def portal_gdpr_path(**options)
      portal_path("gdpr", **options)
    end

    def portal_terms_path(**options)
      portal_path("terms", **options)
    end

    def portal_cookies_path(**options)
      portal_path("cookies", **options)
    end

    def portal_opening_times_path(**options)
      portal_path("opening-times", **options)
    end

    def portal_contact_path(**options)
      portal_path("contact", **options)
    end

    def new_portal_appointment_path(**options)
      portal_path("appointments/new", **options)
    end

    def portal_appointments_path(**options)
      portal_path("appointments", **options)
    end

    def portal_appointment_confirmed_path(**options)
      portal_path("appointments/confirmed", **options)
    end

    def portal_appointment_ics_path(appointment, **options)
      portal_path("appointments/#{appointment.id}/calendar.ics", **options)
    end

    def portal_appointment_calendar_path(**options)
      portal_path("appointments/calendar", **options)
    end

    def portal_appointment_slots_path(**options)
      portal_path("appointments/slots", **options)
    end

    private

    def portal_path(suffix, **options)
      base = custom_domain_portal_request? ? "" : "/#{portal_slug}"
      path = [ base, suffix ].reject(&:blank?).join("/")
      path = "/#{path.delete_prefix("/")}"
      query = options.except(:only_path).to_query
      query.present? ? "#{path}?#{query}" : path
    end
  end
end
