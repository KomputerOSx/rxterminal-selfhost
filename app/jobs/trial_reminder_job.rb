# frozen_string_literal: true

class TrialReminderJob < ApplicationJob
  queue_as :default

  def perform
    send_ending_soon_reminders
    send_ended_reminders
  end

  private

  def send_ending_soon_reminders
    Organization.where(trial_ends_at: 3.days.from_now.all_day).find_each do |organization|
      next if organization.subscribed?

      organization.owner_users.each do |owner|
        TrialMailer.ending_soon(organization, owner).deliver_later
      end
    end
  end

  def send_ended_reminders
    Organization.where(trial_ends_at: Time.current.all_day).find_each do |organization|
      next if organization.subscribed?

      organization.owner_users.each do |owner|
        TrialMailer.ended(organization, owner).deliver_later
      end
    end
  end
end
