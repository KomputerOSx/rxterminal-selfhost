module Admin
  class WebhookEventsController < BaseController
    before_action { authorize :system, :manage_billing?, policy_class: SystemPolicy }
    before_action :redirect_to_default_range, only: :index

    def index
      @result = Billing::WebhookEventSearch.call(params)
      @webhook_events = @result.webhook_events
      @filter_params = @result.filter_params
      @filters_applied = @result.filters_applied
      @pending_pay_webhook_ids = @result.pending_pay_webhook_ids
      @event_types = Billing::StripeEventReceipt.distinct.order(:event_type).pluck(:event_type)
    end

    def show
      @webhook_event = Pay::Webhook.find(params[:id])
      @webhook_events_back_path = webhook_events_back_path
    end

    private

    def redirect_to_default_range
      return if params.except(:controller, :action, :page).present?

      redirect_to admin_webhook_events_path(
        date_from: 7.days.ago.strftime("%Y-%m-%dT%H:%M"),
        date_to: Time.current.strftime("%Y-%m-%dT%H:%M")
      )
    end

    def webhook_events_back_path
      return_to = params[:return_to].to_s

      return return_to if return_to.start_with?(admin_webhook_events_path)

      admin_webhook_events_path
    end
  end
end
