# frozen_string_literal: true

get "robots.txt",  to: "robots#show"
get "sitemap.xml", to: "sitemaps#show"

scope module: :public do
  root "home#index", as: :custom_domain_portal_root
  get  "privacy",        to: "privacy#show"
  post "privacy/accept", to: "privacy#accept"
  get  "arrive",         to: "arrivals#show"
  get  "walk-in",          to: "walk_in_service_requests#new"
  post "walk-in",          to: "walk_in_service_requests#create"
  get  "walk-in/success",  to: "walk_in_service_requests#success"
  get  "walk-in/my-queue", to: "walk_in_service_requests#my_queue"
  get  "appointment-checkin",            to: "appointment_checkins#new"
  post "appointment-checkin",            to: "appointment_checkins#create"
  get  "appointment-checkin/early",      to: "appointment_checkins#early"
  get  "appointment-checkin/late",       to: "appointment_checkins#late"
  get  "appointment-checkin/select",     to: "appointment_checkins#select"
  post "appointment-checkin/select",     to: "appointment_checkins#confirm"
  get  "appointment-checkin/success",    to: "appointment_checkins#success"
  get  "walk-in/upsell",             to: "walk_in_upsells#show"
  post "walk-in/upsell/accept",      to: "walk_in_upsells#accept"
  post "walk-in/upsell/book-later",  to: "walk_in_upsells#book_later"
  post "walk-in/upsell/decline",     to: "walk_in_upsells#decline"
  get  "walk-in/upsell/confirmed",   to: "walk_in_upsells#confirmed"
  get  "privacy-policy", to: "legal#privacy_policy"
  get  "gdpr",           to: "legal#gdpr"
  get  "terms",          to: "legal#terms"
  get  "cookies",        to: "legal#cookies_policy"
  get  "opening-times",  to: "info#opening_times", as: :custom_domain_portal_opening_times
  get  "contact",        to: "info#contact",       as: :custom_domain_portal_contact
  get  "appointments",           to: "appointments#new"
  get  "appointments/new",       to: "appointments#new"
  post "appointments",           to: "appointments#create"
  get  "appointments/confirmed",        to: "appointments#confirmed"
  get  "appointments/:id/calendar.ics", to: "appointments#ics"
  get  "appointments/calendar",  to: "appointments#calendar"
  get  "appointments/slots",     to: "appointments#slot_options"

  get "*path", to: "/sites#show"
end
