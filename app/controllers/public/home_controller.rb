# frozen_string_literal: true

module Public
  class HomeController < BaseController
    skip_before_action :require_privacy_accepted

    def index
      @services = if @organization.online_appointment_booking_enabled?
        @organization.services.visible.active.where(requires_appointment: true).order(:display_name)
      else
        Service.none
      end
      @services = services_with_openings(@services) if @organization.booking_mode_openings?
    end

    private

    def portal_indexable?
      true
    end

    def services_with_openings(services)
      upcoming = @organization.appointment_openings.upcoming
      return services if upcoming.all_calendars.exists?

      services.where(calendar_id: AppointmentOpeningCalendar.where(appointment_opening_id: upcoming.select(:id)).select(:calendar_id))
    end
  end
end
