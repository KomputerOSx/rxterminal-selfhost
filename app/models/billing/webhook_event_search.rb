module Billing
  class WebhookEventSearch
    Result = Data.define(:webhook_events, :filter_params, :filters_applied, :pending_pay_webhook_ids)

    PER_PAGE = 50

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = params
    end

    def call
      scope = Billing::StripeEventReceipt.order(received_at: :desc)
      scope = scope.where(event_type: filter_params[:event_type]) if filter_params[:event_type].present?
      scope = scope.where(received_at: date_from..) if date_from
      scope = scope.where(received_at: ..date_to) if date_to
      scope = apply_status_filter(scope)

      Result.new(
        webhook_events: scope.page(@params[:page]).per(PER_PAGE),
        filter_params: filter_params,
        filters_applied: filters_applied?,
        pending_pay_webhook_ids: pending_pay_webhook_ids
      )
    end

    private

    def apply_status_filter(scope)
      case filter_params[:status]
      when "processed"
        scope.where.not(stripe_event_id: pending_pay_webhook_ids.keys)
      when "pending"
        scope.where(stripe_event_id: pending_pay_webhook_ids.keys)
      else
        scope
      end
    end

    # Pay deletes a Pay::Webhook row once it's processed successfully, so any row still present
    # is one that's in-flight or failed processing. Maps stripe_event_id => Pay::Webhook id so the
    # view can link straight to the raw payload for events that still have one.
    def pending_pay_webhook_ids
      @pending_pay_webhook_ids ||= Pay::Webhook.where(processor: "stripe").pluck(:id, :event)
        .each_with_object({}) do |(id, event), ids|
          event_id = Pay::Webhook.extract_stripe_event_id(event)
          ids[event_id] = id if event_id.present?
        end
    end

    def filter_params
      @filter_params ||= @params.slice(:event_type, :status, :date_from, :date_to)
        .transform_values { |value| value.to_s.strip.presence }
    end

    def filters_applied?
      filter_params.except(:date_from, :date_to).values.any?(&:present?) ||
        filter_params[:date_from].present? || filter_params[:date_to].present?
    end

    def date_from
      parse_filter_time(filter_params[:date_from])&.beginning_of_minute
    end

    def date_to
      parse_filter_time(filter_params[:date_to])&.end_of_minute
    end

    def parse_filter_time(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
