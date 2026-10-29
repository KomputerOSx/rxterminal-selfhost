# frozen_string_literal: true

module Org
  module AppointmentBookingSections
    extend ActiveSupport::Concern

    included do
      before_action :authorize_booking_configuration
      before_action(unless: -> { action_name == "show" }) { block_unless_appointments_enabled! }
    end

    private

    def authorize_booking_configuration
      authorize Current.organization, :update?, policy_class: PortalConfigPolicy
    end

    def booking_calendar_params(key)
      return nil if params.dig(key, :calendar_scope).blank?

      {
        scope: params.dig(key, :calendar_scope).presence || "all",
        ids: Array(params.dig(key, :calendar_ids))
      }
    end

    def respond_with_booking_sections(message, status: :ok, blocked_date: nil)
      conflicts = BookingSchedule.conflicting_appointments(Current.organization)
      type = status == :ok ? "success" : "error"
      if status == :ok && conflicts.any?
        type = "warning"
        message = "#{message} #{conflict_message(conflicts.size)}"
      end

      respond_to do |format|
        format.turbo_stream do
          flash.now[:toast] = { message: message, type: type }
          render status: status, turbo_stream: [
            turbo_stream.replace("appointment_openings_section", partial: "org/appointment_booking/openings",
              locals: { organization: Current.organization }),
            turbo_stream.replace("appointment_blocked_dates_section", partial: "org/appointment_booking/blocked_dates",
              locals: { organization: Current.organization, blocked_date: blocked_date }),
            turbo_stream.replace("appointment_booking_conflicts", partial: "org/appointment_booking/conflicts",
              locals: { appointments: conflicts }),
            turbo_stream.update("flash_messages", partial: "shared/flash")
          ]
        end
        format.html do
          if status == :ok
            redirect_to org_appointment_booking_path, notice: message
          else
            redirect_to org_appointment_booking_path, alert: message
          end
        end
      end
    end

    def conflict_message(count)
      "#{count} booked #{"appointment".pluralize(count)} #{count == 1 ? "falls" : "fall"} outside your booking schedule."
    end
  end
end
