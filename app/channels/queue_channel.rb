# frozen_string_literal: true

class QueueChannel < ApplicationCable::Channel
  def subscribed
    organization = Organization.find_by(id: params[:organization_id])
    unless organization && authorized_for?(organization)
      reject
      return
    end

    stream_from "organization_#{organization.id}_queue"
  end

  private

  def authorized_for?(organization)
    current_user&.has_permission?("app.queue.view", organization: organization)
  end
end
