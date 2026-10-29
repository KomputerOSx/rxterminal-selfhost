# frozen_string_literal: true

module Billing
  class PlanReconciliationsController < ApplicationController
    before_action :require_organization!
    before_action { authorize Current.organization, :manage?, policy_class: BillingPolicy }
    before_action :set_wizard
    before_action :ensure_wizard_applies!

    def show
      @step = normalized_step(params[:step]) || @wizard.first_step
      render :show
    end

    def update
      @step = normalized_step(params[:step])
      return redirect_to billing_plan_reconciliation_path(step: @wizard.first_step), alert: "Unknown step." unless @step

      @wizard.merge_choices!(@step, step_params)
      persist_session_context!

      if @wizard.final_step?(@step)
        complete_wizard!
      else
        redirect_to billing_plan_reconciliation_path(step: @wizard.next_step(@step))
      end
    rescue ArgumentError => e
      redirect_to billing_plan_reconciliation_path(step: @step), alert: e.message
    end

    private

    def require_organization!
      redirect_to dashboard_path, alert: "No organization selected." unless Current.organization
    end

    def set_wizard
      @organization = Current.organization
      @wizard = Billing::PlanReconciliation.for(@organization, session_context: session[:plan_reconciliation])
      @mode = @wizard.mode
      @target_plan = @wizard.target_plan
    end

    def ensure_wizard_applies!
      return if @organization.plan_reconciliation_required?
      return if session[:plan_reconciliation].present?
      return if @wizard.applies?

      redirect_to billing_path, alert: "No plan setup is required right now."
    end

    def normalized_step(step)
      return nil if step.blank?

      step = step.to_sym
      @wizard.step_valid?(step) ? step : nil
    end

    def step_params
      params.permit(:upsell_rule_id, service_ids: [])
    end

    def persist_session_context!
      if @organization.plan_reconciliation_required?
        @organization.update!(plan_reconciliation_choices: @wizard.choices)
        return
      end

      session[:plan_reconciliation] = {
        "target_plan_key" => @wizard.target_plan.key,
        "mode" => @wizard.mode.to_s,
        "choices" => @wizard.choices
      }
    end

    def complete_wizard!
      organization = @organization
      choices = @wizard.choices

      if @wizard.mode == :scheduled
        organization.update!(plan_reconciliation_choices: choices, plan_reconciliation_applied_at: nil)
        organization.schedule_downgrade!(@wizard.target_plan, reconciliation_choices: choices)
        session.delete(:plan_reconciliation)
        log_audit(:subscription_downgrade_scheduled, resource: organization,
          metadata: { plan: @wizard.target_plan.key, reconciliation: true })
        change_date = organization.pending_plan_change_at&.to_date&.to_fs(:long) || "your next billing date"
        redirect_to billing_path,
          notice: "Your plan will change to #{@wizard.target_plan.name} on #{change_date}. Until then you keep your current plan."
      else
        organization.apply_plan_reconciliation!(choices)
        session.delete(:plan_reconciliation)
        log_audit(:plan_reconciliation_completed, resource: organization, metadata: { plan: @wizard.target_plan.key })
        redirect_to dashboard_path, notice: "Your organization is set up for the #{@wizard.target_plan.name} plan."
      end
    rescue Pay::Stripe::Error => e
      redirect_to billing_plan_reconciliation_path(step: :confirm), alert: e.message
    end
  end
end
