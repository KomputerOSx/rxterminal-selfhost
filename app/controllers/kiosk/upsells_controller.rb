# frozen_string_literal: true

module Kiosk
  class UpsellsController < BaseController
    include KioskAuthentication
    include UpsellSessionFlow

    before_action :load_upsell_session, except: [ :confirmed ]

    def show
      unless @rule && @template
        redirect_to kiosk_root_path, alert: upsell_notice and return
      end
    end

    def accept
      unless @rule && @template && @original_sr
        redirect_to kiosk_root_path, alert: upsell_notice and return
      end

      if kiosk_preview_mode?
        session[:upsell_confirmed_numbers] = [ session_queue_number, preview_queue_number ]
        session[:upsell_confirmed_services] = [
          @original_sr.service.display_name,
          @rule.suggested_service.display_name
        ]
        clear_upsell_prompt_session
        clear_upsell_booking_session
        redirect_to kiosk_confirmed_upsell_path
        return
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
      counter_for_now.increment_conversion!(@rule.suggested_service)

      session[:upsell_confirmed_numbers] = [ session_queue_number, new_sr.queue_number ]
      session[:upsell_confirmed_services] = [
        @original_sr.service.display_name,
        @rule.suggested_service.display_name
      ]

      clear_upsell_prompt_session
      clear_upsell_booking_session
      redirect_to kiosk_confirmed_upsell_path
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Kiosk upsell accept failed: #{e.message}"
      clear_upsell_prompt_session
      clear_upsell_booking_session
      redirect_to kiosk_root_path, alert: upsell_notice
    end

    def book_later
      unless @rule && @template && @original_sr && @rule.suggested_service&.requires_appointment?
        clear_upsell_prompt_session
        redirect_to kiosk_root_path, alert: upsell_notice and return
      end

      if kiosk_preview_mode?
        session[:upsell_booking] = {
          preview: true,
          original_queue_number: session_queue_number,
          upsold_service_id: @rule.suggested_service_id,
          walk_in: session[:kiosk_preview_walk_in],
          source: "upsell_booking",
          started_at: Time.current.to_i
        }
        clear_upsell_prompt_session
        redirect_to kiosk_new_appointment_path(service_id: @rule.suggested_service_id)
        return
      end

      record_interaction("accepted_appointment")
      counter_for_now.increment_book_later!(@rule.suggested_service)

      session[:upsell_booking] = {
        original_service_request_id: @original_sr.id,
        original_queue_number: session_queue_number,
        upsold_service_id: @rule.suggested_service_id,
        source: "upsell_booking",
        started_at: Time.current.to_i
      }

      clear_upsell_prompt_session
      redirect_to kiosk_new_appointment_path(service_id: @rule.suggested_service_id)
    end

    def decline
      if kiosk_preview_mode?
        session[:upsell_confirmed_numbers] = [ session_queue_number ].compact
        session[:upsell_confirmed_services] = [ @original_sr&.service&.display_name ].compact
        clear_upsell_prompt_session
        clear_upsell_booking_session
        redirect_to kiosk_confirmed_upsell_path
        return
      end

      record_interaction("declined")
      counter_for_now.increment_decline! if @rule

      session[:upsell_confirmed_numbers] = [ session_queue_number ].compact
      session[:upsell_confirmed_services] = [ @original_sr&.service&.display_name ].compact

      clear_upsell_prompt_session
      clear_upsell_booking_session
      redirect_to kiosk_confirmed_upsell_path
    end

    def confirmed
      @queue_numbers = session.delete(:upsell_confirmed_numbers) || []
      @service_names = session.delete(:upsell_confirmed_services) || []
      redirect_to kiosk_root_path if @queue_numbers.empty?
    end

    private

    def load_upsell_session
      rule_id = session[:upsell_rule_id]
      sr_id = session[:upsell_service_request_id]
      template_id = session[:upsell_template_id]

      @rule = @organization.upsell_rules
        .includes(:upsell_templates, :suggested_service)
        .find_by(id: rule_id)
      @template = @rule&.upsell_templates&.find_by(id: template_id) || @rule&.upsell_templates&.first
      @original_sr = if kiosk_preview_mode? && sr_id == KioskPreviewMode::PREVIEW_WALK_IN_ID
        preview_walk_in
      else
        ServiceRequest.find_by(id: sr_id, organization: @organization)
      end
      @queue_number = session_queue_number
    end

    def session_queue_number
      session[:upsell_queue_number]
    end

    def upsell_notice
      num = session_queue_number
      num.present? ? "Your request has been submitted! Queue number: #{num}" : "Your request has been submitted!"
    end

    def record_interaction(outcome)
      return if kiosk_preview_mode?

      record_upsell_interaction!(organization: @organization, outcome: outcome)
    end

    def counter_for_now
      upsell_counter_for(organization: @organization)
    end

    def clear_upsell_booking_session
      session.delete(:upsell_booking)
    end
  end
end
