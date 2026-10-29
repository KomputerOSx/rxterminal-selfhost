# frozen_string_literal: true

module Billing
  class CheckoutSessionsController < ApplicationController
    include StripeRedirects

    def create
      authorize Current.organization, :manage?, policy_class: BillingPolicy

      plan = ::Billing::Plans.find(params[:plan])
      organization = Current.organization
      if plan.nil? || plan.resolved_stripe_price_id(organization.billing_currency).blank?
        return redirect_to billing_path, alert: "That plan isn't available."
      end

      if organization.subscribed? && plan.key != organization.current_plan&.key
        return redirect_to billing_path, alert: "Use Change plan to upgrade or downgrade your subscription."
      end

      # Subscribing (to the current trial plan or a different one) while on a no-card trial is
      # a pre-pay: collect the card now, defer the first charge to Stripe's own trial_end so it
      # lines up with the local trial instead of charging today.
      prepay_trial = organization.on_trial? && !organization.subscribed?

      checkout_session = organization.create_checkout_session!(
        plan,
        promotion_code: session[:promo_code_id],
        success_url: billing_url,
        cancel_url: billing_url,
        defer_billing_until_trial_end: prepay_trial
      )

      redirect_to_stripe_checkout!(checkout_session.url)
    rescue Pay::Stripe::Error => e
      redirect_to billing_path, alert: e.message
    end
  end
end
