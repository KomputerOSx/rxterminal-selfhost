# frozen_string_literal: true

module Billing
  class PlanReconciliation
    STEPS = %i[intro members services upsell_rules kiosk_devices appointments confirm].freeze
    NON_SELECTION_STEPS = %i[intro confirm].freeze

    attr_reader :organization, :target_plan, :mode, :choices

    def initialize(organization, target_plan: Billing::Plans::STARTER, mode: :immediate, choices: {})
      @organization = organization
      @target_plan = target_plan
      @mode = mode.to_sym
      @choices = choices.stringify_keys
    end

    def applies?
      required_steps.any? { |step| !step.in?(NON_SELECTION_STEPS) }
    end

    def required_steps
      @required_steps ||= begin
        steps = []
        limits = target_plan.limits

        if organization.member_count_with_pending > limits.max_users
          steps << :members
        end
        if organization.billable_services_count > limits.max_services
          steps << :services
        end
        if organization.billable_upsell_rules_count > limits.max_upsell_rules
          steps << :upsell_rules
        end
        if organization.billable_kiosk_devices_count.positive?
          steps << :kiosk_devices
        end
        if organization.appointments.exists?
          steps << :appointments
        end
        steps << :confirm
        steps.unshift(:intro) if steps.size > 1
        steps
      end
    end

    def step_label(step)
      { intro: "Overview" }.fetch(step.to_sym, step.to_s.humanize)
    end

    def first_step
      required_steps.first
    end

    def step_valid?(step)
      required_steps.include?(step.to_sym)
    end

    def next_step(step)
      index = required_steps.index(step.to_sym)
      return nil if index.nil?

      required_steps[index + 1]
    end

    def previous_step(step)
      index = required_steps.index(step.to_sym)
      return nil if index.nil? || index.zero?

      required_steps[index - 1]
    end

    def final_step?(step)
      step.to_sym == :confirm
    end

    def members_to_remove
      organization.memberships
        .includes(:user, :roles)
        .reject { |membership| membership.has_role?(Role::APP_OWNER, scope: :app) }
    end

    def service_selection_limit
      target_plan.limits.max_services
    end

    def selectable_services
      organization.services.plan_active.by_display_order
    end

    def kept_service_ids
      if required_steps.include?(:services)
        Array(choices["service_ids"]).map(&:to_i)
      else
        selectable_services.pluck(:id)
      end
    end

    def selectable_upsell_rules
      kept_ids = kept_service_ids
      return organization.upsell_rules.none if kept_ids.empty?

      organization.upsell_rules.plan_active.by_priority
        .where(trigger_service_id: kept_ids, suggested_service_id: kept_ids)
    end

    def merge_choices!(step, params)
      case step.to_sym
      when :services
        service_ids = Array(params[:service_ids]).map(&:to_i).uniq
        raise ArgumentError, "Pick up to #{service_selection_limit} services to keep active." if service_ids.size > service_selection_limit
        raise ArgumentError, "Pick at least one service to keep active." if service_ids.empty?

        valid_ids = selectable_services.where(id: service_ids).pluck(:id)
        raise ArgumentError, "Invalid service selection." if valid_ids.sort != service_ids.sort

        choices["service_ids"] = valid_ids
        clear_invalid_upsell_rule_choice!
      when :upsell_rules
        rule_id = params[:upsell_rule_id].to_i
        raise ArgumentError, "Pick one upsell rule to keep active." if rule_id.zero?
        raise ArgumentError, "Pick one upsell rule to keep active." unless selectable_upsell_rules.exists?(id: rule_id)

        choices["upsell_rule_id"] = rule_id
      when :intro, :members, :kiosk_devices, :appointments
        choices["#{step}_acknowledged"] = true
      when :confirm
        validate_choices_complete!
        choices["confirm_acknowledged"] = true
      else
        raise ArgumentError, "Unknown step."
      end

      choices["target_plan_key"] = target_plan.key
      choices["mode"] = mode.to_s
      choices
    end

    def clear_invalid_upsell_rule_choice!
      rule_id = choices["upsell_rule_id"]
      return if rule_id.blank?
      return if selectable_upsell_rules.exists?(id: rule_id)

      choices.delete("upsell_rule_id")
    end

    def validate_choices_complete!
      required_steps.each do |step|
        next if step == :confirm

        case step
        when :services
          raise ArgumentError, "Pick up to #{service_selection_limit} services to keep active." if Array(choices["service_ids"]).empty?
        when :upsell_rules
          raise ArgumentError, "Pick one upsell rule to keep active." if choices["upsell_rule_id"].blank?
        when :members, :kiosk_devices, :appointments
          # informational steps only
        end
      end
    end

    def self.for(organization, session_context: nil)
      if organization.plan_reconciliation_required?
        new(
          organization,
          target_plan: Billing::Plans::STARTER,
          mode: :immediate,
          choices: organization.plan_reconciliation_choices
        )
      elsif session_context.present?
        plan = Billing::Plans.find(session_context["target_plan_key"]) || Billing::Plans::STARTER
        new(
          organization,
          target_plan: plan,
          mode: session_context["mode"] || "scheduled",
          choices: session_context.fetch("choices", {})
        )
      else
        new(organization)
      end
    end
  end
end
