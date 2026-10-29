# frozen_string_literal: true

# Shared session bookkeeping for the upsell prompt, used by the org, kiosk, and
# public walk-in flows. Each including controller is still responsible for its
# own load_upsell_session (the @original_sr lookup differs too much between
# staff, kiosk preview mode, and the public portal to share safely).
module UpsellSessionFlow
  extend ActiveSupport::Concern

  SESSION_KEYS = %i[
    upsell_rule_id
    upsell_template_id
    upsell_service_request_id
    upsell_customer_hash
    upsell_queue_number
  ].freeze

  def store_upsell_session!(upsell, service_request)
    session[:upsell_rule_id] = upsell[:rule].id
    session[:upsell_template_id] = upsell[:template].id
    session[:upsell_service_request_id] = service_request.id
    session[:upsell_customer_hash] = upsell[:customer_hash]
    session[:upsell_queue_number] = service_request.queue_number
  end

  def clear_upsell_prompt_session
    SESSION_KEYS.each { |key| session.delete(key) }
  end

  def record_upsell_interaction!(organization:, outcome:)
    return unless @rule

    UpsellInteraction.create!(
      upsell_rule: @rule,
      organization: organization,
      customer_hash: session[:upsell_customer_hash],
      upsell_template: @template,
      outcome: outcome,
      accepted: outcome.start_with?("accepted")
    )
  end

  def upsell_counter_for(organization:)
    UpsellCounter.for_now(organization: organization, upsell_rule: @rule)
  end
end
