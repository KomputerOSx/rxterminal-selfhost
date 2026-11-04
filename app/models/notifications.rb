module Notifications
  CATEGORIES = {
    "membership"   => { label: "Membership & invitations", always_on: false },
    "security"     => { label: "Security alerts", always_on: true },
    "appointments" => { label: "Appointments", always_on: false },
    "admin"        => { label: "Admin & system", always_on: false }
  }.freeze

  # Categories a user can opt out of - always_on categories (e.g. security) are never shown in preference UI and never checked.
  OPTIONAL_CATEGORIES = CATEGORIES.reject { |_, v| v[:always_on] }.keys.freeze
end
