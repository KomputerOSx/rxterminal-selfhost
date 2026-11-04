# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  # Creating an additional organization (a branch) is for the system admin and organization owners.
  def create?
    user.present? && (user.system_admin? || user.organization_owner?)
  end

  def update?
    user&.has_permission?("app.organization.manage", organization: record) || false
  end
end
