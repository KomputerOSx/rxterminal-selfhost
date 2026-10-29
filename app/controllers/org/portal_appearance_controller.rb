# frozen_string_literal: true

module Org
  class PortalAppearanceController < BaseController
    before_action :authorize_configure

    def show
    end

    def update
      organization = Current.organization
      organization.assign_attributes(portal_appearance_params.except(:portal_theme_custom))
      organization.assign_portal_theme_custom_from_params(portal_appearance_params[:portal_theme_custom])

      if organization.save
        log_audit(:organization_updated, resource: organization, metadata: {
          changed_fields: organization.saved_changes.except("updated_at").keys,
          section: "portal_appearance"
        })
        redirect_to org_portal_appearance_path, notice: "Portal appearance updated."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def authorize_configure
      authorize Current.organization, policy_class: PortalConfigPolicy
    end

    def portal_appearance_params
      params.fetch(:organization, {}).permit(
        :portal_theme,
        portal_theme_custom: Organization::PORTAL_CUSTOM_THEME_KEYS.map(&:to_sym)
      )
    end
  end
end
