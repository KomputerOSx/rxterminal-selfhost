# frozen_string_literal: true

class AppointmentPolicy < ApplicationPolicy
  def index?
    user&.has_permission?("app.appointments.view", organization: organization_from_record) || false
  end

  def show?
    index?
  end

  def manage?
    user&.has_permission?("app.appointments.manage", organization: organization_from_record) || false
  end

  alias new? manage?
  alias create? manage?
  alias edit? manage?
  alias update? manage?
  alias check_in? manage?
  alias cancel? manage?
  alias no_show? manage?
  alias return_to_booked? manage?
  alias slots? index?
  alias search? index?
  alias print? index?
end
