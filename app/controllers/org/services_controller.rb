# frozen_string_literal: true

module Org
  class ServicesController < BaseController
    before_action :authorize_manage
    before_action :set_service, only: [ :show, :edit, :update, :destroy, :toggle, :move_up, :move_down ]

    def index
      @services = Current.organization.services.plan_active.by_display_order
      @active_count = @services.count(&:active?)
    end

    def show
    end

    def new
      @service = Current.organization.services.build
      @calendars = active_calendars
    end

    def create
      return if block_if_at_service_limit!

      @service = Current.organization.services.build(service_params)
      @service.display_order = next_display_order
      @calendars = active_calendars

      if @service.save(context: :ui_save)
        log_audit(:service_created, resource: @service, metadata: { internal_name: @service.internal_name })
        redirect_to org_service_path(@service), notice: "Service created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @calendars = active_calendars
    end

    def update
      @calendars = active_calendars
      new_calendar_id = service_params[:calendar_id].presence
      calendar_changed = new_calendar_id && new_calendar_id.to_i != @service.calendar_id.to_i
      new_calendar = new_calendar_id ? Current.organization.calendars.active.find_by(id: new_calendar_id) : nil

      @service.assign_attributes(service_params)

      if @service.save(context: :ui_save)
        @service.move_to_calendar!(new_calendar) if calendar_changed && new_calendar
        log_audit(:service_updated, resource: @service, metadata: {
          internal_name: @service.internal_name,
          changed_fields: @service.saved_changes.except("updated_at").keys
        })
        redirect_to org_service_path(@service), notice: "Service updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle
      @service.update!(active: !@service.active)
      log_audit(:service_updated, resource: @service, metadata: {
        internal_name: @service.internal_name,
        active: @service.active
      })

      respond_to do |format|
        format.turbo_stream do
          flash.now[:toast] = {
            message: @service.active? ? "Service activated." : "Service deactivated.",
            type: "success"
          }
          render turbo_stream: [
            turbo_stream.replace(
              dom_id(@service),
              partial: "org/services/service_row",
              locals: { service: @service }
            ),
            turbo_stream.replace("flash_messages", partial: "shared/flash")
          ]
        end
        format.html { redirect_to org_services_path, notice: @service.active? ? "Service activated." : "Service deactivated." }
      end
    end

    def move_up
      swap_with_adjacent(@service, direction: :up)
    end

    def move_down
      swap_with_adjacent(@service, direction: :down)
    end

    def destroy
      service_id = @service.id
      internal_name = @service.internal_name

      if @service.soft_delete!(deleted_by: current_user)
        log_audit(:service_deleted, metadata: { service_id: service_id, internal_name: internal_name })
        redirect_to org_services_path, notice: "Service deleted."
      else
        redirect_to org_service_path(@service), alert: "Failed to delete service: #{@service.errors.full_messages.join(', ')}"
      end
    end

    private

    def authorize_manage
      authorize Current.organization, :manage?, policy_class: ServicePolicy
    end

    def set_service
      @service = Current.organization.services.visible.find(params[:id])
    end

    def active_calendars
      Current.organization.calendars.active.ordered
    end

    def next_display_order
      (Current.organization.services.visible.maximum(:display_order) || -1) + 1
    end

    def service_params
      permitted = params.require(:service).permit(
        :internal_name,
        :display_name,
        :description,
        :allows_private_consultation,
        :requires_appointment,
        :allows_immediate,
        :estimated_duration,
        :active,
        :display_order,
        :icon,
        :price,
        :calendar_id,
        eligibility_requirements: { eligible: [], not_eligible: [], additional: [] }
      )
      permitted.delete(:requires_appointment) unless Current.organization.appointments_enabled?
      permitted.delete(:calendar_id) unless Current.organization.calendars_enabled?
      filter_eligibility_requirements(permitted)
    end

    def filter_eligibility_requirements(permitted)
      req = permitted[:eligibility_requirements]
      return permitted.merge(eligibility_requirements: {}) unless req

      %w[eligible not_eligible additional].each do |key|
        req[key] = req[key]&.reject(&:blank?) || []
      end
      permitted
    end

    def swap_with_adjacent(service, direction:)
      scope = Current.organization.services.visible.by_display_order.to_a
      index = scope.index(service)
      return redirect_to_reorder unless index

      swap_index = direction == :up ? index - 1 : index + 1
      return redirect_to_reorder unless swap_index.between?(0, scope.length - 1)

      other = scope[swap_index]
      service_order = service.display_order
      other_order = other.display_order

      Service.transaction do
        service.update!(display_order: other_order)
        other.update!(display_order: service_order)
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "services_table_body",
            partial: "org/services/table_body",
            locals: { services: Current.organization.services.visible.by_display_order }
          )
        end
        format.html { redirect_to org_services_path }
      end
    end

    def redirect_to_reorder
      redirect_to org_services_path
    end
  end
end
