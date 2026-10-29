# frozen_string_literal: true

module Kiosk
  class ServiceRequestsController < BaseController
    include KioskAuthentication
    include UpsellSessionFlow

    before_action :set_service, only: [ :new, :create ]

    def new
      @service_request = ServiceRequest.new
    end

  def create
    if kiosk_preview_mode?
      handle_preview_create
      return
    end

    return if block_if_at_monthly_request_limit!(public_facing: true)

    @service_request = ServiceRequest.new(service_request_params)
      @service_request.organization = @organization
      @service_request.service = @service
      @service_request.status = "waiting"
      @service_request.request_type = "immediate"
      @service_request.dob = parse_dob(params.dig(:service_request, :dob))
      @service_request.first_name = @service_request.first_name&.upcase
      @service_request.last_name = @service_request.last_name&.upcase
      @service_request.postcode = @service_request.postcode&.upcase

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
        render json: { redirect_to: kiosk_upsell_path }
      else
        session[:upsell_confirmed_numbers] = [ @service_request.queue_number ]
        session[:upsell_confirmed_services] = [ @service.display_name ]
        render json: { redirect_to: kiosk_confirmed_upsell_path }
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      render json: {
        errors: @service_request.errors.full_messages.presence || [ e.message ]
      }, status: :unprocessable_entity
    end

    private

    def set_service
      id = params[:service_id] || params.dig(:service_request, :service_id)
      @service = @organization.services.visible.active.find_by(id: id)
      return if @service

      respond_to do |format|
        format.json { render json: { errors: [ "Service not found" ] }, status: :not_found }
        format.html { redirect_to kiosk_services_path, alert: "Service not found or not available" }
      end
    end

    def service_request_params
      params.require(:service_request).permit(
        :first_name,
        :last_name,
        :dob,
        :postcode,
        :privacy_requested,
        :description
      )
    end

    def parse_dob(value)
      return nil if value.blank?

      Date.parse(value)
    rescue ArgumentError
      nil
    end

    def handle_preview_create
      dob = parse_dob(params.dig(:service_request, :dob))
      walk_in = preview_walk_in_from_params(dob: dob)

      upsell = UpsellEngine.evaluate(
        organization: @organization,
        service: @service,
        customer_dob: dob,
        customer_first_name: walk_in[:first_name],
        customer_last_name: walk_in[:last_name]
      )

      if upsell
        store_preview_upsell_session!(upsell, walk_in)
        render json: { redirect_to: kiosk_upsell_path }
      else
        session[:upsell_confirmed_numbers] = [ walk_in[:queue_number] ]
        session[:upsell_confirmed_services] = [ @service.display_name ]
        render json: { redirect_to: kiosk_confirmed_upsell_path }
      end
    end

    def preview_walk_in_from_params(dob: nil)
      dob ||= parse_dob(params.dig(:service_request, :dob))
      {
        first_name: service_request_params[:first_name]&.upcase,
        last_name: service_request_params[:last_name]&.upcase,
        dob: dob&.iso8601,
        postcode: service_request_params[:postcode]&.upcase,
        privacy_requested: service_request_params[:privacy_requested],
        service_id: @service.id,
        service_name: @service.display_name,
        queue_number: preview_queue_number
      }
    end
  end
end
