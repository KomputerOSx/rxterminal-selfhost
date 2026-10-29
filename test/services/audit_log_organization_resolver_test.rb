# frozen_string_literal: true

require "test_helper"

class AuditLogOrganizationResolverTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "audit_resolver_svc",
      display_name: "Audit Resolver Service",
      estimated_duration: 15,
      active: true
    )
  end

  test "resolves organization from resource type Organization" do
    log = AuditLog.create!(
      event_type: :organization_updated,
      resource_type: "Organization",
      resource_id: @organization.id
    )

    assert_equal @organization.id, AuditLogOrganizationResolver.organization_id_for(log)
  end

  test "resolves organization from metadata organization_id" do
    log = AuditLog.create!(
      event_type: :customer_called,
      metadata: { organization_id: @organization.id }
    )

    assert_equal @organization.id, AuditLogOrganizationResolver.organization_id_for(log)
  end

  test "resolves organization from org-scoped resource" do
    log = AuditLog.create!(
      event_type: :service_updated,
      resource_type: "Service",
      resource_id: @service.id
    )

    assert_equal @organization.id, AuditLogOrganizationResolver.organization_id_for(log)
  end

  test "preload assigns resolved organization records" do
    log = AuditLog.create!(
      event_type: :service_updated,
      resource_type: "Service",
      resource_id: @service.id
    )

    AuditLogOrganizationResolver.preload!([ log ])

    assert_equal @organization, log.resolved_organization
    assert_equal @organization.id, log.resolved_organization_id
  end
end
