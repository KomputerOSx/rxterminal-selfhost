class BillingController < ApplicationController
  CHARGES_PER_PAGE = 10

  before_action { redirect_to dashboard_path, alert: "No organization selected." unless Current.organization }
  before_action { authorize Current.organization, :show?, policy_class: BillingPolicy }
  before_action :finalize_checkout_return, only: :show
  after_action :verify_authorized

  def show
    if Current.organization.plan_reconciliation_required?
      redirect_to billing_plan_reconciliation_path and return
    end

    @plans = Billing::Plans::PAID
    @subscribed = Current.organization.subscribed?
    @current_plan = Current.organization.current_plan
    @currency = Current.organization.billing_currency
    @plan_usage = Current.organization.plan_usage_items
    @payment_method = Current.organization.payment_processor&.default_payment_method

    @subscription = Current.organization.payment_processor&.subscription
    @on_grace_period = @subscription&.active? && @subscription.on_grace_period?
    @on_trial = Current.organization.on_trial?
    @pending_plan = Current.organization.pending_plan
    @pending_price_cents = Current.organization.pending_price_cents
    @promo_code_id = session[:promo_code_id]
    @promo_code_display = session[:promo_code_display]
    # For "you'll keep X until <date>" copy on downgrade confirms - synced locally by Pay, so
    # no Stripe API call happens on page view; nil just softens the copy.
    @current_period_end = @subscription&.current_period_end

    charges = Current.organization.payment_processor&.charges&.order(created_at: :desc) || Pay::Charge.none
    @charges_page = [ params[:charges_page].to_i, 1 ].max
    @charges_total_pages = (charges.count / CHARGES_PER_PAGE.to_f).ceil
    @charges = charges.offset((@charges_page - 1) * CHARGES_PER_PAGE).limit(CHARGES_PER_PAGE)
  end

  private

  def finalize_checkout_return
    session_id = params[:stripe_checkout_session_id]
    return if session_id.blank?

    organization = Current.organization
    plan_key = nil

    case organization.finalize_checkout_session!(session_id)
    when :complete
      clear_promo_code!
      plan_key = organization.current_plan&.key
      log_audit(:subscription_created, resource: organization,
        metadata: { plan: plan_key, checkout: true }.compact_blank)
      if plan_key == Billing::Plans::STARTER.key && organization.downgrade_to_starter_requires_reconciliation?
        organization.require_plan_reconciliation_blocking!
        redirect_to billing_plan_reconciliation_path, notice: checkout_success_message(organization, plan_key)
      else
        redirect_to billing_path, notice: checkout_success_message(organization, plan_key)
      end
    when :incomplete
      redirect_to billing_path, alert: "Checkout wasn't completed. No changes were made."
    when :invalid
      redirect_to billing_path, alert: "That checkout session doesn't belong to this organization."
    when :error
      redirect_to billing_path, alert: "We couldn't confirm your checkout. If you were charged, contact support."
    end
  end

  def checkout_success_message(organization, plan_key)
    plan_name = ::Billing::Plans.find(plan_key)&.name || "your"
    subscription = organization.payment_processor&.subscription
    if subscription&.on_trial?
      trial_end = organization.trial_ends_at&.to_date&.to_fs(:long)
      "Card saved for the #{plan_name} plan. You'll be charged automatically when your trial ends#{" on #{trial_end}" if trial_end}."
    elsif organization.subscribed?
      "Subscribed to the #{plan_name} plan."
    else
      "Payment received. Your subscription will appear shortly."
    end
  end

  def clear_promo_code!
    session.delete(:promo_code_id)
    session.delete(:promo_code_display)
    session.delete(:promo_code_applied_live)
  end
end
