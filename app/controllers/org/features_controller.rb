module Org
  class FeaturesController < BaseController
    PORTAL_DEPENDENT_FEATURES = %w[
      online_appointment_booking
      mobile_service_request
      online_appointment_check
      portal_opening_times
      portal_contact_page
    ].freeze

    def index
      authorize Current.organization, :update?, policy_class: OrganizationPolicy

      @features = OrgFeature.all
    end

    def update
      authorize Current.organization, :update?, policy_class: OrganizationPolicy

      # Only writes keys from the catalog - a crafted request can't write arbitrary keys
      # into the features JSON column.
      available_keys = OrgFeature.keys
      submitted = params.fetch(:features, {}).to_unsafe_h

      submitted.each do |key, attrs|
        next unless available_keys.include?(key)

        enabled = ActiveModel::Type::Boolean.new.cast(attrs["enabled"])

        Current.organization.update_feature!(key, enabled: enabled)
      end

      disable_portal_dependents_unless_portal_enabled!

      log_audit(:organization_feature_settings_updated, resource: Current.organization)
      redirect_to org_features_path, notice: "Feature settings updated."
    end

    private

    def disable_portal_dependents_unless_portal_enabled!
      return if Current.organization.public_portal_enabled?

      PORTAL_DEPENDENT_FEATURES.each do |key|
        next unless Current.organization.feature_org_setting_enabled?(key)

        Current.organization.update_feature!(key, enabled: false)
      end
    end
  end
end
