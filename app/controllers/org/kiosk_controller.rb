# frozen_string_literal: true

module Org
  class KioskController < BaseController
    include KioskPreviewMode

    before_action :authorize_configure, only: [ :show, :update ]
    before_action :authorize_preview, only: [ :preview, :exit_preview ]

    def show
      @services = Current.organization.services.visible.active.by_display_order
      @layout_services = kiosk_layout_services
    end

    def update
      organization = Current.organization
      organization.assign_attributes(kiosk_params.except(:kiosk_theme_custom))
      organization.assign_kiosk_theme_custom_from_params(kiosk_params[:kiosk_theme_custom])

      if organization.valid?
        ActiveRecord::Base.transaction do
          organization.save!
          update_layout_services!
        end

        log_audit(:organization_updated, resource: organization, metadata: {
          changed_fields: organization.saved_changes.except("updated_at").keys,
          section: "kiosk"
        })
        redirect_to org_kiosk_path, notice: "Kiosk settings updated."
      else
        @services = organization.services.visible.active.by_display_order
        @layout_services = kiosk_layout_services
        render :show, status: :unprocessable_entity
      end
    end

    def preview
      enter_kiosk_preview!(organization: Current.organization, user: Current.user)
      redirect_to kiosk_root_path
    end

    def exit_preview
      exit_kiosk_preview!
      redirect_to org_kiosk_path, notice: "Exited kiosk preview."
    end

    private

    def authorize_configure
      authorize Current.organization, policy_class: KioskConfigPolicy
    end

    def authorize_preview
      authorize Current.organization, :preview?, policy_class: KioskConfigPolicy
    end

    def kiosk_layout_services
      Current.organization.services.visible.order(active: :desc, featured: :desc, display_order: :asc, display_name: :asc)
    end

    def kiosk_params
      params.fetch(:organization, {}).permit(
        :kiosk_show_featured_service,
        :kiosk_show_services,
        :kiosk_show_appointments,
        :kiosk_featured_service_id,
        :kiosk_theme,
        kiosk_theme_custom: Organization::CUSTOM_THEME_KEYS.map(&:to_sym)
      )
    end

    def update_layout_services!
      ids = Array(params[:service_order]).map(&:to_i)
      return if ids.empty?

      services = Current.organization.services.visible.where(id: ids).index_by(&:id)
      service_params = params.fetch(:services, {})

      ids.each_with_index do |id, index|
        service = services[id]
        next unless service

        attrs = layout_service_attrs(service_params[id.to_s] || service_params[id])
        attrs[:display_order] = index
        service.update!(attrs)
      end
    end

    def layout_service_attrs(raw_attrs)
      return {} unless raw_attrs.respond_to?(:permit)

      attrs = raw_attrs.permit(:featured, :active, :icon)
      result = {}
      result[:featured] = ActiveModel::Type::Boolean.new.cast(attrs[:featured]) if attrs.key?(:featured)
      result[:active] = ActiveModel::Type::Boolean.new.cast(attrs[:active]) if attrs.key?(:active)

      if attrs.key?(:icon)
        icon = attrs[:icon].presence
        result[:icon] = icon if icon.blank? || valid_kiosk_icon?(icon)
      end

      result
    end

    def valid_kiosk_icon?(icon)
      ApplicationHelper::MATERIAL_ICON_GROUPS.values.flatten.include?(icon)
    end
  end
end
