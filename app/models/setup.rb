# frozen_string_literal: true

# First-run state of the install. Until the first user exists, every request is sent to /setup,
# where the first visitor creates the owner account and the organization (first come, first
# served - there is deliberately no setup token).
module Setup
  def self.required?
    !User.exists?
  end
end
