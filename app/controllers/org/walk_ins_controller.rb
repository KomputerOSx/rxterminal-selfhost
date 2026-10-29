# frozen_string_literal: true

module Org
  class WalkInsController < BaseController
    include WalkInsHelper
    include UpsellsHelper
    include UpsellSessionFlow

    before_action :authorize_manage
    before_action :load_upsell_session, only: [ :upsell, :upsell_accept, :upsell_book_later, :upsell_decline ]

    def new
      @service_request = ServiceRequest.new
      @services = Current.organization.services.active.immediate.visible.by_display_order
      @services_json = walk_in_services_json(@services)
      @recent_services = recent_services_for(@services)
    end

    def create
      return if block_if_at_monthly_request_limit!

      service = Current.organization.services.active.visible.find_by(id: params.dig(:service_request, :service_id))
      unless service
        redirect_to org_new_walk_in_path, alert: "Service not found." and return
      end

      @service_request = ServiceRequest.new(walk_in_params)
      @service_request.organization = Current.organization
      @service_request.service = service
      @service_request.status = "waiting"
      @service_request.request_type = "immediate"
      @service_request.dob = DateOfBirthParser.parse(params.dig(:service_request, :dob))
      @service_request.first_name = @service_request.first_name&.upcase
      @service_request.last_name = @service_request.last_name&.upcase
      @service_request.postcode = @service_request.postcode&.upcase

      ServiceRequest.transaction do
        Current.organization.with_lock do
          @service_request.queue_number = ServiceRequest.next_queue_number_for(Current.organization)
          @service_request.save!
        end
      end

      log_audit(:walk_in_created, resource: @service_request, metadata: {
        queue_number: @service_request.queue_number,
        service_id: service.id
      })

      upsell = UpsellEngine.evaluate(
        organization: Current.organization,
        service: service,
        customer_dob: @service_request.dob,
        customer_first_name: @service_request.first_name,
        customer_last_name: @service_request.last_name
      )

      if upsell
        store_upsell_session!(upsell, @service_request)
        redirect_to org_upsell_walk_in_path
      else
        session[:walk_in_confirmed_numbers] = [ @service_request.queue_number ]
        session[:walk_in_confirmed_services] = [ service.display_name ]
        redirect_to org_confirmed_walk_in_path
      end
    rescue ActiveRecord::RecordInvalid
      @services = Current.organization.services.active.immediate.visible.by_display_order
      @services_json = walk_in_services_json(@services)
      render :new, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotUnique => e
      @services = Current.organization.services.active.immediate.visible.by_display_order
      @services_json = walk_in_services_json(@services)
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def upsell
      unless @rule && @template
        redirect_to org_new_walk_in_path, notice: "Upsell session expired." and return
      end

      @stats = rule_stats(@rule)
      @customer_hash = session[:upsell_customer_hash]
      @prior_accepted = @customer_hash && UpsellInteraction
        .where(customer_hash: @customer_hash, organization: Current.organization, outcome: "accepted_immediate")
        .exists?
      @prior_seen = @customer_hash && !@prior_accepted && UpsellInteraction
        .where(customer_hash: @customer_hash, organization: Current.organization)
        .exists?
    end

    def upsell_accept
      unless @rule && @template && @original_sr
        redirect_to org_new_walk_in_path and return
      end

      new_sr = ServiceRequest.new(
        service: @rule.suggested_service,
        organization: Current.organization,
        first_name: @original_sr.first_name,
        last_name: @original_sr.last_name,
        dob: @original_sr.dob,
        postcode: @original_sr.postcode,
        status: "waiting",
        request_type: "immediate",
        privacy_requested: @original_sr.privacy_requested
      )

      ServiceRequest.transaction do
        Current.organization.with_lock do
          new_sr.queue_number = ServiceRequest.next_queue_number_for(Current.organization)
          new_sr.save!
        end
      end

      record_interaction("accepted_immediate")
      counter_for_now.increment_conversion!(@rule.suggested_service)

      session[:walk_in_confirmed_numbers] = [ session[:upsell_queue_number], new_sr.queue_number ]
      session[:walk_in_confirmed_services] = [ @original_sr.service.display_name, @rule.suggested_service.display_name ]
      clear_upsell_prompt_session
      redirect_to org_confirmed_walk_in_path
    rescue ActiveRecord::RecordInvalid
      clear_upsell_prompt_session
      redirect_to org_new_walk_in_path, alert: "Upsell failed. Please create a new request."
    end

    def upsell_book_later
      unless @rule && @template && @original_sr
        redirect_to org_new_walk_in_path, alert: "Upsell session expired." and return
      end

      record_interaction("accepted_appointment")
      counter_for_now.increment_book_later!(@rule.suggested_service)

      session[:walk_in_book_later_queue_number] = session[:upsell_queue_number]
      session[:walk_in_book_later_service_request_id] = @original_sr.id
      session[:walk_in_book_later_suggested_service_id] = @rule.suggested_service_id
      clear_upsell_prompt_session
      redirect_to org_book_later_walk_in_path
    end

    def upsell_decline
      record_interaction("declined")
      counter_for_now.increment_decline! if @rule

      session[:walk_in_confirmed_numbers] = [ session[:upsell_queue_number] ].compact
      session[:walk_in_confirmed_services] = [ @original_sr&.service&.display_name ].compact
      clear_upsell_prompt_session
      redirect_to org_confirmed_walk_in_path
    end

    def confirmed
      @queue_numbers = session.delete(:walk_in_confirmed_numbers) || []
      @service_names = session.delete(:walk_in_confirmed_services) || []
      redirect_to org_new_walk_in_path if @queue_numbers.empty?
    end

    def book_later
      @queue_number = session.delete(:walk_in_book_later_queue_number)
      @service_request_id = session.delete(:walk_in_book_later_service_request_id)
      @suggested_service_id = session.delete(:walk_in_book_later_suggested_service_id)
      redirect_to org_new_walk_in_path if @queue_number.blank? || @service_request_id.blank?
    end

    private

    def authorize_manage
      authorize Current.organization, :manage?, policy_class: QueuePolicy
    end

    def recent_services_for(services, limit: 3, lookback: 25)
      recent_ids = Current.organization.service_requests
        .where(request_type: "immediate")
        .order(created_at: :desc)
        .limit(lookback)
        .pluck(:service_id)
        .uniq

      recent_ids.filter_map { |id| services.find { |service| service.id == id } }.first(limit)
    end

    def walk_in_params
      params.require(:service_request).permit(
        :first_name,
        :last_name,
        :postcode,
        :privacy_requested,
        :description
      )
    end

    def load_upsell_session
      rule_id = session[:upsell_rule_id]
      sr_id = session[:upsell_service_request_id]
      template_id = session[:upsell_template_id]
      @rule = UpsellRule.includes(:upsell_templates, :suggested_service).find_by(id: rule_id, organization: Current.organization)
      @template = @rule&.upsell_templates&.find_by(id: template_id) || @rule&.upsell_templates&.first
      @original_sr = Current.organization.service_requests.find_by(id: sr_id)
    end

    def record_interaction(outcome)
      record_upsell_interaction!(organization: Current.organization, outcome: outcome)
    end

    def counter_for_now
      upsell_counter_for(organization: Current.organization)
    end
  end
end
