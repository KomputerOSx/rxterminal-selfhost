# frozen_string_literal: true

module Org
  class AppointmentsController < BaseController
    before_action :authorize_view, only: [ :index, :show, :slots, :search, :print ]
    before_action :authorize_manage, only: [ :new, :create, :edit, :update, :check_in, :cancel, :no_show, :resend_confirmation, :return_to_booked ]
    before_action :set_appointment, only: [ :show, :edit, :update, :check_in, :cancel, :no_show, :resend_confirmation, :return_to_booked ]
    before_action :load_services, only: [ :new, :create, :edit, :update ]
    before_action :ensure_editable, only: [ :edit, :update ]

    CALENDAR_VIEWS = %w[day week month].freeze

    def index
      @view = CALENDAR_VIEWS.include?(params[:view]) ? params[:view] : "day"
      @date = parse_date_param(params[:date]) || Date.current
      @calendars = Current.organization.calendars.active.ordered.to_a
      @calendar = params[:calendar_id].present? ? @calendars.find { |calendar| calendar.id == params[:calendar_id].to_i } : nil
      @period = calendar_period(@view, @date)
      @range = calendar_range(@view, @period)
      @appointments = filtered_appointments(@range).to_a
      @appointments_by_date = @appointments.group_by(&:appointment_date)
      @status_counts = Appointment::STATUSES.index_with(0)
      @appointments.each { |appointment| @status_counts[appointment.status] += 1 if @period.cover?(appointment.appointment_date) }
      @period_total = @status_counts.values.sum
      @closures = Current.organization.booking_schedule(calendar: @calendar).closures_in(@range)
    end

    def show
      @return_params = calendar_return_params.merge(date: (parse_date_param(params[:date]) || @appointment.appointment_date).iso8601)
    end

    def new
      @appointment = build_appointment_from_prefill
    end

    def create
      return if block_unless_appointments_enabled!

      @appointment = Current.organization.appointments.build(appointment_params)
      apply_customer_normalization(@appointment)
      @appointment.status = "booked"

      if @appointment.save_with_slot_protection
        AppointmentMailer.booking_confirmation(@appointment).deliver_later if @appointment.email.present?
        log_audit(:appointment_created, resource: @appointment, metadata: {
          booking_reference: @appointment.booking_reference,
          service_id: @appointment.service_id
        })
        redirect_to org_appointment_path(@appointment), notice: "Appointment booked."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attrs = appointment_params
      attrs[:first_name] = attrs[:first_name]&.upcase
      attrs[:last_name] = attrs[:last_name]&.upcase
      attrs[:postcode] = attrs[:postcode]&.upcase
      attrs[:email] = attrs[:email]&.downcase&.strip

      if @appointment.update_with_slot_protection(attrs)
        log_audit(:appointment_updated, resource: @appointment, metadata: {
          booking_reference: @appointment.booking_reference,
          changed_fields: @appointment.saved_changes.except("updated_at").keys
        })
        redirect_to org_appointment_path(@appointment), notice: "Appointment updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def slots
      service = Current.organization.services.visible.find(params[:service_id])
      date = parse_date_param(params[:date])
      return head :unprocessable_entity unless date

      slots = SlotAvailabilityService.new(
        Current.organization,
        service,
        date,
        exclude_appointment_id: params[:exclude_id]
      ).available_slots

      closure = Current.organization.booking_schedule(calendar: service.calendar).blocked_date_for(date)

      render partial: "org/appointments/slots",
        locals: { slots: slots, selected_time: params[:selected_time], closure: closure }
    end

    def search
      query = params[:q].to_s.strip
      @results = appointment_search_results(query)
      render partial: "org/appointments/search_results", locals: { results: @results, query: query, return_params: calendar_return_params }
    end

    def print
      @date = parse_date_param(params[:date]) || Date.current
      @service = params[:service_id].present? ? Current.organization.services.visible.active.find_by(id: params[:service_id]) : nil
      @calendar = params[:calendar_id].present? ? Current.organization.calendars.active.find_by(id: params[:calendar_id]) : nil
      @appointments = filtered_appointments(@date..@date)
      render layout: "print"
    end

    def check_in
      unless @appointment.status == "booked" && @appointment.appointment_date == Date.current
        redirect_to org_appointment_path(@appointment), alert: "Only today's booked appointments can be checked in."
        return
      end

      service_request = @appointment.check_in!
      log_audit(:appointment_checked_in, resource: @appointment, metadata: {
        booking_reference: @appointment.booking_reference,
        queue_number: service_request.queue_number
      })
      redirect_to org_queue_path, notice: "Checked in. Queue ##{service_request.queue_number}."
    end

    def cancel
      unless @appointment.status == "booked"
        redirect_to org_appointment_path(@appointment), alert: "Only booked appointments can be cancelled."
        return
      end

      @appointment.cancel!(reason: params[:cancellation_reason])
      AppointmentMailer.cancellation(@appointment).deliver_later if @appointment.email.present?
      log_audit(:appointment_cancelled, resource: @appointment, metadata: {
        booking_reference: @appointment.booking_reference,
        reason_given: @appointment.cancellation_reason.present?
      })
      redirect_to org_appointments_path(date: @appointment.appointment_date), notice: "Appointment cancelled."
    end

    def no_show
      unless @appointment.status == "booked"
        redirect_to org_appointment_path(@appointment), alert: "Only booked appointments can be marked as no-show."
        return
      end

      @appointment.mark_no_show!
      log_audit(:appointment_no_show, resource: @appointment, metadata: {
        booking_reference: @appointment.booking_reference
      })
      redirect_to org_appointments_path(date: @appointment.appointment_date), notice: "Appointment marked as no-show."
    end

    def return_to_booked
      unless @appointment.status == "checked_in"
        redirect_to org_appointment_path(@appointment), alert: "Only checked-in appointments can be returned to booked."
        return
      end

      previous_queue_number = @appointment.service_request&.queue_number

      @appointment.revert_to_booked!
      log_audit(:appointment_reverted_to_booked, resource: @appointment, metadata: {
        booking_reference: @appointment.booking_reference,
        previous_queue_number: previous_queue_number
      })
      redirect_to org_appointment_path(@appointment), notice: "Appointment returned to booked."
    rescue Appointment::RevertNotAllowedError => e
      redirect_to org_appointment_path(@appointment), alert: e.message
    end

    def resend_confirmation
      if @appointment.email.present?
        AppointmentMailer.booking_confirmation(@appointment).deliver_later
        redirect_to org_appointment_path(@appointment), notice: "Confirmation email resent."
      else
        redirect_to org_appointment_path(@appointment), alert: "No email address on this appointment."
      end
    end

    private

    def authorize_view
      authorize Current.organization, :index?, policy_class: AppointmentPolicy
    end

    def authorize_manage
      authorize Current.organization, :manage?, policy_class: AppointmentPolicy
    end

    def set_appointment
      @appointment = Current.organization.appointments.find(params[:id])
    end

    def ensure_editable
      return if @appointment.editable_by_staff?

      redirect_to org_appointment_path(@appointment), alert: "This appointment can no longer be edited."
    end

    def load_services
      @services = Current.organization.services.active.visible.by_display_order
    end

    def build_appointment_from_prefill
      appointment = Current.organization.appointments.build(status: "booked")

      if params[:service_id].present?
        appointment.service_id = params[:service_id]
      end

      if params[:date].present?
        appointment.appointment_date = parse_date_param(params[:date])
      end

      if params[:service_request_id].present?
        service_request = Current.organization.service_requests.find_by(id: params[:service_request_id])
        if service_request
          appointment.first_name = service_request.first_name
          appointment.last_name = service_request.last_name
          appointment.dob = service_request.dob
          appointment.postcode = service_request.postcode
          appointment.notes = service_request.description
        end
      end

      @prefill_queue_number = params[:queue_number]
      appointment
    end

    def appointment_params
      permitted = params.require(:appointment).permit(
        :service_id,
        :first_name,
        :last_name,
        :dob,
        :postcode,
        :email,
        :notes,
        :appointment_date,
        :appointment_time
      )

      permitted[:dob] = DateOfBirthParser.parse(permitted[:dob]) if permitted.key?(:dob)
      permitted[:appointment_date] = parse_date_param(permitted[:appointment_date]) if permitted.key?(:appointment_date)
      permitted[:appointment_time] = parse_time_param(permitted[:appointment_time]) if permitted.key?(:appointment_time)
      permitted
    end

    def apply_customer_normalization(appointment)
      appointment.first_name = appointment.first_name&.upcase
      appointment.last_name = appointment.last_name&.upcase
      appointment.postcode = appointment.postcode&.upcase
      appointment.email = appointment.email&.downcase&.strip
    end

    def parse_date_param(value)
      return nil if value.blank?

      if value.is_a?(Date)
        value
      elsif value.match?(/\A\d{2}-\d{2}-\d{4}\z/)
        Date.strptime(value, "%d-%m-%Y")
      else
        Date.parse(value)
      end
    rescue ArgumentError
      nil
    end

    def parse_time_param(value)
      return nil if value.blank?

      Time.zone.parse("2000-01-01 #{value}")
    rescue ArgumentError
      nil
    end

    def calendar_return_params
      calendar_id = Current.organization.calendars.active.where(id: params[:calendar_id]).pick(:id) if params[:calendar_id].present?

      { view: CALENDAR_VIEWS.include?(params[:view]) ? params[:view] : nil, calendar_id: calendar_id }.compact
    end

    def calendar_period(view, date)
      case view
      when "week" then date.beginning_of_week(:monday)..date.end_of_week(:monday)
      when "month" then date.beginning_of_month..date.end_of_month
      else date..date
      end
    end

    def calendar_range(view, period)
      return period unless view == "month"

      period.first.beginning_of_week(:monday)..period.last.end_of_week(:monday)
    end

    def filtered_appointments(range)
      appointments = Current.organization.appointments
        .where(appointment_date: range)
        .includes(:service, :calendar)
        .order(:appointment_date, :appointment_time)
      appointments = appointments.where(service_id: params[:service_id]) if params[:service_id].present?
      appointments = appointments.where(calendar_id: @calendar.id) if @calendar
      appointments
    end

    def appointment_search_results(query)
      return [] if query.length < 2

      normalized_query = query.upcase
      scope = Current.organization.appointments.not_redacted
        .includes(:service)
        .order(appointment_date: :desc, appointment_time: :desc)
        .limit(200)

      scope.select do |appointment|
        appointment.booking_reference.upcase.include?(normalized_query) ||
          "#{appointment.first_name} #{appointment.last_name}".upcase.include?(normalized_query)
      end.first(8)
    end
  end
end
