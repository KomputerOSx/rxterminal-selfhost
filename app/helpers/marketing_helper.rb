# frozen_string_literal: true

module MarketingHelper
  PLAN_FEATURES = {
    "starter" => [
      "1 team member",
      "Up to 3 services",
      "200 requests per month",
      "Staff queue & walk-in",
      "7-day audit history",
      "Email support (Mon–Fri)"
    ],
    "business" => [
      "Unlimited team members",
      "Unlimited services & requests",
      "Appointments & kiosk devices",
      "Custom domain for your portal",
      "Full audit log history",
      "Priority email support"
    ]
  }.freeze

  def marketing_plan_features(plan)
    PLAN_FEATURES.fetch(plan.key, [])
  end
end
