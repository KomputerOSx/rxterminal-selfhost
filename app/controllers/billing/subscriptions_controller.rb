module Billing
  class SubscriptionsController < ApplicationController
    include StripeRedirects

    def create
      authorize Current.organization, :manage?, policy_class: BillingPolicy

      plan = ::Billing::Plans.find(params[:plan])
      organization = Current.organization
      return redirect_with_alert("That plan isn't available.") if plan.nil? || plan.resolved_stripe_price_id(organization.billing_currency).blank?

      converting_trial = organization.on_trial? && !organization.subscribed?
      same_plan = plan.key == organization.current_plan&.key
      if same_plan && !(converting_trial && organization.payment_processor.default_payment_method)
        return redirect_with_alert("You're already on the #{plan.name} plan.")
      end

      if converting_trial
        # Mid-trial plan switches need no card; converting to paid uses Stripe Checkout.
        unless organization.payment_processor.default_payment_method
          organization.switch_trial_plan!(plan)
          log_audit(:subscription_updated, resource: organization, metadata: { plan: plan.key, trial: true })
          return redirect_to billing_path, notice: "Switched to the #{plan.name} plan for the rest of your trial."
        end

        return redirect_to_checkout!(organization, plan)
      elsif !organization.payment_processor.default_payment_method
        return redirect_to_checkout!(organization, plan)
      end

      if organization.subscribed? &&
          plan.price_cents(organization.billing_currency) < organization.current_plan.price_cents(organization.billing_currency) &&
          organization.downgrade_to_starter_requires_reconciliation?(plan)
        session[:plan_reconciliation] = {
          "target_plan_key" => plan.key,
          "mode" => "scheduled",
          "choices" => {}
        }
        return redirect_to billing_plan_reconciliation_path
      end

      case organization.change_plan!(plan, promotion_code: session[:promo_code_id])
      when :created
        clear_promo_code!
        log_audit(:subscription_created, resource: organization, metadata: { plan: plan.key })
        redirect_to billing_path, notice: "Subscribed to the #{plan.name} plan."
      when :converted
        clear_promo_code!
        log_audit(:subscription_created, resource: organization, metadata: { plan: plan.key, trial_converted: true })
        redirect_to billing_path, notice: "Subscribed to the #{plan.name} plan."
      when :trial_plan_changed
        log_audit(:subscription_updated, resource: organization, metadata: { plan: plan.key, trial: true })
        redirect_to billing_path, notice: "Switched to the #{plan.name} plan for the rest of your trial."
      when :upgraded
        clear_promo_code!
        log_audit(:subscription_updated, resource: organization, metadata: { plan: plan.key })
        redirect_to billing_path, notice: "Switched to the #{plan.name} plan. The prorated difference for the rest of this period has been charged to your card."
      when :downgrade_scheduled
        log_audit(:subscription_downgrade_scheduled, resource: organization, metadata: { plan: plan.key })
        change_date = organization.pending_plan_change_at&.to_date&.to_fs(:long) || "your next billing date"
        redirect_to billing_path, notice: "Your plan will change to #{plan.name} on #{change_date}. Until then you keep your current plan."
      end
    rescue Pay::ActionRequired, Pay::InvalidPaymentMethod
      redirect_with_alert("Your card needs additional verification. Please update your payment method and try again.")
    rescue Pay::Stripe::Error => e
      redirect_with_alert(e.message)
    end

    def destroy
      authorize Current.organization, :manage?, policy_class: BillingPolicy

      organization = Current.organization

      if organization.on_trial? && !organization.subscribed?
        plan_key = organization.trial_plan_key
        organization.end_trial!
        log_audit(:subscription_cancelled, resource: organization, metadata: { plan: plan_key, trial: true })
        return redirect_to billing_path, notice: "Your trial has ended. Subscribe to restore access."
      end

      subscription = organization.payment_processor.subscription
      return redirect_with_alert("No active subscription to cancel.") unless subscription&.active?
      return redirect_with_alert("Your subscription is already set to cancel.") if subscription.on_grace_period?

      cancelled_subscription = organization.cancel_subscription!
      log_audit(:subscription_cancelled, resource: organization, metadata: { plan: organization.current_plan&.key })

      end_date = cancelled_subscription.ends_at&.to_date&.to_fs(:long) || "the end of your current billing period"
      plan_name = organization.current_plan&.name || "subscription"
      redirect_to billing_path, notice: "Your #{plan_name} plan will end on #{end_date}. You can resume any time before then."
    rescue Pay::Stripe::Error => e
      redirect_with_alert(e.message)
    end

    private

    def clear_promo_code!
      session.delete(:promo_code_id)
      session.delete(:promo_code_display)
      session.delete(:promo_code_applied_live)
    end

    def redirect_with_alert(message)
      redirect_to billing_path, alert: message
    end

    def redirect_to_checkout!(organization, plan)
      checkout_session = organization.create_checkout_session!(
        plan,
        promotion_code: session[:promo_code_id],
        success_url: billing_url,
        cancel_url: billing_url
      )
      redirect_to_stripe_checkout!(checkout_session.url)
    rescue Pay::Stripe::Error => e
      redirect_with_alert(e.message)
    end
  end
end
