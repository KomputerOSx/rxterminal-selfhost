module Onboarding
  Step = Struct.new(:key, :title, :description, :view, keyword_init: true)

  STEPS = [
    Step.new(key: "welcome", title: "Welcome",
      description: "Let's get your account set up.",
      view: "onboarding/steps/welcome"),
    Step.new(key: "profile", title: "Tell us about you",
      description: "A little context helps us tailor your experience.",
      view: "onboarding/steps/profile"),
    Step.new(key: "organization", title: "Your organization",
      description: "Tell us about the organization you are setting up.",
      view: "onboarding/steps/organization"),
    Step.new(key: "business_type", title: "What kind of business is this?",
      description: "We'll suggest some starter services to get you going.",
      view: "onboarding/steps/business_type"),
    Step.new(key: "data_collection", title: "Customer details",
      description: "Choose what you need from customers when they check in.",
      view: "onboarding/steps/data_collection"),
    Step.new(key: "time_zone", title: "Time zone",
      description: "Used to work out what day it is for your queues and appointments.",
      view: "onboarding/steps/time_zone"),
    Step.new(key: "currency", title: "Currency",
      description: "Choose the currency your service prices are shown in.",
      view: "onboarding/steps/currency"),
    Step.new(key: "finish", title: "You're all set",
      description: "You're ready to go.",
      view: "onboarding/steps/finish")
  ].freeze

  module_function

  def steps = STEPS
  def keys = STEPS.map(&:key)
  def find(key) = STEPS.find { |s| s.key == key.to_s }
  def first_step = STEPS.first
  def last_step = STEPS.last
  def last_step?(key) = key.to_s == last_step.key
  def index_of(key) = keys.index(key.to_s)
  def step_before(key) = (i = index_of(key)) && i > 0 ? STEPS[i - 1] : nil
  def step_after(key) = (i = index_of(key)) && STEPS[i + 1]
end
