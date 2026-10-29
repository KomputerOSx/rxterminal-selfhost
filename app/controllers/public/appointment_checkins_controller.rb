# frozen_string_literal: true

module Public
  class AppointmentCheckinsController < BaseController
    before_action :require_online_appointment_check_feature
    before_action(only: [ :new, :create ]) { block_unless_appointments_enabled!(public_facing: true) }
    before_action :require_walk_in_session, only: [ :new, :create ]
    before_action :load_checkin_forms, only: [ :new, :create ]

    def new
    end

    def create
      if params[:booking_reference].present?
        check_in_by_reference
      else
        check_in_by_identity
      end
    end

    def early
      date_str = session.delete(:checkin_appointment_date)
      redirect_to portal_arrive_path and return if date_str.blank?

      @appointment_date = Date.parse(date_str)
    end

    def late
      date_str = session.delete(:checkin_appointment_date)
      redirect_to portal_arrive_path and return if date_str.blank?

      @appointment_date = Date.parse(date_str)
      @appointment_time = session.delete(:checkin_appointment_time)
    end

    def select
      @candidates = load_checkin_candidates
      redirect_to new_portal_appointment_checkin_path, alert: "Please search again." and return if @candidates.blank?
    end

    def confirm
      @candidates = load_checkin_candidates
      session.delete(:checkin_candidate_ids)
      @appointment = @candidates.find { |appointment| appointment.id == params[:appointment_id].to_i }

      unless @appointment
        redirect_to new_portal_appointment_checkin_path, alert: "That appointment could not be found. Please search again."
        return
      end

      complete_check_in
    end

    def success
      @queue_number = flash[:appointment_checkin_queue_number]

      redirect_to portal_root_path if @queue_number.blank?
    end

    private

    def load_checkin_candidates
      ids = session[:checkin_candidate_ids]
      return [] if ids.blank?

      @organization.appointments.where(id: ids, status: "booked")
        .includes(:service).order(:appointment_date, :appointment_time)
    end

    def require_online_appointment_check_feature
      redirect_to portal_root_path unless @organization.online_appointment_check_enabled?
    end

    def require_walk_in_session
      redirect_to portal_arrive_path unless walk_in_session_active?
    end

    def load_checkin_forms
      @reference_checkin = AppointmentCheckinReference.new
      @identity_checkin = AppointmentCheckinIdentity.new
    end

    def check_in_by_reference
      @reference_checkin = AppointmentCheckinReference.new(
        booking_reference: params[:booking_reference].to_s.strip
      )

      if @reference_checkin.booking_reference.blank?
        @reference_checkin.errors.add(:booking_reference, "can't be blank")
        render :new, status: :unprocessable_entity and return
      end

      @appointment = @organization.appointments.find_by(
        booking_reference: @reference_checkin.booking_reference.upcase
      )

      unless @appointment
        @reference_checkin.errors.add(:booking_reference, "not found. Please check and try again.")
        render :new, status: :unprocessable_entity and return
      end

      complete_check_in
    end

    def check_in_by_identity
      @identity_checkin = AppointmentCheckinIdentity.new(
        last_name: params[:last_name].to_s.strip,
        dob: params[:dob].to_s.strip
      )
      @display_dob = params[:dob]

      if @identity_checkin.last_name.blank?
        @identity_checkin.errors.add(:last_name, "can't be blank")
      end

      if @organization.kiosk_collect_dob? && @identity_checkin.dob.blank?
        @identity_checkin.errors.add(:dob, "can't be blank")
      end

      if @identity_checkin.errors.any?
        render :new, status: :unprocessable_entity and return
      end

      parsed_dob = nil
      if @identity_checkin.dob.present?
        parsed_dob = parse_portal_dob(@identity_checkin.dob)
        unless parsed_dob
          @identity_checkin.errors.add(:dob, "is invalid")
          render :new, status: :unprocessable_entity and return
        end
      end

      candidates = AppointmentCheckInService.find_candidates(
        organization: @organization,
        last_name: @identity_checkin.last_name,
        dob: parsed_dob
      )

      if candidates.empty?
        @identity_checkin.errors.add(:last_name, "not found. Please check your details and try again.")
        @identity_checkin.errors.add(:dob, "not found. Please check your details and try again.") if parsed_dob
        render :new, status: :unprocessable_entity and return
      end

      session[:checkin_candidate_ids] = candidates.map(&:id)
      redirect_to portal_appointment_checkin_select_path
    end

    def complete_check_in
      if @appointment.status == "checked_in"
        fail_check_in("This appointment has already been checked in.") and return
      end

      if @appointment.status.in?(%w[cancelled no_show])
        fail_check_in("This appointment has been #{@appointment.status.humanize.downcase}.") and return
      end

      if @appointment.appointment_date > Date.current
        session[:checkin_appointment_date] = @appointment.appointment_date.iso8601
        redirect_to portal_appointment_checkin_early_path and return
      end

      if @appointment.appointment_date < Date.current
        session[:checkin_appointment_date] = @appointment.appointment_date.iso8601
        session[:checkin_appointment_time] = @appointment.formatted_time
        redirect_to portal_appointment_checkin_late_path and return
      end

      service_request = @appointment.check_in!(submission_ip: request.remote_ip)
      flash[:appointment_checkin_queue_number] = service_request.queue_number
      redirect_to portal_appointment_checkin_success_path
    rescue StandardError => e
      Rails.logger.error "Appointment check-in failed: #{e.message}"
      fail_check_in("Something went wrong. Please speak to a member of staff.")
    end

    # complete_check_in is called both from the create action (where @identity_checkin/
    # @reference_checkin forms are loaded and errors can render inline) and from confirm
    # (the selection step, where no form is loaded) - fall back to a flash alert + redirect
    # to the start of the flow in the latter case.
    def fail_check_in(message)
      if @identity_checkin || @reference_checkin
        add_checkin_error(message)
        render :new, status: :unprocessable_entity
      else
        redirect_to new_portal_appointment_checkin_path, alert: message
      end
    end

    def add_checkin_error(message)
      if params[:booking_reference].present?
        @reference_checkin.errors.add(:booking_reference, message)
      else
        @identity_checkin.errors.add(:last_name, message)
      end
    end

    def parse_portal_dob(value)
      DateOfBirthParser.parse(value)
    end
  end
end
