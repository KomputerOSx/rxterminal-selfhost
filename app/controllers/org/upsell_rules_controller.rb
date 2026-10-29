# frozen_string_literal: true

module Org
  class UpsellRulesController < BaseController
    include UpsellsHelper

    before_action :authorize_manage
    before_action :set_rule, only: [ :show, :edit, :update, :destroy, :toggle, :move_up, :move_down ]
    before_action :load_services, only: [ :new, :create, :edit, :update ]

    def index
      @rules = Current.organization.upsell_rules.plan_active.by_priority.includes(:trigger_service, :suggested_service)
      @active_count = @rules.count(&:active?)
    end

    def show
      @period = %w[today this_week this_month all_time].include?(params[:period]) ? params[:period] : "all_time"
      @stats = rule_stats(@rule, period: @period)
      @sparkline = upsell_sparkline_data(@rule)
    end

    def new
      @rule = Current.organization.upsell_rules.build(
        frequency_type: "every_nth_customer",
        frequency_value: 3,
        visit_type: "any",
        cooldown_days: 30,
        active: true
      )
      @rule.upsell_templates.build
    end

    def create
      return if block_if_at_upsell_rule_limit!

      @rule = Current.organization.upsell_rules.build(rule_params)
      @rule.priority = next_priority

      if @rule.save
        log_audit(:upsell_rule_created, resource: @rule, metadata: { name: @rule.name })
        redirect_to org_upsell_rule_path(@rule), notice: "Upsell rule created."
      else
        ensure_template_for_form
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      ensure_template_for_form
    end

    def update
      if @rule.update(rule_params)
        log_audit(:upsell_rule_updated, resource: @rule, metadata: {
          name: @rule.name,
          changed_fields: @rule.saved_changes.except("updated_at").keys
        })
        redirect_to org_upsell_rule_path(@rule), notice: "Upsell rule updated."
      else
        ensure_template_for_form
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle
      @rule.update!(active: !@rule.active)
      log_audit(:upsell_rule_updated, resource: @rule, metadata: {
        name: @rule.name,
        active: @rule.active
      })

      respond_to do |format|
        format.turbo_stream do
          flash.now[:toast] = {
            message: @rule.active? ? "Upsell rule activated." : "Upsell rule deactivated.",
            type: "success"
          }
          render turbo_stream: [
            turbo_stream.replace(
              dom_id(@rule),
              partial: "org/upsell_rules/rule_row",
              locals: {
                rule: @rule,
                rules: Current.organization.upsell_rules.by_priority.includes(:trigger_service, :suggested_service)
              }
            ),
            turbo_stream.replace("flash_messages", partial: "shared/flash")
          ]
        end
        format.html { redirect_to org_upsell_rules_path, notice: @rule.active? ? "Upsell rule activated." : "Upsell rule deactivated." }
      end
    end

    def move_up
      swap_with_adjacent(@rule, direction: :up)
    end

    def move_down
      swap_with_adjacent(@rule, direction: :down)
    end

    def destroy
      rule_id = @rule.id
      name = @rule.name

      if @rule.destroy
        log_audit(:upsell_rule_deleted, metadata: { upsell_rule_id: rule_id, name: name })
        redirect_to org_upsell_rules_path, notice: "Upsell rule deleted."
      else
        redirect_to org_upsell_rules_path, alert: "Failed to delete upsell rule: #{@rule.errors.full_messages.join(', ')}"
      end
    end

    private

    def authorize_manage
      authorize Current.organization, :manage?, policy_class: UpsellPolicy
    end

    def set_rule
      @rule = Current.organization.upsell_rules
        .includes(:trigger_service, :suggested_service, :upsell_templates, :upsell_counters)
        .find(params[:id])
    end

    def load_services
      @services = Current.organization.services.visible.by_display_order
    end

    def next_priority
      (Current.organization.upsell_rules.minimum(:priority) || 1) - 1
    end

    def ensure_template_for_form
      @rule.upsell_templates.build if @rule.upsell_templates.empty?
    end

    def rule_params
      params.require(:upsell_rule).permit(
        :name,
        :trigger_service_id,
        :suggested_service_id,
        :frequency_type,
        :frequency_value,
        :visit_type,
        :cooldown_days,
        :min_age,
        :max_age,
        :active_from,
        :active_until,
        :active_hours_start,
        :active_hours_end,
        :daily_limit,
        :hourly_limit,
        :active,
        upsell_templates_attributes: [ :id, :title, :description, :cta_text, :_destroy ]
      )
    end

    def swap_with_adjacent(rule, direction:)
      scope = Current.organization.upsell_rules.by_priority.to_a
      index = scope.index(rule)
      return redirect_to_reorder unless index

      swap_index = direction == :up ? index - 1 : index + 1
      return redirect_to_reorder unless swap_index.between?(0, scope.length - 1)

      other = scope[swap_index]
      rule_priority = rule.priority
      other_priority = other.priority

      UpsellRule.transaction do
        rule.update!(priority: other_priority)
        other.update!(priority: rule_priority)
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "upsell_rules_table_body",
            partial: "org/upsell_rules/table_body",
            locals: { rules: Current.organization.upsell_rules.by_priority.includes(:trigger_service, :suggested_service) }
          )
        end
        format.html { redirect_to org_upsell_rules_path }
      end
    end

    def redirect_to_reorder
      redirect_to org_upsell_rules_path
    end
  end
end
