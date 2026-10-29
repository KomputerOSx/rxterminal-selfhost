# frozen_string_literal: true

module Billing
  module StripeRedirects
    STRIPE_CHECKOUT_HOST = "checkout.stripe.com"
    STRIPE_BILLING_PORTAL_HOST = "billing.stripe.com"

    private

    def redirect_to_stripe_checkout!(url)
      redirect_to_stripe!(url, expected_host: STRIPE_CHECKOUT_HOST)
    end

    def redirect_to_stripe_billing_portal!(url)
      redirect_to_stripe!(url, expected_host: STRIPE_BILLING_PORTAL_HOST)
    end

    def redirect_to_stripe!(url, expected_host:)
      uri = URI.parse(url.to_s)
      unless uri.is_a?(URI::HTTPS) && uri.host == expected_host
        raise ArgumentError, "Invalid Stripe redirect URL"
      end

      redirect_to uri.to_s, allow_other_host: true
    end
  end
end
