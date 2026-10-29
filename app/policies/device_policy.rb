# frozen_string_literal: true

class DevicePolicy < ApplicationPolicy
  def manage?
    user&.has_permission?("app.devices.manage", organization: organization_from_record) || false
  end
end
