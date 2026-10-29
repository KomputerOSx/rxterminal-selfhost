# frozen_string_literal: true

module AuditLogging
  extend ActiveSupport::Concern

  private

  def log_audit(event_type, user: current_user, resource: nil, metadata: {}, organization: nil)
    org = organization || audit_organization_from_context
    merged_metadata = audit_log_base_metadata(org).merge(metadata)

    AuditLog.log!(
      event_type: event_type,
      user: user,
      resource: resource,
      organization: org,
      metadata: merged_metadata,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  rescue => e
    Rails.logger.error "[AuditLog] #{e.class}: #{e.message} - event=#{event_type} user=#{user&.id}"
  end

  def audit_log_base_metadata(organization)
    metadata = { controller: "#{params[:controller]}##{params[:action]}" }
    metadata[:organization_id] = organization.id if organization
    metadata
  end

  def audit_organization_from_context
    return Current.organization if Current.organization.present?
    return @organization if defined?(@organization) && @organization.present?

    nil
  end
end
