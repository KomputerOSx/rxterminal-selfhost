# frozen_string_literal: true

class PortalConfigPolicy < ApplicationPolicy
  def show?
    update?
  end

  def update?
    user&.has_permission?("app.portal.configure", organization: record) || false
  end
end
