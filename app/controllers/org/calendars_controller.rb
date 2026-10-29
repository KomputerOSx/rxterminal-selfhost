# frozen_string_literal: true

module Org
  class CalendarsController < BaseController
    before_action :authorize_manage
    before_action :set_calendar, only: [ :edit, :update, :archive ]

    def index
      @calendars = Current.organization.calendars.ordered
      @active_count = @calendars.count { |calendar| !calendar.archived? }
    end

    def new
      @calendar = Current.organization.calendars.build
    end

    def create
      return if block_unless_calendars_enabled!

      @calendar = Current.organization.calendars.build(calendar_params)

      if @calendar.save
        log_audit(:calendar_created, resource: @calendar, metadata: { name: @calendar.name })
        redirect_to org_calendars_path, notice: "Calendar created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @calendar.update(calendar_params)
        log_audit(:calendar_updated, resource: @calendar, metadata: {
          name: @calendar.name,
          changed_fields: @calendar.saved_changes.except("updated_at").keys
        })
        redirect_to org_calendars_path, notice: "Calendar updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def archive
      unless @calendar.archivable?
        redirect_to org_calendars_path, alert: "The default calendar cannot be archived." and return
      end

      default_calendar = Current.organization.calendars.active.find_by(is_default: true)

      moved = { openings: 0, blocked_dates: 0 }
      Calendar.transaction do
        if default_calendar
          @calendar.services.find_each { |service| service.move_to_calendar!(default_calendar) }
          moved = @calendar.reassign_booking_schedule_to!(default_calendar)
        end
        @calendar.update!(archived: true)
      end

      log_audit(:calendar_archived, resource: @calendar, metadata: {
        name: @calendar.name,
        moved_openings: moved[:openings],
        moved_blocked_dates: moved[:blocked_dates]
      })
      redirect_to org_calendars_path,
        notice: "Calendar archived.#{" Services, openings and blocked dates moved to #{default_calendar.name}." if default_calendar}"
    end

    private

    def authorize_manage
      authorize Current.organization, :manage?, policy_class: CalendarPolicy
    end

    def set_calendar
      @calendar = Current.organization.calendars.find(params[:id])
    end

    def calendar_params
      params.require(:calendar).permit(:name, :color)
    end
  end
end
