# Mixed into the tenant model (Organization). Three independent gates must all pass for
# a feature to be "on": Feature.enabled (global kill switch), FeatureOrganizationAccess.enabled
# (per-org grant), and the org's own opt-in stored in the `features` JSON column (only
# checked when the feature requires it).
module FeatureToggleable
  extend ActiveSupport::Concern

  def feature_enabled?(key)
    feature = Feature.find_by(key: key.to_s)
    return false unless feature&.available_to_organization?(self)

    !feature.org_opt_in_required? || feature_org_setting_enabled?(key)
  end

  def feature_available?(key)
    Feature.exists?(key: key.to_s, enabled: true)
  end

  def feature_admin_enabled?(key)
    feature = Feature.find_by(key: key.to_s)
    feature&.available_to_organization?(self) || false
  end

  def feature_org_setting_enabled?(key)
    features.dig(key.to_s, "enabled") == true
  end

  def feature_settings(key)
    features[key.to_s] || {}
  end

  def update_feature!(key, new_settings)
    current = features[key.to_s] || {}
    update!(features: features.merge(key.to_s => current.merge(new_settings.stringify_keys)))
  end

  def waiting_time_enabled?
    feature_enabled?(:waiting_time)
  end

  def public_portal_enabled?
    feature_enabled?(:public_portal)
  end

  def online_appointment_booking_enabled?
    public_portal_enabled? && feature_enabled?(:online_appointment_booking)
  end

  def mobile_service_request_enabled?
    public_portal_enabled? && feature_enabled?(:mobile_service_request)
  end

  def online_appointment_check_enabled?
    public_portal_enabled? && feature_enabled?(:online_appointment_check)
  end

  def portal_opening_times_enabled?
    public_portal_enabled? && feature_enabled?(:portal_opening_times)
  end

  def portal_contact_page_enabled?
    public_portal_enabled? && feature_enabled?(:portal_contact_page)
  end

  def waiting_time_reset_at
    ts = features.dig("waiting_time", "reset_at")
    ts ? Time.zone.parse(ts) : nil
  end

  def reset_waiting_time_timer!
    current = features["waiting_time"] || {}
    update!(features: features.merge("waiting_time" => current.merge("reset_at" => Time.current.iso8601)))
  end
end
