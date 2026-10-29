# frozen_string_literal: true

class OrganizationLogoReviewReminderJob < ApplicationJob
  queue_as :default

  def perform
    pending_count = OrganizationLogo.pending.count
    return if pending_count.zero?

    User.joins(:roles).where(roles: { scope: :system, name: Role::SYSTEM_ADMIN }).distinct.find_each do |admin|
      OrganizationLogoReviewMailer.pending_reminder(admin, pending_count).deliver_later
    end
  end
end
