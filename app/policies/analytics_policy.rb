# frozen_string_literal: true

class AnalyticsPolicy < ApplicationPolicy
  def show?
    user&.has_permission?("app.analytics.view", organization: record) || false
  end
end
