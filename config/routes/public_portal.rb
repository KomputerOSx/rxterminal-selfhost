# frozen_string_literal: true

scope module: :public do
  root "home#index", as: :portal_root
  get  "privacy",        to: "privacy#show",   as: :portal_privacy
  post "privacy/accept", to: "privacy#accept", as: :accept_portal_privacy
  get  "arrive",         to: "arrivals#show",  as: :portal_arrive
  get  "walk-in",          to: "walk_in_service_requests#new",       as: :new_portal_walk_in
  post "walk-in",          to: "walk_in_service_requests#create",    as: :portal_walk_in
  get  "walk-in/success",  to: "walk_in_service_requests#success",   as: :portal_walk_in_success
  get  "walk-in/my-queue", to: "walk_in_service_requests#my_queue",  as: :portal_walk_in_my_queue
  get  "appointment-checkin",            to: "appointment_checkins#new",        as: :new_portal_appointment_checkin
  post "appointment-checkin",            to: "appointment_checkins#create",     as: :portal_appointment_checkin
  get  "appointment-checkin/early",      to: "appointment_checkins#early",      as: :portal_appointment_checkin_early
  get  "appointment-checkin/late",       to: "appointment_checkins#late",       as: :portal_appointment_checkin_late
  get  "appointment-checkin/select",     to: "appointment_checkins#select",     as: :portal_appointment_checkin_select
  post "appointment-checkin/select",     to: "appointment_checkins#confirm",    as: :portal_appointment_checkin_confirm
  get  "appointment-checkin/success",    to: "appointment_checkins#success",    as: :portal_appointment_checkin_success
  get  "walk-in/upsell",             to: "walk_in_upsells#show",      as: :portal_walk_in_upsell
  post "walk-in/upsell/accept",      to: "walk_in_upsells#accept",    as: :accept_portal_walk_in_upsell
  post "walk-in/upsell/book-later",  to: "walk_in_upsells#book_later", as: :book_later_portal_walk_in_upsell
  post "walk-in/upsell/decline",     to: "walk_in_upsells#decline",   as: :decline_portal_walk_in_upsell
  get  "walk-in/upsell/confirmed",   to: "walk_in_upsells#confirmed", as: :confirmed_portal_walk_in_upsell
  get  "privacy-policy", to: "legal#privacy_policy", as: :portal_privacy_policy
  get  "gdpr",           to: "legal#gdpr",           as: :portal_gdpr
  get  "terms",          to: "legal#terms",          as: :portal_terms
  get  "cookies",        to: "legal#cookies_policy", as: :portal_cookies
  get  "opening-times",  to: "info#opening_times",   as: :portal_opening_times
  get  "contact",        to: "info#contact",         as: :portal_contact
  get  "appointments",           to: "appointments#new"
  get  "appointments/new",       to: "appointments#new",          as: :new_portal_appointment
  post "appointments",           to: "appointments#create",       as: :portal_appointments
  get  "appointments/confirmed",        to: "appointments#confirmed",    as: :portal_appointment_confirmed
  get  "appointments/:id/calendar.ics", to: "appointments#ics",          as: :portal_appointment_ics
  get  "appointments/calendar",  to: "appointments#calendar",     as: :portal_appointment_calendar
  get  "appointments/slots",     to: "appointments#slot_options", as: :portal_appointment_slots
end
