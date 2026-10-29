class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  serialize :metadata, coder: JSON

  enum :event_type, {
    login_success: "login_success",
    login_failure: "login_failure",
    logout: "logout",
    session_created: "session_created",
    session_destroyed: "session_destroyed",
    account_locked: "account_locked",
    account_unlocked: "account_unlocked",
    two_factor_challenge_sent: "two_factor_challenge_sent",
    two_factor_success: "two_factor_success",
    two_factor_failure: "two_factor_failure",
    totp_enabled: "totp_enabled",
    totp_disabled: "totp_disabled",
    totp_email_fallback_requested: "totp_email_fallback_requested",
    user_registered: "user_registered",
    account_confirmed: "account_confirmed",
    email_change_requested: "email_change_requested",
    email_change_confirmed_old: "email_change_confirmed_old",
    email_change_confirmed_new: "email_change_confirmed_new",
    email_change_completed: "email_change_completed",
    email_change_cancelled: "email_change_cancelled",
    password_change: "password_change",
    password_reset_requested: "password_reset_requested",
    password_reset_link_sent: "password_reset_link_sent",
    password_reset_completed: "password_reset_completed",
    password_reset_failed: "password_reset_failed",
    user_deleted: "user_deleted",
    rate_limit_triggered: "rate_limit_triggered",
    role_granted: "role_granted",
    role_revoked: "role_revoked",
    authorization_denied: "authorization_denied",
    organization_created: "organization_created",
    membership_created: "membership_created",
    membership_destroyed: "membership_destroyed",
    organization_invitation_sent: "organization_invitation_sent",
    organization_invitation_accepted: "organization_invitation_accepted",
    organization_invitation_revoked: "organization_invitation_revoked",
    owner_removal_blocked: "owner_removal_blocked",
    owner_promoted: "owner_promoted",
    owner_demoted: "owner_demoted",
    account_deletion_blocked: "account_deletion_blocked",
    organization_updated: "organization_updated",
    notification_created: "notification_created",
    notification_withdrawn: "notification_withdrawn",
    email_campaign_created: "email_campaign_created",
    email_campaign_updated: "email_campaign_updated",
    email_campaign_deleted: "email_campaign_deleted",
    email_campaign_sent: "email_campaign_sent",
    maintenance_mode_enabled: "maintenance_mode_enabled",
    maintenance_mode_disabled: "maintenance_mode_disabled",
    sessions_force_logged_out: "sessions_force_logged_out",
    user_disabled: "user_disabled",
    user_enabled: "user_enabled",
    user_updated: "user_updated",
    role_created: "role_created",
    role_updated: "role_updated",
    role_deleted: "role_deleted",
    permission_created: "permission_created",
    permission_updated: "permission_updated",
    permission_deleted: "permission_deleted",
    feature_updated: "feature_updated",
    feature_access_granted: "feature_access_granted",
    feature_access_revoked: "feature_access_revoked",
    organization_feature_settings_updated: "organization_feature_settings_updated",
    subscription_created: "subscription_created",
    subscription_updated: "subscription_updated",
    subscription_cancelled: "subscription_cancelled",
    subscription_resumed: "subscription_resumed",
    subscription_downgrade_scheduled: "subscription_downgrade_scheduled",
    subscription_downgrade_cancelled: "subscription_downgrade_cancelled",
    plan_reconciliation_completed: "plan_reconciliation_completed",
    payment_method_updated: "payment_method_updated",
    payment_method_removed: "payment_method_removed",
    billing_details_updated: "billing_details_updated",
    promotion_code_applied: "promotion_code_applied",
    promotion_code_removed: "promotion_code_removed",
    price_migration_started: "price_migration_started",
    price_migration_scheduled: "price_migration_scheduled",
    organization_grandfathered: "organization_grandfathered",
    organization_ungrandfathered: "organization_ungrandfathered",
    custom_domain_updated: "custom_domain_updated",
    custom_domain_removed: "custom_domain_removed",
    service_created: "service_created",
    service_updated: "service_updated",
    service_deleted: "service_deleted",
    calendar_created: "calendar_created",
    calendar_updated: "calendar_updated",
    calendar_archived: "calendar_archived",
    upsell_rule_created: "upsell_rule_created",
    upsell_rule_updated: "upsell_rule_updated",
    upsell_rule_deleted: "upsell_rule_deleted",
    appointment_created: "appointment_created",
    appointment_updated: "appointment_updated",
    appointment_cancelled: "appointment_cancelled",
    appointment_checked_in: "appointment_checked_in",
    appointment_no_show: "appointment_no_show",
    appointment_reverted_to_booked: "appointment_reverted_to_booked",
    appointment_opening_created: "appointment_opening_created",
    appointment_opening_updated: "appointment_opening_updated",
    appointment_opening_deleted: "appointment_opening_deleted",
    appointment_blocked_date_created: "appointment_blocked_date_created",
    appointment_blocked_date_deleted: "appointment_blocked_date_deleted",
    appointment_blocked_dates_imported: "appointment_blocked_dates_imported",
    device_created: "device_created",
    device_updated: "device_updated",
    device_key_regenerated: "device_key_regenerated",
    device_ip_cleared: "device_ip_cleared",
    device_auth_success: "device_auth_success",
    device_auth_failure: "device_auth_failure",
    customer_called: "customer_called",
    customer_status_updated: "customer_status_updated",
    customer_reactivated: "customer_reactivated",
    customer_reverted: "customer_reverted",
    wait_timer_reset: "wait_timer_reset",
    walk_in_created: "walk_in_created",
    customer_pii_redacted: "customer_pii_redacted",
    customer_pii_report_exported: "customer_pii_report_exported",
    subject_access_exported: "subject_access_exported",
    payment_failed: "payment_failed",
    new_device_login: "new_device_login",
    appointment_booked_online: "appointment_booked_online",
    organization_logo_submitted: "organization_logo_submitted",
    organization_logo_approved: "organization_logo_approved",
    organization_logo_declined: "organization_logo_declined",
    organization_logo_activated: "organization_logo_activated",
    organization_logo_withdrawn: "organization_logo_withdrawn"
  }

  validates :event_type, presence: true

  def self.log!(event_type:, resource: nil, organization: nil, metadata: {}, user: nil, ip_address: nil, user_agent: nil)
    create!(
      user: user,
      event_type: event_type,
      ip_address: ip_address,
      user_agent: user_agent,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      metadata: metadata
    )

    Notifications::Registry.dispatch!(
      event_type: event_type,
      actor_id: user&.id,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      organization_id: organization&.id,
      metadata: metadata
    )
  end

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }
  scope :security_events, -> { where(event_type: %w[login_failure account_locked rate_limit_triggered password_reset_requested password_reset_failed authorization_denied owner_removal_blocked]) }

  attr_writer :resolved_organization, :resolved_organization_id

  def resolved_organization
    return @resolved_organization if instance_variable_defined?(:@resolved_organization)

    AuditLogOrganizationResolver.preload!([ self ])
    @resolved_organization
  end

  def resolved_organization_id
    return @resolved_organization_id if instance_variable_defined?(:@resolved_organization_id)

    AuditLogOrganizationResolver.preload!([ self ])
    @resolved_organization_id
  end
end
