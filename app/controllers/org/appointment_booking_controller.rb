# frozen_string_literal: true

module Org
  class AppointmentBookingController < BaseController
    include PortalConfigParams
    include AppointmentBookingSections

    def show
      @conflicting_appointments = BookingSchedule.conflicting_appointments(Current.organization)
    end

    def update
      attributes = appointment_booking_scalar_params.to_h
      attributes[:bookable_times] = build_bookable_times_from_params if params.dig(:organization, :bookable_times).present?

      if Current.organization.update(attributes)
        log_audit(:organization_updated, resource: Current.organization, metadata: {
          changed_fields: Current.organization.saved_changes.except("updated_at").keys,
          section: "appointment_booking"
        })
        conflicts = BookingSchedule.conflicting_appointments(Current.organization)
        if conflicts.any?
          flash[:toast] = { message: "Appointment booking settings updated. #{conflict_message(conflicts.size)}", type: "warning" }
          redirect_to org_appointment_booking_path
        else
          redirect_to org_appointment_booking_path, notice: "Appointment booking settings updated."
        end
      else
        @conflicting_appointments = BookingSchedule.conflicting_appointments(Organization.find(Current.organization.id))
        render :show, status: :unprocessable_entity
      end
    end
  end
end
