# frozen_string_literal: true

class AuditLogPolicy < ApplicationPolicy
  def index?
    user&.has_permission?("app.audit_logs.view", organization: record) || false
  end

  alias show? index?
end
