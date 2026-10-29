Rails.application.routes.draw do
  # Health + internal endpoints must be outside the custom-domain catch-all.
  # kamal-proxy probes /up with a non-APP_HOST Host header; if the catch-all
  # wins first, SitesController returns 404 and the deploy never goes healthy.
  get "up" => "rails/health#show", as: :rails_health_check

  # Caddy on-demand TLS ask endpoint (internal Docker / localhost only).
  namespace :internal do
    get "domain_validations", to: "domain_validations#show"
  end

  # Custom domains serve the public portal for the mapped organization.
  constraints CustomDomainConstraint do
    draw :public_portal_custom_domain
  end

  # --- Authentication ---
  resource :session, only: [ :new, :create, :destroy ], controller: "sessions"
  get    "login",  to: "sessions#new"
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  get  "login/two_factor",                to: "sessions#two_factor",                as: :two_factor_login
  post "login/two_factor",                to: "sessions#verify_two_factor",         as: :verify_two_factor_login
  post "login/two_factor/resend",         to: "sessions#resend_two_factor",         as: :resend_two_factor_login
  post "login/two_factor/email_fallback", to: "sessions#email_two_factor_fallback", as: :email_two_factor_fallback_login

  # --- OmniAuth (Google / GitHub) ---
  # The request phase (/auth/:provider) is handled directly by the OmniAuth::Builder
  # middleware (config/initializers/omniauth.rb) - only the callback needs a route.
  get "auth/:provider/callback", to: "omniauth_callbacks#create"

  resource :password, only: [ :edit, :update ], controller: "passwords"
  resources :password_resets, only: [ :new, :create, :edit, :update ], param: :token

  get  "signup", to: "registrations#new",    as: :new_registration
  post "signup", to: "registrations#create", as: :registration
  get  "confirmations/new", to: "confirmations#new",    as: :new_confirmation
  post "confirmations",     to: "confirmations#create", as: :confirmations

  resource :profile, only: [ :show, :update, :destroy ], controller: "profile"
  resource :billing, only: [ :show ], controller: "billing" do
    resource :checkout_session, only: [ :create ], controller: "billing/checkout_sessions"
    resource :billing_portal_session, only: [ :create ], controller: "billing/billing_portal_sessions"
    resource :subscription, only: [ :create, :destroy ], controller: "billing/subscriptions" do
      resource :resume, only: [ :create ], controller: "billing/subscription_resumes"
      resource :scheduled_change, only: [ :destroy ], controller: "billing/scheduled_changes"
    end
    resource :currency, only: [ :update ], controller: "billing/currencies"
    resource :promo_code, only: [ :create, :destroy ], controller: "billing/promo_codes"
    resource :plan_reconciliation, only: [ :show, :update ], controller: "billing/plan_reconciliations"
  end
  get    "profile/totp/new",     to: "profile#new_totp",          as: :new_profile_totp
  post   "profile/totp",         to: "profile#create_totp",       as: :profile_totp
  delete "profile/totp",         to: "profile#destroy_totp"
  post   "profile/deletion_code", to: "profile#send_deletion_code", as: :profile_deletion_code
  patch  "profile/email_preferences", to: "profile#update_email_preferences", as: :profile_email_preferences
  patch  "profile/notification_preferences", to: "profile#update_notification_preferences", as: :profile_notification_preferences

  resource :profile_email_change, only: [ :new, :create, :destroy ], controller: "email_changes", path: "profile/email_change"
  post "profile/email_change/confirm_old", to: "email_changes#confirm_old", as: :confirm_old_profile_email_change
  post "profile/email_change/confirm_new", to: "email_changes#confirm_new", as: :confirm_new_profile_email_change

  root "home#index"
  get "robots.txt",  to: "robots#show"
  # `.xml` is a literal here, not a captured format, but Rails still parses a
  # trailing recognized extension (e.g. the `.gz` some crawlers probe for) as
  # the request format - constrain it so those requests 404 instead of
  # hitting the controller with a format we have no template for.
  get "sitemap.xml", to: "sitemaps#show", as: :sitemap, constraints: { format: "xml" }
  get "pricing", to: "pricing#index", as: :pricing
  get "features", to: "pages#features", as: :features
  get "security", to: "pages#security", as: :security
  get "contact", to: "contact#new", as: :contact
  post "contact", to: "contact#create"
  get "contact/sent", to: "contact#sent", as: :contact_sent

  get "privacy-policy", to: "legal#privacy_policy", as: :legal_privacy_policy
  get "gdpr",           to: "legal#gdpr",           as: :legal_gdpr
  get "terms",          to: "legal#terms",          as: :legal_terms
  get "cookies",        to: "legal#cookies_policy", as: :legal_cookies

  get "dashboard" => "dashboard#index"

  # --- Onboarding ---
  get   "onboarding",       to: "onboarding#show",   as: :onboarding
  get   "onboarding/:step", to: "onboarding#show",   as: :onboarding_step
  patch "onboarding/:step", to: "onboarding#update"
  post  "onboarding/skip",  to: "onboarding#skip",   as: :skip_onboarding

  resources :notification_recipients, only: [ :index, :destroy ] do
    member do
      patch :mark_read
      get   :open
    end
    collection do
      patch :mark_all_read
    end
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [ :index, :show, :update ] do
      resource :user_role, only: [ :create, :destroy ], controller: "user_roles"
      member do
        patch :disable
        patch :enable
        post  :send_reset_link
      end
    end
    resources :roles
    resources :permissions
    resources :features, only: [ :index, :edit, :update ]
    resources :audit_logs, only: [ :index, :show ]
    resources :webhook_events, only: [ :index, :show ]
    mount MissionControl::Jobs::Engine, at: "/jobs"
    resources :notifications, only: [ :index, :new, :create ] do
      member do
        patch :withdraw
      end
    end
    resources :email_campaigns, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
      member do
        post :deliver
        get  :recipients
      end
    end
    resources :email_campaign_images, only: [ :create ]
    resource :maintenance_mode, only: [ :edit, :update ], controller: "maintenance_mode" do
      post :force_logout_all
    end
    resources :price_migrations, only: [ :new, :create ]
    resources :customer_erasures, only: [ :new, :create ]
    resources :subject_access_requests, only: [ :new, :create ]
    get "customer_pii_exports/:token", to: "customer_pii_exports#show", as: :customer_pii_export
    resources :organizations, only: [] do
      resource :grandfather, only: [ :create, :destroy ], controller: "organization_grandfathers"
    end
    resources :organization_logos, only: [ :index, :show ] do
      member do
        patch :approve
        patch :decline
      end
    end
  end

  # --- Organization invitations (public acceptance endpoint) ---
  get  "invitations/:token",        to: "invitations#show",   as: :invitation
  post "invitations/:token/accept", to: "invitations#accept", as: :accept_invitation

  # --- Email preference center (public, unauthenticated - reached from an emailed unsubscribe link) ---
  get   "email_preferences/:token",           to: "email_preferences#show",   as: :email_preference
  patch "email_preferences/:token",           to: "email_preferences#update"
  post  "email_preferences/:token/one_click", to: "email_preferences#one_click", as: :one_click_email_preference

  # --- Org-facing members/invitations management (distinct from the system-scope Admin:: namespace) ---
  namespace :org do
    resource :organization, only: [ :update, :new, :create ], controller: "organizations"
    resources :organization_logos, only: [ :create, :destroy ] do
      member do
        patch :activate
      end
      collection do
        patch :deactivate
      end
    end
    resource :custom_domain, only: [ :show, :create, :destroy ], controller: "custom_domains" do
      get :status
    end
    get "settings", to: "settings#index", as: :settings
    resource :opening_hours, only: [ :show, :update ], controller: "opening_hours"
    resource :appointment_booking, only: [ :show, :update ], controller: "appointment_booking" do
      resources :openings, only: [ :new, :create, :edit, :update, :destroy ], controller: "appointment_openings"
      resources :blocked_dates, only: [ :create, :destroy ], controller: "appointment_blocked_dates" do
        post :import, on: :collection
      end
    end
    resources :members, only: [ :index, :destroy ] do
      member do
        patch :promote
        patch :demote
        patch :promote_to_owner
        post  :send_promotion_code
        patch :demote_owner
        post  :send_owner_demotion_code
      end
      collection do
        delete :leave
      end
    end
    resources :invitations, only: [ :create, :destroy ]
    get   "features", to: "features#index",  as: :features
    patch "features", to: "features#update"
    post "switch", to: "switches#create", as: :switch

    get "analytics", to: "analytics#index", as: :analytics
    resource :kiosk, only: [ :show, :update ], controller: "kiosk" do
      get :preview, on: :member
      delete :exit_preview, on: :member
    end
    resource :portal_appearance, only: [ :show, :update ], controller: "portal_appearance"

    get    "queue", to: "queue#index", as: :queue
    post   "queue/call_next", to: "queue#call_next", as: :call_next_queue
    get    "queue/poll", to: "queue#poll", as: :poll_queue
    post   "queue/refresh", to: "queue#refresh", as: :refresh_queue
    post   "queue/reset_wait_timer", to: "queue#reset_wait_timer", as: :reset_wait_timer_queue
    patch  "queue/undo_last_cancelled", to: "queue#undo_last_cancelled", as: :undo_last_cancelled_queue
    patch  "queue/:id/update_status", to: "queue#update_status", as: :update_status_queue
    patch  "queue/:id/revert_completed", to: "queue#revert_completed", as: :revert_completed_queue
    patch  "queue/:id/revert_cancelled", to: "queue#revert_cancelled", as: :revert_cancelled_queue

    get  "walk_in/new", to: "walk_ins#new", as: :new_walk_in
    post "walk_in", to: "walk_ins#create", as: :walk_in
    get  "walk_in/upsell", to: "walk_ins#upsell", as: :upsell_walk_in
    post "walk_in/upsell/accept", to: "walk_ins#upsell_accept", as: :upsell_accept_walk_in
    post "walk_in/upsell/book_later", to: "walk_ins#upsell_book_later", as: :upsell_book_later_walk_in
    post "walk_in/upsell/decline", to: "walk_ins#upsell_decline", as: :upsell_decline_walk_in
    get  "walk_in/confirmed", to: "walk_ins#confirmed", as: :confirmed_walk_in
    get  "walk_in/book_later", to: "walk_ins#book_later", as: :book_later_walk_in

    get "waiting_display", to: "waiting_display#index", as: :waiting_display
    get "waiting_display/poll", to: "waiting_display#poll", as: :poll_waiting_display

    resources :services do
      member do
        post :toggle
        patch :move_up
        patch :move_down
      end
    end

    resources :calendars, except: [ :show, :destroy ] do
      member do
        patch :archive
      end
    end

    resources :upsell_rules do
      member do
        post :toggle
        patch :move_up
        patch :move_down
      end
    end

    resources :devices do
      member do
        post :regenerate_key
        post :clear_ip
        patch :set_status
      end
    end

    resources :appointments do
      collection do
        get :slots
        get :search
        get :print
      end
      member do
        patch :check_in
        patch :cancel
        patch :no_show
        patch :return_to_booked
        post :resend_confirmation
      end
    end

    resources :audit_logs, only: [ :index, :show ]
  end

  namespace :kiosk do
    root "home#index"
    get "home", to: "home#index", as: :home

    get "privacy", to: "privacy#show", as: :privacy

    get "setup", to: "setup#index", as: :setup
    post "setup/configure", to: "setup#configure", as: :setup_configure
    post "setup/authenticate", to: "setup#authenticate", as: :setup_authenticate
    post "setup/clear", to: "setup#clear", as: :setup_clear
    post "setup/logout", to: "setup#logout", as: :setup_logout

    get "services", to: "services#index", as: :services
    get "services/search", to: "services#search", as: :search_services
    get "services/:id/choose", to: "services#choose", as: :choose_service

    get "service_requests/new", to: "service_requests#new", as: :new_service_request
    post "service_requests", to: "service_requests#create", as: :service_requests

    get "upsell", to: "upsells#show", as: :upsell
    post "upsell/accept", to: "upsells#accept", as: :accept_upsell
    post "upsell/book_later", to: "upsells#book_later", as: :book_later_upsell
    post "upsell/decline", to: "upsells#decline", as: :decline_upsell
    get "upsell/confirmed", to: "upsells#confirmed", as: :confirmed_upsell

    get "appointments/new", to: "appointments#new", as: :new_appointment
    get "appointments/check_in", to: "appointments#check_in", as: :check_in_appointments
    get "appointments/checked_in", to: "appointments#checked_in", as: :appointment_checked_in
    get "appointments/upsell_booking_confirmation", to: "appointments#upsell_booking_confirmation", as: :upsell_booking_confirmation
    get "appointments/:id/confirmation", to: "appointments#confirmation", as: :appointment_confirmation

    resources :appointments, only: [ :create ] do
      collection do
        get :calendar
        get :slot_options
        get :check_in_candidates
        post :process_check_in
        post :cancel_upsell_booking
      end
    end
  end

  namespace :api do
    namespace :v1 do
      post "device_auth", to: "device_auth#create"
    end
  end

  # Public booking portal — slug routes must be last so existing namespaces take precedence.
  # Reserved words come from ReservedSlug::WORDS - the single source of truth shared
  # with Organization#slug's own validation - rather than a second hardcoded list here.
  scope "/:organization_slug",
        constraints: {
          organization_slug: /(?!(?:#{ReservedSlug::WORDS.join("|")})\b)[a-z0-9][a-z0-9\-]*[a-z0-9]/
        } do
    draw :public_portal
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
