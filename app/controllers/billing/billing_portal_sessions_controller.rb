# frozen_string_literal: true

module Billing
  class BillingPortalSessionsController < ApplicationController
    include StripeRedirects

    def create
      authorize Current.organization, :manage?, policy_class: BillingPolicy

      portal_session = Current.organization.create_billing_portal_session!(return_url: billing_url)
      redirect_to_stripe_billing_portal!(portal_session.url)
    rescue Pay::Stripe::Error => e
      redirect_to billing_path, alert: e.message
    end
  end
end
