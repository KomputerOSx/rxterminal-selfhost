# frozen_string_literal: true

class TrialMailer < ApplicationMailer
  def ending_soon(organization, owner)
    @organization = organization
    @owner = owner
    @trial_plan = organization.trial_plan
    @trial_ends_at = organization.trial_ends_at
    @days_remaining = organization.trial_days_remaining

    mail(to: owner.email, subject: "Your #{@trial_plan.name} trial ends in #{@days_remaining} days")
  end

  def ended(organization, owner)
    @organization = organization
    @owner = owner
    @trial_plan = organization.trial_plan

    mail(to: owner.email, subject: "Your #{@organization.name} trial has ended")
  end
end
