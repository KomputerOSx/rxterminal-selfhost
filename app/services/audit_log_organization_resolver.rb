# frozen_string_literal: true

class AuditLogOrganizationResolver
  RESOURCE_MODELS = {
    "Service" => Service,
    "ServiceRequest" => ServiceRequest,
    "Appointment" => Appointment,
    "Calendar" => Calendar,
    "Device" => Device,
    "UpsellRule" => UpsellRule,
    "Membership" => Membership
  }.freeze

  def self.preload!(audit_logs)
    new(audit_logs).preload!
  end

  def self.organization_id_for(audit_log)
    new([ audit_log ]).organization_id_for(audit_log)
  end

  def initialize(audit_logs)
    @audit_logs = Array(audit_logs)
  end

  def preload!
    resource_org_ids = resource_organization_ids(@audit_logs)
    organization_ids = Set.new

    @audit_logs.each do |log|
      org_id = organization_id_for(log, resource_org_ids: resource_org_ids)
      log.resolved_organization_id = org_id
      organization_ids << org_id if org_id
    end

    organizations = Organization.where(id: organization_ids.to_a).index_by(&:id)

    @audit_logs.each do |log|
      log.resolved_organization = organizations[log.resolved_organization_id]
    end

    organizations
  end

  def organization_id_for(audit_log, resource_org_ids: nil)
    return audit_log.resource_id if audit_log.resource_type == "Organization" && audit_log.resource_id.present?

    metadata = audit_log.metadata.is_a?(Hash) ? audit_log.metadata : {}
    metadata_id = metadata["organization_id"] || metadata[:organization_id]
    return metadata_id.to_i if metadata_id.present?

    mapping = resource_org_ids || resource_organization_ids([ audit_log ])
    mapping[[ audit_log.resource_type, audit_log.resource_id ]]
  end

  private

  def resource_organization_ids(audit_logs)
    mapping = {}

    audit_logs.group_by(&:resource_type).each do |resource_type, logs|
      model = RESOURCE_MODELS[resource_type]
      next unless model

      ids = logs.filter_map(&:resource_id).uniq
      next if ids.empty?

      model.where(id: ids).pluck(:id, :organization_id).each do |resource_id, organization_id|
        mapping[[ resource_type, resource_id ]] = organization_id if organization_id
      end
    end

    mapping
  end
end
