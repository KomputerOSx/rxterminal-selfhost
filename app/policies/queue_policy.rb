# frozen_string_literal: true

class QueuePolicy < ApplicationPolicy
  def index?
    user&.has_permission?("app.queue.view", organization: organization_from_record) || false
  end

  def manage?
    user&.has_permission?("app.queue.manage", organization: organization_from_record) || false
  end
end
