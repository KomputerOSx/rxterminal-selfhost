# frozen_string_literal: true

class KioskConfigPolicy < ApplicationPolicy
  def show?
    configure?
  end

  def preview?
    configure?
  end

  def update?
    configure?
  end

  private

  def configure?
    user&.has_permission?("app.kiosk.configure", organization: record) || false
  end
end
