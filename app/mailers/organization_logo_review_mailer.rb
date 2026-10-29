# frozen_string_literal: true

class OrganizationLogoReviewMailer < ApplicationMailer
  def pending_reminder(admin, pending_count)
    @admin = admin
    @pending_count = pending_count

    mail(to: admin.email, subject: "#{pending_count} #{"organization logo".pluralize(pending_count)} awaiting review")
  end
end
