# frozen_string_literal: true

class CalendarPolicy < ApplicationPolicy
  def manage?
    user&.has_permission?("app.calendars.manage", organization: organization_from_record) || false
  end
end
