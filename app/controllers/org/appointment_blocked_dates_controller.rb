# frozen_string_literal: true

module Org
  class AppointmentBlockedDatesController < BaseController
    include AppointmentBookingSections

    def create
      blocked_date = Current.organization.appointment_blocked_dates.new(blocked_date_params.merge(source: "manual"))
      calendar_params = booking_calendar_params(:appointment_blocked_date)
      blocked_date.assign_calendars(**calendar_params) if calendar_params

      unless blocked_date.save
        return respond_with_booking_sections(blocked_date.errors.full_messages.to_sentence, status: :unprocessable_entity, blocked_date: blocked_date)
      end

      log_audit(:appointment_blocked_date_created, resource: blocked_date, metadata: blocked_date_metadata(blocked_date))
      respond_with_booking_sections("Blocked date added.")
    end

    def import
      calendar_params = booking_calendar_params(:holiday_import) || { scope: "all", ids: [] }
      calendar_ids = calendar_params[:scope] == "selected" ? calendar_params[:ids].compact_blank.map(&:to_i) : []
      importer = PublicHolidayImporter.new(Current.organization, region: params.dig(:holiday_import, :region), calendar_ids: calendar_ids)
      return respond_with_booking_sections("Choose a country or region.", status: :unprocessable_entity) unless importer.valid_region?
      if calendar_params[:scope] == "selected" && calendar_ids.empty?
        return respond_with_booking_sections("Choose at least one calendar.", status: :unprocessable_entity)
      end
      return respond_with_booking_sections("Calendar is not valid.", status: :unprocessable_entity) unless importer.valid_calendars?

      result = importer.call
      log_audit(:appointment_blocked_dates_imported, resource: Current.organization, metadata: {
        region: params.dig(:holiday_import, :region),
        calendar_ids: calendar_ids,
        created: result.created,
        skipped: result.skipped
      })

      respond_with_booking_sections(import_message(result))
    end

    def destroy
      blocked_date = Current.organization.appointment_blocked_dates.find(params[:id])
      blocked_date.destroy!
      log_audit(:appointment_blocked_date_deleted, resource: blocked_date, metadata: blocked_date_metadata(blocked_date))

      respond_with_booking_sections("Blocked date removed.")
    end

    private

    def blocked_date_params
      params.require(:appointment_blocked_date).permit(:start_date, :end_date, :reason)
    end

    def blocked_date_metadata(blocked_date)
      {
        start_date: blocked_date.start_date.iso8601,
        end_date: blocked_date.end_date.iso8601,
        reason: blocked_date.reason,
        calendar_ids: blocked_date.calendar_ids
      }
    end

    def import_message(result)
      message = "#{result.created} public #{"holiday".pluralize(result.created)} added."
      message += " #{result.skipped} already blocked." if result.skipped.positive?
      message
    end
  end
end
