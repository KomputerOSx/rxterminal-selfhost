# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def update?
    user&.has_permission?("app.organization.manage", organization: record) || false
  end
end
