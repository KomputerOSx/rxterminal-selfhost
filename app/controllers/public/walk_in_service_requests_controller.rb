# frozen_string_literal: true

module Public
  class WalkInServiceRequestsController < BaseController
    include UpsellSessionFlow

    before_action :require_mobile_service_request_feature
    before_action :require_walk_in_session, only: [ :new, :create ]

    def new
      if params[:service_id].present?
        @service = walk_in_services.find_by(id: params[:service_id])
        redirect_to(new_portal_walk_in_path) and return unless @service

        @service_request = ServiceRequest.new
      else
        @services = walk_in_services
      end
    end

    def create
      return if block_if_at_monthly_request_limit!(public_facing: true)

      submitted = service_request_params
      @display_dob = submitted[:dob]

      @service = walk_in_services.find_by(id: submitted[:service_id])

      unless @service
        redirect_to new_portal_walk_in_path, alert: "Service not found."
        return
      end

      @service_request = ServiceRequest.new(submitted.except(:service_id))
      @service_request.service = @service
      @service_request.organization = @organization
      @service_request.status = "waiting"
      @service_request.request_type = "immediate"
      @service_request.dob = DateOfBirthParser.parse(@display_dob)
      @service_request.first_name = @service_request.first_name&.upcase
      @service_request.last_name = @service_request.last_name&.upcase
      @service_request.postcode = @service_request.postcode&.upcase
      @service_request.submission_ip = request.remote_ip

      ServiceRequest.transaction do
        @organization.with_lock do
          @service_request.queue_number = ServiceRequest.next_queue_number_for(@organization)
          @service_request.save!
        end
      end

      upsell = UpsellEngine.evaluate(
        organization: @organization,
        service: @service,
        customer_dob: @service_request.dob,
        customer_first_name: @service_request.first_name,
        customer_last_name: @service_request.last_name
      )

      if upsell
        store_upsell_session!(upsell, @service_request)
        redirect_to portal_walk_in_upsell_path
      else
        flash[:walk_in_queue_number] = @service_request.queue_number
        flash[:walk_in_service_name] = @service.display_name
        redirect_to portal_walk_in_success_path
      end
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def success
      @queue_number = flash[:walk_in_queue_number]
      @service_name = flash[:walk_in_service_name]

      redirect_to portal_root_path if @queue_number.blank?
    end

    def my_queue
      @queue_number = session.delete(:walk_in_queue_number_carry)
      @service_name = session.delete(:walk_in_queue_service_carry)
      session.delete(:walk_in_prefill)

      redirect_to portal_arrive_path if @queue_number.blank?
    end

    private

    def require_mobile_service_request_feature
      redirect_to portal_root_path unless @organization.mobile_service_request_enabled?
    end

    def require_walk_in_session
      redirect_to portal_arrive_path unless walk_in_session_active?
    end

    def walk_in_services
      @organization.services.visible.active.where(allows_immediate: true).order(:display_order, :display_name)
    end

    def service_request_params
      params.require(:service_request).permit(
        :service_id,
        :first_name,
        :last_name,
        :dob,
        :postcode,
        :privacy_requested,
        :description
      )
    end
  end
end
