# frozen_string_literal: true

module Org
  class OpeningHoursController < BaseController
    include PortalConfigParams

    before_action :authorize_configure

    def show
    end

    def update
      if Current.organization.update(operating_hours: build_operating_hours_from_params)
        log_audit(:organization_updated, resource: Current.organization, metadata: {
          changed_fields: Current.organization.saved_changes.except("updated_at").keys,
          section: "opening_hours"
        })
        redirect_to org_opening_hours_path, notice: "Opening hours updated."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def authorize_configure
      authorize Current.organization, :update?, policy_class: PortalConfigPolicy
    end
  end
end
