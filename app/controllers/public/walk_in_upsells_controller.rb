# frozen_string_literal: true

module Public
  class WalkInUpsellsController < BaseController
    include UpsellSessionFlow

    before_action :load_upsell_session, except: [ :confirmed ]

    def show
      redirect_to portal_arrive_path unless @rule && @template
    end

    def accept
      unless @rule && @template && @original_sr
        redirect_to portal_arrive_path and return
      end

      new_sr = ServiceRequest.new(
        service: @rule.suggested_service,
        organization: @organization,
        first_name: @original_sr.first_name,
        last_name: @original_sr.last_name,
        dob: @original_sr.dob,
        postcode: @original_sr.postcode,
        status: "waiting",
        request_type: "immediate",
        privacy_requested: @original_sr.privacy_requested
      )

      ServiceRequest.transaction do
        @organization.with_lock do
          new_sr.queue_number = ServiceRequest.next_queue_number_for(@organization)
          new_sr.save!
        end
      end

      record_interaction("accepted_immediate")
      upsell_counter_for(organization: @organization).increment_conversion!(@rule.suggested_service)

      session[:upsell_confirmed_numbers] = [ session_queue_number, new_sr.queue_number ]
      session[:upsell_confirmed_services] = [
        @original_sr.service.display_name,
        @rule.suggested_service.display_name
      ]

      clear_upsell_prompt_session
      redirect_to confirmed_portal_walk_in_upsell_path
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Walk-in upsell accept failed: #{e.message}"
      clear_upsell_prompt_session
      redirect_to portal_arrive_path
    end

    def book_later
      unless @organization.online_appointment_booking_enabled?
        clear_upsell_prompt_session
        redirect_to portal_arrive_path and return
      end

      unless @rule && @template && @original_sr && @rule.suggested_service&.requires_appointment?
        clear_upsell_prompt_session
        redirect_to portal_arrive_path and return
      end

      record_interaction("accepted_appointment")
      upsell_counter_for(organization: @organization).increment_book_later!(@rule.suggested_service)

      session[:walk_in_prefill] = {
        "first_name" => @original_sr.first_name,
        "last_name" => @original_sr.last_name,
        "dob" => @original_sr.dob&.iso8601,
        "postcode" => @original_sr.postcode
      }

      session[:walk_in_queue_number_carry] = session_queue_number
      session[:walk_in_queue_service_carry] = @original_sr.service.display_name

      clear_upsell_prompt_session
      redirect_to new_portal_appointment_path(service_id: @rule.suggested_service_id)
    end

    def decline
      record_interaction("declined")
      upsell_counter_for(organization: @organization)&.increment_decline! if @rule

      session[:upsell_confirmed_numbers] = [ session_queue_number ].compact
      session[:upsell_confirmed_services] = [ @original_sr&.service&.display_name ].compact

      clear_upsell_prompt_session
      redirect_to confirmed_portal_walk_in_upsell_path
    end

    def confirmed
      @queue_numbers = session.delete(:upsell_confirmed_numbers) || []
      @service_names = session.delete(:upsell_confirmed_services) || []

      redirect_to portal_arrive_path if @queue_numbers.empty?
    end

    private

    def load_upsell_session
      @rule = @organization.upsell_rules
        .includes(:upsell_templates, :suggested_service)
        .find_by(id: session[:upsell_rule_id])
      @template = @rule&.upsell_templates&.find_by(id: session[:upsell_template_id]) ||
        @rule&.upsell_templates&.first
      @original_sr = ServiceRequest.find_by(id: session[:upsell_service_request_id], organization: @organization)
    end

    def session_queue_number
      session[:upsell_queue_number]
    end

    def record_interaction(outcome)
      record_upsell_interaction!(organization: @organization, outcome: outcome)
    end
  end
end
