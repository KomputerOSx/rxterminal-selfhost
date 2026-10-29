# frozen_string_literal: true

module Org
  class AppointmentOpeningsController < BaseController
    include PortalConfigParams
    include AppointmentBookingSections

    before_action :set_opening, only: [ :edit, :update, :destroy ]

    def new
      @opening = Current.organization.appointment_openings.new
    end

    def create
      @opening = Current.organization.appointment_openings.new(opening_attributes(base: Current.organization.bookable_times))
      assign_opening_calendars

      if @opening.save
        log_audit(:appointment_opening_created, resource: @opening, metadata: opening_metadata(@opening))
        redirect_after_save("Opening added.")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @opening.assign_attributes(opening_attributes(base: @opening.bookable_times))
      assign_opening_calendars

      if @opening.save
        log_audit(:appointment_opening_updated, resource: @opening, metadata: opening_metadata(@opening).merge(
          changed_fields: @opening.saved_changes.except("updated_at").keys
        ))
        redirect_after_save("Opening updated.")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @opening.destroy!
      log_audit(:appointment_opening_deleted, resource: @opening, metadata: opening_metadata(@opening))

      respond_with_booking_sections("Opening removed.")
    end

    private

    def set_opening
      @opening = Current.organization.appointment_openings.find(params[:id])
    end

    def opening_attributes(base:)
      params.require(:appointment_opening).permit(:name, :start_date, :end_date).merge(
        bookable_times: build_bookable_times_from_params(scope: :appointment_opening, base: base)
      )
    end

    def assign_opening_calendars
      calendar_params = booking_calendar_params(:appointment_opening)
      @opening.assign_calendars(**calendar_params) if calendar_params
    end

    def redirect_after_save(message)
      conflicts = BookingSchedule.conflicting_appointments(Current.organization)
      if conflicts.any?
        flash[:toast] = { message: "#{message} #{conflict_message(conflicts.size)}", type: "warning" }
        redirect_to org_appointment_booking_path
      else
        redirect_to org_appointment_booking_path, notice: message
      end
    end

    def opening_metadata(opening)
      {
        name: opening.name,
        start_date: opening.start_date&.iso8601,
        end_date: opening.end_date&.iso8601,
        calendar_ids: opening.calendar_ids
      }
    end
  end
end
