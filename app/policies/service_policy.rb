# frozen_string_literal: true

class ServicePolicy < ApplicationPolicy
  def manage?
    user&.has_permission?("app.services.manage", organization: organization_from_record) || false
  end
end
