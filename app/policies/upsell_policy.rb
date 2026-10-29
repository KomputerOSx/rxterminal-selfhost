# frozen_string_literal: true

class UpsellPolicy < ApplicationPolicy
  def manage?
    user&.has_permission?("app.upsells.manage", organization: organization_from_record) || false
  end
end
