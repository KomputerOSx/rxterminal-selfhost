# Pay::Webhooks::StripeController only logs signature verification failures to the Rails
# logger, so a rejected webhook (wrong/rotated signing secret, misconfigured endpoint) is easy
# to miss until reconciliation flags the event as missing hours later. Report it to Sentry
# immediately so a rejected event is visible right away instead of via a delayed reconciliation
# alert.
Rails.application.config.to_prepare do
  Pay::Webhooks::StripeController.class_eval do
    private

    def log_error(e)
      logger.error e.message
      e.backtrace.each { |line| logger.error "  #{line}" }
      Sentry.capture_exception(e) if defined?(Sentry)
    end
  end
end
