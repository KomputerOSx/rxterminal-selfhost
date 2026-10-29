# frozen_string_literal: true

module Public
  class AppointmentsController < BaseController
    before_action :require_online_appointment_booking_feature
    before_action(only: [ :new, :calendar, :slot_options, :create ]) { block_unless_appointments_enabled!(public_facing: true) }

    def new
      @appointment = Appointment.new
      @display_dob = nil

      if (prefill = session.delete(:walk_in_prefill))
        @appointment.first_name = prefill["first_name"]
        @appointment.last_name = prefill["last_name"]
        @appointment.dob = Date.parse(prefill["dob"]) if prefill["dob"].present?
        @appointment.postcode = prefill["postcode"]
      end

      @walk_in_queue_number = session[:walk_in_queue_number_carry]
      @walk_in_queue_service = session[:walk_in_queue_service_carry]
      @preselected_service_id = params[:service_id]&.to_i
      @selected_service = @organization.services.visible.active.find_by(id: @preselected_service_id) if @preselected_service_id
      assign_appointment_form_state
    end

    def calendar
      service = @organization.services.visible.active.find_by(id: params[:service_id])
      schedule = @organization.booking_schedule(calendar: service&.calendar)
      selected_date = parsed_date_param(params[:selected_date])

      render partial: "public/appointments/calendar",
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

      render partial: "public/appointments/slots",
        locals: {
          appointment_date: date,
          slots: slots,
          selected_slot: params[:selected_slot].presence
        }
    end

    def ics
      appointment = Appointment.find_by(id: params[:id], organization: @organization)
      head :not_found and return unless appointment

      send_data AppointmentCalendarExport.generate(appointment),
        filename: AppointmentCalendarExport.filename(appointment),
        type: "text/calendar",
        disposition: "attachment"
    end

    def create
      submitted = appointment_params
      @display_dob = submitted[:dob]

      @appointment = Appointment.new(submitted)
      @appointment.organization = @organization
      normalize_appointment_fields(@appointment)

      if honeypot_triggered?
        redirect_to portal_appointment_confirmed_path and return
      end

      if @appointment.save_with_slot_protection
        AppointmentMailer.booking_confirmation(@appointment).deliver_later if @appointment.email.present?
        log_audit(:appointment_booked_online, resource: @appointment, metadata: {
          booking_reference: @appointment.booking_reference,
          service: @appointment.service.display_name,
          date: @appointment.appointment_date.to_s
        })
        session[:public_last_booked_appointment_id] = @appointment.id
        session[:public_last_booked_appointment_at] = Time.current.to_i
        redirect_to portal_appointment_confirmed_path
      else
        @preselected_service_id = submitted[:service_id]&.to_i
        @selected_service = @organization.services.visible.active.find_by(id: @preselected_service_id) if @preselected_service_id
        @walk_in_queue_number = session[:walk_in_queue_number_carry]
        @walk_in_queue_service = session[:walk_in_queue_service_carry]
        assign_appointment_form_state
        render :new, status: :unprocessable_entity
      end
    end

    def confirmed
      @appointment = Appointment.find_by(id: session[:public_last_booked_appointment_id], organization: @organization)
      booked_at = session[:public_last_booked_appointment_at].to_i

      valid = @appointment &&
        booked_at.positive? &&
        Time.current.to_i - booked_at < 10.minutes.to_i

      redirect_to portal_root_path unless valid

      session.delete(:public_last_booked_appointment_id)
      session.delete(:public_last_booked_appointment_at)

      @walk_in_queue_number = session.delete(:walk_in_queue_number_carry)
      @walk_in_queue_service = session.delete(:walk_in_queue_service_carry)
    end

    private

    def require_online_appointment_booking_feature
      redirect_to portal_root_path unless @organization.online_appointment_booking_enabled?
    end

    def appointment_params
      params.require(:appointment).permit(
        :service_id, :first_name, :last_name, :dob, :postcode,
        :email, :appointment_date, :appointment_time, :notes
      )
    end

    def normalize_appointment_fields(appointment)
      appointment.first_name = appointment.first_name&.upcase
      appointment.last_name = appointment.last_name&.upcase
      appointment.postcode = appointment.postcode&.upcase
      appointment.email = appointment.email&.downcase&.strip
      appointment.dob = DateOfBirthParser.parse(appointment.dob) if appointment.dob.is_a?(String)
      appointment.appointment_date = parsed_date_param(appointment.appointment_date) if appointment.appointment_date.is_a?(String)
      appointment.appointment_time = parse_time_param(appointment.appointment_time) if appointment.appointment_time.is_a?(String)
    end

    def honeypot_triggered?
      params[:website].present?
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

      Date.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def assign_appointment_form_state
      booking_service = @organization.services.visible.active.find_by(id: @appointment.service_id || @selected_service&.id)
      @booking_schedule = @organization.booking_schedule(calendar: booking_service&.calendar)
      @appointment_month = @appointment.appointment_date&.beginning_of_month ||
        parsed_month ||
        default_booking_month(@booking_schedule)
      @collect_postcode = @organization.kiosk_collect_postcode?
      @collect_dob = @organization.kiosk_collect_dob?
      @postcode_region = @organization.postcode_region.presence || "uk"
      @eligibility_data = eligibility_data_for_form
      @error_step = appointment_error_step
      @appointment_slots = appointment_slots_for_form
    end

    DETAIL_ERROR_FIELDS = %i[first_name last_name dob postcode email notes].freeze

    def appointment_error_step
      return 0 unless @appointment&.errors&.any?

      (@appointment.errors.attribute_names.map(&:to_sym) & DETAIL_ERROR_FIELDS).any? ? 1 : 0
    end

    def appointment_slots_for_form
      return [] unless @appointment&.appointment_date.present? && @appointment.service_id.present?

      service = @organization.services.visible.active.find_by(id: @appointment.service_id)
      return [] unless service

      SlotAvailabilityService.new(@organization, service, @appointment.appointment_date).available_slots
    end

    def eligibility_data_for_form
      @organization.services.visible.active.where(requires_appointment: true)
        .order(:display_name)
        .each_with_object({}) do |service, hash|
          hash[service.id] = service.eligibility_requirements if service.eligibility_requirements?
        end
    end

    def parse_time_param(value)
      return value if value.is_a?(Time)
      return if value.blank?

      Time.zone.parse("2000-01-01 #{value}")
    rescue ArgumentError
      nil
    end
  end
end
