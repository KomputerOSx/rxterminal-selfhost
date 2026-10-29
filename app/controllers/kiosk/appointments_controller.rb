# frozen_string_literal: true

module Kiosk
  class AppointmentsController < BaseController
    include KioskAuthentication

    before_action :load_upsell_booking_context, only: [ :new, :create, :cancel_upsell_booking ]

    def new
      @appointment = Appointment.new
      @preselected_service_id = (@upsell_booking_service&.id || params[:service_id])&.to_i
      @selected_service = @organization.services.visible.active.find_by(id: @preselected_service_id) if @preselected_service_id

      unless @selected_service
        redirect_to kiosk_services_path, alert: "Service not found or not available"
        return
      end

      @booking_schedule = @organization.booking_schedule(calendar: @selected_service.calendar)
      @appointment_month = parsed_month || default_booking_month(@booking_schedule)
      prepare_appointment_flow_state
    end

    def calendar
      service = @organization.services.visible.active.find_by(id: params[:service_id])
      schedule = @organization.booking_schedule(calendar: service&.calendar)
      selected_date = parsed_date_param(params[:selected_date])

      render partial: "kiosk/appointments/appointment_calendar",
        locals: {
          month_date: parsed_month || default_booking_month(schedule),
          selected_date: selected_date,
          schedule: schedule
        }
    end

    def slot_options
      service = @organization.services.visible.active.find_by(id: params[:service_id])
      date = parsed_date_param(params[:date])
      slots = service && date ? SlotAvailabilityService.new(@organization, service, date).available_slots : []

      render partial: "kiosk/appointments/appointment_slots",
        locals: {
          appointment_date: date,
          slots: slots,
          selected_slot: params[:selected_slot].presence
        }
    end

    def check_in_candidates
      candidates = AppointmentCheckInService.find_candidates(
        organization: @organization,
        last_name: params[:last_name],
        dob: parse_dob(params[:dob])
      )

      if candidates.empty?
        head :not_found
        return
      end

      render partial: "kiosk/appointments/check_in_candidates", locals: { candidates: candidates }
    end

    def create
      if kiosk_preview_mode?
        handle_preview_create
        return
      end

      @appointment = @organization.appointments.build(build_appointment_attributes)
      apply_customer_normalization(@appointment)
      @appointment.status = "booked"

      if @appointment.save_with_slot_protection
        AppointmentMailer.booking_confirmation(@appointment).deliver_later if @appointment.email.present?
        session[:last_booked_appointment_id] = @appointment.id
        session[:last_booked_appointment_at] = Time.current.to_i

        redirect_path = if @upsell_booking_context
          session[:upsell_booking_confirmation] = {
            appointment_id: @appointment.id,
            original_queue_number: @upsell_booking_queue_number,
            original_service_name: @upsell_booking_original_request&.service&.display_name,
            booked_at: Time.current.to_i
          }
          clear_active_upsell_booking_session
          kiosk_upsell_booking_confirmation_path
        else
          kiosk_appointment_confirmation_path(@appointment)
        end

        render json: { redirect_to: redirect_path }
      else
        render json: { errors: @appointment.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def confirmation
      if kiosk_preview_mode? && session[:last_booked_appointment_id] == KioskPreviewMode::PREVIEW_APPOINTMENT_ID
        @appointment = Kiosk::PreviewAppointment.new(session[:kiosk_preview_appointment] || {})
        return if session[:kiosk_preview_appointment].present?

        redirect_to kiosk_root_path
        return
      end

      @appointment = Appointment.find_by(id: params[:id], organization: @organization)
      booked_at = session[:last_booked_appointment_at].to_i
      valid = @appointment &&
        @appointment.id == session[:last_booked_appointment_id] &&
        booked_at.positive? &&
        Time.current.to_i - booked_at < 10.minutes.to_i

      redirect_to kiosk_root_path unless valid
    end

    def upsell_booking_confirmation
      confirmation = session.delete(:upsell_booking_confirmation) || {}

      if kiosk_preview_mode? && confirmation[:preview]
        @appointment = Kiosk::PreviewAppointment.new(confirmation[:appointment] || confirmation["appointment"] || {})
        @queue_number = confirmation[:original_queue_number] || confirmation["original_queue_number"]
        @original_service_name = confirmation[:original_service_name] || confirmation["original_service_name"]
        return
      end

      appointment_id = confirmation[:appointment_id] || confirmation["appointment_id"]
      booked_at = (confirmation[:booked_at] || confirmation["booked_at"]).to_i

      @appointment = Appointment.find_by(id: appointment_id, organization: @organization)
      valid = @appointment && booked_at.positive? && Time.current.to_i - booked_at < 10.minutes.to_i

      unless valid
        redirect_after_invalid_upsell_booking(
          queue_number: confirmation[:original_queue_number] || confirmation["original_queue_number"],
          service_name: confirmation[:original_service_name] || confirmation["original_service_name"]
        )
        return
      end

      @queue_number = confirmation[:original_queue_number] || confirmation["original_queue_number"]
      @original_service_name = confirmation[:original_service_name] || confirmation["original_service_name"]
    end

    def cancel_upsell_booking
      unless @upsell_booking_context
        redirect_after_invalid_upsell_booking and return
      end

      session[:upsell_confirmed_numbers] = [ @upsell_booking_queue_number ].compact
      session[:upsell_confirmed_services] = [ @upsell_booking_original_request&.service&.display_name ].compact
      clear_upsell_booking_session
      redirect_to kiosk_confirmed_upsell_path
    end

    def check_in
    end

    def process_check_in
      if kiosk_preview_mode?
        session[:appointment_queue_number] = preview_queue_number
        redirect_to kiosk_appointment_checked_in_path
        return
      end

      @check_in_mode = params[:last_name].present? ? "details" : "reference"
      @appointment = params[:appointment_id].present? ? find_selected_candidate : find_reference_appointment

      unless @appointment
        flash.now[:alert] = "Appointment not found. Please check your details and try again."
        render :check_in, status: :unprocessable_entity
        return
      end

      if @appointment.status == "checked_in"
        flash.now[:alert] = "This appointment has already been checked in."
        render :check_in, status: :unprocessable_entity
        return
      end

      if @appointment.status.in?(%w[cancelled no_show])
        flash.now[:alert] = "This appointment has been #{@appointment.status.humanize.downcase}."
        render :check_in, status: :unprocessable_entity
        return
      end

      if @appointment.appointment_date > Date.current
        render :early and return
      end

      if @appointment.appointment_date < Date.current
        render :late and return
      end

      service_request = @appointment.check_in!
      log_kiosk_audit(
        :appointment_checked_in,
        resource: @appointment,
        metadata: {
          booking_reference: @appointment.booking_reference,
          queue_number: service_request.queue_number,
          device_id: current_device.device_id
        }
      )

      session[:appointment_queue_number] = service_request.queue_number
      redirect_to kiosk_appointment_checked_in_path
    end

    def checked_in
      @queue_number = session.delete(:appointment_queue_number)
      redirect_to kiosk_root_path unless @queue_number
    end

    private

    def find_reference_appointment
      AppointmentCheckInService.find_by_reference(@organization, params[:booking_reference])
    end

    # Re-derive candidates server-side from the submitted last_name/dob rather than trusting
    # appointment_id alone, so a tampered/stale id can't check in an unrelated appointment,
    # and a race (someone else already checked this appointment in) is naturally caught by
    # the status guards below.
    def find_selected_candidate
      AppointmentCheckInService.find_candidates(
        organization: @organization,
        last_name: params[:last_name],
        dob: parse_dob(params[:dob])
      ).find { |appointment| appointment.id == params[:appointment_id].to_i }
    end

    def log_kiosk_audit(event_type, resource: nil, metadata: {})
      log_audit(event_type, user: nil, resource: resource, organization: @organization, metadata: metadata)
    end

    def appointment_params
      permitted = params.require(:appointment).permit(
        :service_id, :first_name, :last_name, :dob, :postcode,
        :email, :appointment_date, :appointment_time, :notes
      )

      permitted[:dob] = parse_dob(permitted[:dob]) if permitted.key?(:dob)
      permitted[:appointment_date] = parsed_date_param(permitted[:appointment_date]) if permitted.key?(:appointment_date)
      permitted[:appointment_time] = parse_time_param(permitted[:appointment_time]) if permitted.key?(:appointment_time)
      permitted
    end

    def build_appointment_attributes
      attrs = appointment_params.to_h

      if @upsell_booking_context
        attrs.merge!(
          "service_id" => @upsell_booking_service.id,
          "first_name" => @upsell_booking_original_request.first_name,
          "last_name" => @upsell_booking_original_request.last_name,
          "dob" => @upsell_booking_original_request.dob
        )
        if @organization.kiosk_collect_postcode?
          attrs["postcode"] = @upsell_booking_original_request.postcode
        end
      end

      attrs
    end

    def apply_customer_normalization(appointment)
      appointment.first_name = appointment.first_name&.upcase
      appointment.last_name = appointment.last_name&.upcase
      appointment.postcode = appointment.postcode&.upcase
      appointment.email = appointment.email&.downcase&.strip
    end

    def prepare_appointment_flow_state
      @upsell_booking_mode = @upsell_booking_context.present?
      @appointment_start_step = if @upsell_booking_mode
        "appointment"
      elsif @selected_service&.eligibility_requirements?
        "eligibility"
      else
        "appointment"
      end
      @prefill_first_name = @upsell_booking_original_request&.first_name
      @prefill_last_name = @upsell_booking_original_request&.last_name
      @prefill_dob = @upsell_booking_original_request&.dob&.iso8601
      @prefill_postcode = @organization.kiosk_collect_postcode? ? @upsell_booking_original_request&.postcode : nil
    end

    def parse_dob(value)
      return nil if value.blank?

      Date.parse(value)
    rescue ArgumentError
      nil
    end

    def parsed_month
      return if params[:month].blank?

      Date.strptime(params[:month], "%Y-%m").beginning_of_month
    rescue ArgumentError
      nil
    end

    def default_booking_month(schedule)
      (schedule.first_bookable_date || Date.current).beginning_of_month
    end

    def parsed_date_param(raw)
      return if raw.blank?

      Date.parse(raw)
    rescue ArgumentError
      nil
    end

    def parse_time_param(value)
      return nil if value.blank?

      Time.zone.parse("2000-01-01 #{value}")
    rescue ArgumentError
      nil
    end

    def load_upsell_booking_context
      @upsell_booking_context = session[:upsell_booking]
      return if @upsell_booking_context.blank?

      original_service_request_id = @upsell_booking_context[:original_service_request_id] ||
        @upsell_booking_context["original_service_request_id"]
      upsold_service_id = @upsell_booking_context[:upsold_service_id] ||
        @upsell_booking_context["upsold_service_id"]
      @upsell_booking_queue_number = @upsell_booking_context[:original_queue_number] ||
        @upsell_booking_context["original_queue_number"]

      if preview_upsell_booking?(@upsell_booking_context)
        walk_in = @upsell_booking_context[:walk_in] || @upsell_booking_context["walk_in"]
        @upsell_booking_original_request = Kiosk::PreviewWalkIn.new(walk_in, organization: @organization)
        @upsell_booking_service = @organization.services.visible.active.find_by(id: upsold_service_id)
        return if @upsell_booking_original_request && @upsell_booking_service

        clear_active_upsell_booking_session
        redirect_after_invalid_upsell_booking(queue_number: @upsell_booking_queue_number)
        return
      end

      @upsell_booking_original_request = ServiceRequest.find_by(
        id: original_service_request_id,
        organization: @organization
      )
      @upsell_booking_service = @organization.services.visible.active.find_by(id: upsold_service_id)

      return if @upsell_booking_original_request && @upsell_booking_service

      clear_active_upsell_booking_session
      redirect_after_invalid_upsell_booking(queue_number: @upsell_booking_queue_number)
    end

    def redirect_after_invalid_upsell_booking(queue_number: nil, service_name: nil)
      if queue_number.present?
        session[:upsell_confirmed_numbers] = [ queue_number ]
        session[:upsell_confirmed_services] = [ service_name ].compact
        redirect_to kiosk_confirmed_upsell_path
      else
        redirect_to kiosk_root_path
      end
    end

    def clear_upsell_booking_session
      clear_active_upsell_booking_session
      session.delete(:upsell_booking_confirmation)
    end

    def clear_active_upsell_booking_session
      session.delete(:upsell_booking)
    end

    def preview_upsell_booking?(context)
      ActiveModel::Type::Boolean.new.cast(context[:preview] || context["preview"])
    end

    def handle_preview_create
      service = @organization.services.visible.active.find_by(id: appointment_params[:service_id])
      appointment_date = appointment_params[:appointment_date]
      appointment_time = appointment_params[:appointment_time]
      preview_data = {
        service_name: service&.display_name || "Appointment",
        formatted_date: appointment_date.is_a?(Date) ? appointment_date.strftime("%A %-d %B %Y") : appointment_date.to_s,
        formatted_time: format_preview_time(appointment_time),
        booking_reference: preview_booking_reference
      }
      session[:kiosk_preview_appointment] = preview_data
      session[:last_booked_appointment_id] = KioskPreviewMode::PREVIEW_APPOINTMENT_ID
      session[:last_booked_appointment_at] = Time.current.to_i

      redirect_path = if @upsell_booking_context
        session[:upsell_booking_confirmation] = {
          preview: true,
          appointment: preview_data,
          original_queue_number: @upsell_booking_queue_number,
          original_service_name: @upsell_booking_original_request&.service&.display_name,
          booked_at: Time.current.to_i
        }
        clear_active_upsell_booking_session
        kiosk_upsell_booking_confirmation_path
      else
        kiosk_appointment_confirmation_path(KioskPreviewMode::PREVIEW_APPOINTMENT_ID)
      end

      render json: { redirect_to: redirect_path }
    end

    def format_preview_time(value)
      return value.to_s if value.blank?

      time = value.is_a?(Time) ? value : Time.zone.parse("2000-01-01 #{value}")
      time.strftime("%-I:%M %p")
    rescue ArgumentError
      value.to_s
    end
  end
end
