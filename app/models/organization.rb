class Organization < ApplicationRecord
  include FeatureToggleable
  include KioskTheming
  include PortalTheming
  include BillingPlanLimits
  include OrganizationSubscriptionState
  include OrganizationPlanReconciliation
  include OrganizationTrial

  SLUG_FORMAT = /\A[a-z0-9](?:[a-z0-9\-]*[a-z0-9])?\z/
  CUSTOM_DOMAIN_FORMAT = /\A(?:[a-z0-9](?:[a-z0-9\-]*[a-z0-9])?\.)+[a-z]{2,}\z/
  DOMAIN_ORG_CACHE_PREFIX = "domain_org_id:"
  WEEKDAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze
  APPOINTMENT_BOOKING_MODES = %w[rolling openings].freeze
  SLUG_CHANGE_INTERVAL = 30.days
  POSTCODE_REGIONS = %w[uk us ca au].freeze
  SERVICE_CURRENCIES = %w[gbp usd eur cad aud].freeze
  DEFAULT_SERVICE_CURRENCY = "gbp"
  APPOINTMENT_EMAIL_MESSAGE_MAX_LENGTH = 1000
  DEFAULT_APPOINTMENT_EMAIL_MESSAGE = <<~TEXT.strip
    Please arrive 5 minutes before your scheduled appointment.
    Please bring your booking reference when you arrive. You can check in at the kiosk using your reference number or your last name and date of birth.
  TEXT
  SERVICE_CURRENCY_SYMBOLS = {
    "gbp" => "£",
    "usd" => "$",
    "eur" => "€",
    "cad" => "CA$",
    "aud" => "A$"
  }.freeze
  DEFAULT_OPERATING_HOURS = {
    "monday" => { "open" => "09:00", "close" => "18:00" },
    "tuesday" => { "open" => "09:00", "close" => "18:00" },
    "wednesday" => { "open" => "09:00", "close" => "18:00" },
    "thursday" => { "open" => "09:00", "close" => "18:00" },
    "friday" => { "open" => "09:00", "close" => "18:00" },
    "saturday" => { "open" => "09:00", "close" => "13:00" },
    "sunday" => nil
  }.freeze
  DEFAULT_BOOKABLE_TIMES = {
    "monday" => [ { "start" => "10:00", "end" => "13:00" }, { "start" => "14:00", "end" => "16:00" } ],
    "tuesday" => [ { "start" => "10:00", "end" => "13:00" }, { "start" => "14:00", "end" => "16:00" } ],
    "wednesday" => [ { "start" => "10:00", "end" => "13:00" }, { "start" => "14:00", "end" => "16:00" } ],
    "thursday" => [ { "start" => "10:00", "end" => "13:00" }, { "start" => "14:00", "end" => "16:00" } ],
    "friday" => [ { "start" => "10:00", "end" => "13:00" }, { "start" => "14:00", "end" => "16:00" } ],
    "saturday" => [ { "start" => "10:00", "end" => "12:00" } ],
    "sunday" => []
  }.freeze

  # Pay::Customer#email delegates to owner.email (Pay::Customer#api_record_attributes reads it
  # unconditionally), so Organization needs its own #email even though we have no email column -
  # see #email below, which borrows the current owner's.
  #
  # name/address here fall back to the org's own name (no address) until the user explicitly
  # sets billing details via #sync_billing_details! - see there for how those then take over.
  pay_customer default_payment_processor: :stripe,
    stripe_attributes: ->(pay_customer) {
      organization = pay_customer.owner
      { name: organization.billing_name.presence || organization.name, address: organization.stripe_billing_address }.compact
    }

  serialize :features, coder: JSON
  after_initialize do
    self.features ||= {}
    self.operating_hours = DEFAULT_OPERATING_HOURS.deep_dup if operating_hours.blank?
    self.bookable_times = DEFAULT_BOOKABLE_TIMES.deep_dup if bookable_times.blank?
  end

  has_one_attached :kiosk_logo
  belongs_to :kiosk_featured_service, class_name: "Service", optional: true

  has_many :organization_logos, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :membership_roles, through: :memberships
  has_many :organization_invitations, dependent: :destroy
  has_many :feature_organization_accesses, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :service_requests, dependent: :destroy
  has_many :calendars, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :appointment_openings, dependent: :destroy
  has_many :appointment_blocked_dates, dependent: :destroy
  has_many :upsell_rules, dependent: :destroy
  has_many :devices, dependent: :destroy

  before_validation :normalize_custom_domain
  attr_accessor :enforce_slug_change_limit

  before_validation :normalize_slug, if: -> { slug.present? && will_save_change_to_slug? }
  before_save :stamp_slug_change, if: :limited_slug_change?
  after_save :clear_custom_domain_cache, if: :saved_change_to_custom_domain?

  validates :name, presence: true, profanity: true
  validates :slug, presence: true, uniqueness: true,
    format: { with: SLUG_FORMAT },
    length: { maximum: 63 },
    exclusion: { in: ReservedSlug::WORDS },
    profanity: true
  validates :preferred_currency, inclusion: { in: Billing::Plans::SUPPORTED_CURRENCIES }
  validates :custom_domain, uniqueness: { allow_nil: true },
    format: { with: CUSTOM_DOMAIN_FORMAT, allow_nil: true },
    length: { maximum: 253, allow_nil: true }
  validate :custom_domain_requires_business_plan, if: -> { custom_domain.present? && will_save_change_to_custom_domain? }
  validates :postcode_region, inclusion: { in: POSTCODE_REGIONS }
  validates :service_currency, inclusion: { in: SERVICE_CURRENCIES }
  validates :business_type, inclusion: { in: ->(_) { Onboarding::BusinessPresets.all.map(&:key) } }, allow_nil: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone::MAPPING.keys }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :contact_phone, length: { maximum: 50 }, allow_blank: true
  validates :address_line1, :address_line2, :address_city,
    :address_state, :address_postal_code, :address_country,
    length: { maximum: 255 }, allow_blank: true
  with_options on: :essential_details do
    validates :address_line1, :address_city, :address_postal_code, :address_country, presence: true
    validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :contact_phone, presence: true
  end
  validates :appointment_days_ahead, numericality: { only_integer: true, greater_than: 0 }
  validates :appointment_booking_mode, inclusion: { in: APPOINTMENT_BOOKING_MODES }
  normalizes :appointment_email_message, with: ->(message) {
    message = message.gsub("\r\n", "\n").strip
    message.presence unless message == DEFAULT_APPOINTMENT_EMAIL_MESSAGE
  }
  validates :appointment_email_message, length: { maximum: APPOINTMENT_EMAIL_MESSAGE_MAX_LENGTH }, allow_blank: true
  validate :slug_change_allowed, if: :limited_slug_change?
  validate :operating_hours_are_valid
  validates :bookable_times, bookable_times: true
  validate :at_least_one_homescreen_button_visible
  validate :featured_service_required_when_enabled
  validate :kiosk_featured_service_belongs_to_organization

  # Every user gets exactly one of these at signup - see ConfirmationsController#create.
  # Name/slug are derived from the email local-part since registration only collects
  # email/password (no name field exists at signup time).
  def self.create_personal_for!(user)
    create_for!(user, name: name_for(user), slug_base: slug_base_for(user))
  end

  # Self-serve org creation (signup uses #create_personal_for!). Only the account's first org
  # gets a no-card trial — see User#trial_available? / OrganizationTrial#start_no_card_trial_for!.
  def self.create_for!(user, name:, slug_base: nil, slug: nil, validate_essential_details: false, **attrs)
    detail_attrs = attrs.slice(
      :address_line1, :address_line2, :address_city, :address_state, :address_postal_code, :address_country,
      :contact_email, :contact_phone
    )
    validation_context = validate_essential_details ? :essential_details : nil

    organization =
      if slug.present?
        build_and_save_organization!(
          name: name, slug: slug, **detail_attrs, validation_context: validation_context
        )
      else
        base = slug_base.presence || name.to_s.parameterize.presence || slug_base_for(user)
        create_with_unique_slug!(name: name, slug_base: base, **detail_attrs, validation_context: validation_context)
      end
    provision_new_organization!(organization, user)
    # Business, not the concern's own Starter default, so trials show appointments/kiosk too.
    organization.start_no_card_trial_for!(user, plan_key: Billing::Plans::BUSINESS.key) if user.trial_available?
    organization
  end

  def self.create_with_unique_slug!(name:, slug_base:, validation_context: nil, **detail_attrs)
    begin
      build_and_save_organization!(
        name: name, slug: generate_unique_slug(slug_base), **detail_attrs, validation_context: validation_context
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      # A concurrent signup claimed the same slug between our uniqueness check and
      # the write - retry once with a random suffix rather than failing the signup.
      build_and_save_organization!(
        name: name, slug: "#{slug_base}-#{SecureRandom.alphanumeric(6).downcase}", **detail_attrs,
        validation_context: validation_context
      )
    end
  end

  def self.build_and_save_organization!(name:, slug:, validation_context: nil, **attrs)
    organization = new(name: name, slug: slug, preferred_currency: Billing::Plans::DEFAULT_CURRENCY, **attrs)
    validation_context ? organization.save!(context: validation_context) : organization.save!
    organization
  end

  def self.provision_new_organization!(organization, user)
    membership = organization.memberships.create!(user: user)

    owner_role = Role.find_or_create_by!(scope: :app, name: Role::APP_OWNER) do |role|
      role.permanent = true
      role.description = "Organization owner - full control; cannot be removed while sole owner"
    end
    membership.grant_role!(owner_role)

    organization.calendars.create!(name: "Default", is_default: true)
  end

  private_class_method :build_and_save_organization!, :create_with_unique_slug!, :provision_new_organization!

  def self.name_for(user)
    local_part = user.email.to_s.split("@").first.to_s
    words = local_part.gsub(/[^a-zA-Z0-9]+/, " ").strip
    words.present? ? words.split.map(&:capitalize).join(" ") : "My Organization"
  end

  def self.slug_base_for(user)
    local_part = user.email.to_s.split("@").first.to_s.downcase
    base = local_part.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    base.presence || "org"
  end

  def self.generate_unique_slug(base)
    slug = base
    suffix = 2

    while exists?(slug: slug)
      slug = "#{base}-#{suffix}"
      suffix += 1
    end

    slug
  end

  # Organizations with an active subscription still on the given Stripe price id - shared by
  # Admin::PriceMigrationsController's preview and Billing::MigratePriceJob's actual run, so
  # both always agree on exactly who a migration would affect. Pay's `active?` is a Ruby-level
  # predicate (trial/active/not-yet-ended), not a DB column, so this filters in Ruby after a
  # plain processor_plan lookup - fine at this app's scale; a large subscriber base would want
  # a DB-level status filter instead.
  def self.on_stripe_price(price_id)
    Pay::Subscription.where(processor_plan: price_id).includes(:customer)
      .select(&:active?)
      .filter_map { |subscription| subscription.customer.owner if subscription.customer.owner_type == "Organization" }
      .uniq
  end

  # Stripe Customer email (see Pay::Customer#email, which delegates here) - Organization has
  # no email column of its own, so we borrow the current owner's. Falls back gracefully if the
  # org somehow has no owner membership.
  def email
    memberships.joins(:roles).find_by(roles: { name: Role::APP_OWNER, scope: :app })&.user&.email
  end

  def subscribed?
    payment_processor&.subscription&.active?
  end

  def current_plan
    if subscribed?
      subscription = payment_processor.subscription
      return Billing::Plans.for_stripe_price(subscription.processor_plan)
    end

    return trial_plan if on_trial?

    nil
  end

  # The currency prices/subscribing use on the billing page. GBP-only — locked to the
  # subscription's Stripe Price currency once subscribed.
  def billing_currency
    return Billing::Plans::DEFAULT_CURRENCY unless subscribed?

    Billing::Plans.currency_for_stripe_price(payment_processor.subscription.processor_plan) ||
      Billing::Plans::DEFAULT_CURRENCY
  end

  # The currency service prices are entered/displayed in across the org - kiosk, portal,
  # staff views, upsells - as distinct from #billing_currency (the subscription's currency).
  # Applies org-wide, not per-service, since there's no per-location pricing concept.
  def service_currency_symbol
    SERVICE_CURRENCY_SYMBOLS.fetch(service_currency, SERVICE_CURRENCY_SYMBOLS.fetch(DEFAULT_SERVICE_CURRENCY))
  end

  def member_limit
    plan_limits.max_users
  end

  def custom_domain_allowed?
    custom_domain_enabled?
  end

  def clear_custom_domain_if_disallowed!
    return if custom_domain.blank? || custom_domain_allowed?

    update!(custom_domain: nil)
  end

  def self.find_id_by_custom_domain(host)
    domain = host.to_s.downcase.strip.sub(/\Awww\./, "")
    return nil if domain.blank?

    Rails.cache.fetch("#{DOMAIN_ORG_CACHE_PREFIX}#{domain}", expires_in: 10.minutes) do
      find_by(custom_domain: domain)&.id
    end
  end

  def member_count_with_pending
    memberships.count + organization_invitations.outstanding.count
  end

  def at_member_limit?
    !within_member_limit? && plan_limits.max_users.present?
  end

  def at_service_limit?
    !within_service_limit? && plan_limits.max_services.present?
  end

  def at_upsell_rule_limit?
    !within_upsell_rule_limit? && plan_limits.max_upsell_rules.present?
  end

  def at_monthly_request_limit?
    !within_monthly_request_limit? && plan_limits.max_monthly_requests.present?
  end

  def remaining_seats
    limit = member_limit
    return nil if limit.nil?

    [ limit - member_count_with_pending, 0 ].max
  end

  def slug_changeable_at
    slug_changed_at && slug_changed_at + SLUG_CHANGE_INTERVAL
  end

  def slug_change_locked?
    slug_changeable_at.present? && slug_changeable_at > Time.current
  end

  def self.weekday_key(date)
    WEEKDAYS[date.cwday - 1]
  end

  def appointment_email_message_text
    appointment_email_message.presence || DEFAULT_APPOINTMENT_EMAIL_MESSAGE
  end

  def booking_mode_rolling?
    appointment_booking_mode == "rolling"
  end

  def booking_mode_openings?
    appointment_booking_mode == "openings"
  end

  def booking_schedule(calendar: nil)
    BookingSchedule.new(self, calendar: calendar)
  end

  def hours_for(date)
    day_key = date.strftime("%A").downcase
    operating_hours&.dig(day_key)
  end

  def open_on?(date)
    hours_for(date).present?
  end

  def open_now?
    open_at?(Time.current)
  end

  def open_at?(time)
    hours = hours_for(time.to_date)
    return false if hours.blank?

    now_min = time.hour * 60 + time.min
    now_min >= time_to_minutes(hours["open"]) && now_min < time_to_minutes(hours["close"])
  end

  def over_member_limit?
    over_member_limit_at.present?
  end

  # Single-line address string for display. Deliberately separate from the Stripe-only
  # billing_address_* columns below - this is the org's one address (contact info), not a
  # billing address.
  def full_address
    [
      address_line1, address_line2, address_city,
      address_state, address_postal_code, address_country
    ].compact_blank.join(", ")
  end

  # Stripe-shaped address hash built from the billing_address_* columns, or nil if none of
  # them are set (so we don't send Stripe an all-blank address object).
  def stripe_billing_address
    address = {
      line1: billing_address_line1, line2: billing_address_line2, city: billing_address_city,
      state: billing_address_state, postal_code: billing_address_postal_code, country: billing_address_country
    }
    address.values.all?(&:blank?) ? nil : address
  end

  # Persists the billing name/address locally and pushes them straight to the Stripe Customer
  # (what invoices' "Bill to" section actually reads from - not the payment method). Raises
  # Pay::Stripe::Error on failure; callers decide how to surface that.
  def sync_billing_details!(name:, address: {})
    update!(
      billing_name: name,
      billing_address_line1: address[:line1],
      billing_address_line2: address[:line2],
      billing_address_city: address[:city],
      billing_address_state: address[:state],
      billing_address_postal_code: address[:postal_code],
      billing_address_country: address[:country]
    )
    payment_processor.update_api_record(name: billing_name.presence || self.name, address: stripe_billing_address)
  end

  # --- Subscription lifecycle ---
  #
  # Policy implemented here (see docs/BILLING.md):
  # - First org per account: 30-day no-card local trial (OrganizationTrial), plan chosen up front.
  # - Paid subscribe / trial conversion via change_plan!/convert_to_paid! (payment method already
  #   on file): immediate charge today (no Stripe trial period).
  # - Subscribing via Stripe Checkout while still on a no-card trial (create_checkout_session!):
  #   pre-pay - the card is saved today but Stripe's own trial_end (mirroring the local trial)
  #   defers the first charge until the trial actually ends. See finalize_checkout_session!.
  # - Upgrade (more expensive plan): applied immediately, prorated difference invoiced right now
  #   ("always_invoice" - also Pay's own default for swap, made explicit here so the policy
  #   doesn't silently change if the gem's default ever does).
  # - Downgrade (cheaper plan): scheduled via a Stripe Subscription Schedule to take effect at
  #   the end of the current period - the org keeps what it already paid for, and the next
  #   renewal invoice is simply the lower price. Held in pending_plan_* columns until the
  #   renewal webhook confirms the flip (see Billing::ReconcileOrganizationJob).

  TRIAL_PLAN_KEY = DEFAULT_TRIAL_PLAN_KEY

  # Legacy hook — Stripe card trials are replaced by no-card local trials (OrganizationTrial).
  def trial_eligible?(_plan)
    false
  end

  def pending_plan
    return nil if pending_plan_key.blank?
    Billing::Plans.find(pending_plan_key)
  end

  # Moves the org onto `plan`. Returns :created, :trial_plan_changed, :converted,
  # :upgraded, or :downgrade_scheduled so callers can pick the right audit event/message.
  #
  # `promotion_code` (a Stripe promotion code id, e.g. "promo_..." - resolved from a
  # human-entered code by Billing::PromoCodesController) only applies on subscribe/upgrade,
  # which invoice immediately - a scheduled downgrade has no invoice to discount right now, so
  # it's silently not passed through there; the code stays available in the session for the
  # caller to use on a future subscribe/upgrade instead.
  def change_plan!(plan, promotion_code: nil)
    if on_trial? && !subscribed?
      payment_method = payment_processor.default_payment_method
      if payment_method
        return convert_to_paid!(plan, promotion_code: promotion_code)
      end

      switch_trial_plan!(plan)
      return :trial_plan_changed
    end

    payment_method = payment_processor.default_payment_method
    raise ArgumentError, "no payment method on file" unless payment_method

    price_id = plan.resolved_stripe_price_id(billing_currency)
    discount_options = promotion_code.present? ? { discounts: [ { promotion_code: promotion_code } ] } : {}
    tax_options = Billing::Tax.collect_vat? ? { automatic_tax: { enabled: true } } : {}

    if !subscribed?
      payment_processor.subscribe(plan: price_id, default_payment_method: payment_method.processor_id,
        quantity: 1, **tax_options, **discount_options)
      clear_trial_state!
      :created
    elsif plan.price_cents(billing_currency) > current_plan.price_cents(billing_currency)
      cancel_scheduled_downgrade! if scheduled_downgrade?
      payment_processor.subscription.swap(price_id, proration_behavior: "always_invoice", **discount_options)
      restore_plan_reconciliation_archives! if plan.key == Billing::Plans::BUSINESS.key
      :upgraded
    else
      schedule_downgrade!(plan)
      :downgrade_scheduled
    end
  end

  # Stripe Checkout for first subscribe, trial conversion, and resubscribe after lockout.
  # Upgrade/downgrade on an active subscription stays on change_plan! (proration / schedules).
  #
  # `defer_billing_until_trial_end:` lets a trial org pre-pay its *current* trial plan: a card
  # is collected now, but Stripe's own `trial_end` (set to match our local `trial_ends_at`)
  # keeps the first charge from happening until the local trial would have ended anyway - so
  # `on_trial?`/`subscribed?` are briefly both true (see finalize_checkout_session!).
  def create_checkout_session!(plan, promotion_code: nil, success_url:, cancel_url:, defer_billing_until_trial_end: false)
    price_id = plan.resolved_stripe_price_id(billing_currency)
    raise ArgumentError, "no Stripe price configured" if price_id.blank?

    options = {
      mode: "subscription",
      line_items: price_id,
      billing_address_collection: "required",
      customer_update: { address: "auto", name: "auto" },
      client_reference_id: Pay::Stripe.to_client_reference_id(self),
      metadata: { plan_key: plan.key },
      success_url: success_url,
      cancel_url: cancel_url
    }
    options[:automatic_tax] = { enabled: true } if Billing::Tax.collect_vat?
    if promotion_code.present?
      options[:discounts] = [ { promotion_code: promotion_code } ]
    else
      options[:allow_promotion_codes] = true
    end
    if defer_billing_until_trial_end && trial_ends_at.present?
      options[:subscription_data] = { trial_end: trial_ends_at.to_i }
    end

    payment_processor.checkout(**options)
  end

  def create_billing_portal_session!(return_url:)
    payment_processor.billing_portal(return_url: return_url)
  end

  def finalize_checkout_session!(session_id)
    checkout_session = ::Stripe::Checkout::Session.retrieve(session_id)
    expected_reference = Pay::Stripe.to_client_reference_id(self)
    return :invalid unless checkout_session.client_reference_id == expected_reference
    return :incomplete unless checkout_session.status == "complete"

    if checkout_session.subscription.present?
      Pay::Stripe::Subscription.sync(checkout_session.subscription)
    end

    reload
    # A pre-paid trial (see create_checkout_session!'s defer_billing_until_trial_end) syncs in as
    # an active-but-still-trialing Pay::Subscription - keep the local trial state so on_trial?
    # stays true (and the trial UI/banners/"End trial" keep working) until Stripe's own trial_end
    # naturally lapses, rather than treating this checkout like an immediate conversion.
    clear_trial_state! if subscribed? && !payment_processor.subscription.on_trial?
    :complete
  rescue ::Stripe::StripeError
    :error
  end

  def convert_to_paid!(plan, promotion_code: nil)
    raise ArgumentError, "not on trial" unless on_trial?

    payment_method = payment_processor.default_payment_method
    raise ArgumentError, "no payment method on file" unless payment_method

    price_id = plan.resolved_stripe_price_id(billing_currency)
    discount_options = promotion_code.present? ? { discounts: [ { promotion_code: promotion_code } ] } : {}
    tax_options = Billing::Tax.collect_vat? ? { automatic_tax: { enabled: true } } : {}

    payment_processor.subscribe(plan: price_id, default_payment_method: payment_method.processor_id,
      quantity: 1, **tax_options, **discount_options)
    clear_trial_state!
    :converted
  end

  # Cancels at period end (never immediately - the org keeps access until what they paid for
  # runs out, and can resume any time before then). Releases any pending downgrade first, since
  # cancel_at_period_end can't be set on a schedule-managed subscription. Returns the (mutated)
  # subscription so callers can read ends_at back without a stale, separately-fetched copy.
  def cancel_subscription!
    cancel_scheduled_downgrade! if scheduled_downgrade?
    subscription = payment_processor.subscription
    subscription.cancel
    subscription
  end

  def scheduled_downgrade?
    pending_plan_key.present? || stripe_subscription_schedule_id.present?
  end

  # Attaches a promotion code straight to the live subscription for an already-subscribed org
  # (as opposed to change_plan!'s discount_options, which only apply on a subscribe/upgrade
  # call). `discounts:` replaces whatever discounts were on the subscription, not merges with
  # them - fine here since only one code is ever tracked at a time (see PromoCodesController).
  def apply_promotion_code!(promotion_code)
    subscription = payment_processor.subscription
    raise ArgumentError, "no active subscription" unless subscription&.active?

    ::Stripe::Subscription.update(subscription.processor_id, discounts: [ { promotion_code: promotion_code } ])
  rescue ::Stripe::StripeError => e
    raise Pay::Stripe::Error, e
  end

  # Strips any discount from the live subscription - the counterpart to apply_promotion_code!.
  def remove_promotion_code!
    subscription = payment_processor.subscription
    return unless subscription&.active?

    ::Stripe::Subscription.update(subscription.processor_id, discounts: [])
  rescue ::Stripe::StripeError => e
    raise Pay::Stripe::Error, e
  end

  # Live preview of the next invoice Stripe will actually generate for this subscription -
  # reflects whatever discounts currently apply, unlike the plan's static list price. Nil (and
  # the caller falls back to the static price) if there's nothing upcoming or the preview call
  # fails - this is a "nice to have" display, not something that should ever break the page.
  def upcoming_invoice_preview
    subscription = payment_processor&.subscription
    return nil unless subscription&.active? && !subscription.on_grace_period?

    params = {
      customer: payment_processor.processor_id,
      subscription: subscription.processor_id
    }
    params[:automatic_tax] = { enabled: true } if Billing::Tax.collect_vat?

    ::Stripe::Invoice.create_preview(params)
  rescue ::Stripe::StripeError
    nil
  end

  def upcoming_invoice_breakdown
    preview = upcoming_invoice_preview
    return nil unless preview

    currency = preview.currency
    total = Pay::Currency.format(invoice_total_cents(preview), currency: currency)

    unless Billing::Tax.collect_vat?
      return { total: total }
    end

    plan = current_plan
    subtotal_label = plan ? "#{plan.name} (ex VAT)" : "Subscription (ex VAT)"
    ex_vat = Pay::Currency.format(invoice_subtotal(preview), currency: currency)
    lines = invoice_preview_lines(preview, subtotal_label: subtotal_label)

    return { total: total } if lines.size <= 1

    {
      lines: lines,
      total: total,
      total_label: "Total due",
      footnote: ""
    }
  end

  # Itemized first-invoice preview for the subscribe payment modal — uses Stripe Tax on the
  # address the user is entering so ex-VAT plan price, VAT, and total due today match checkout.
  def subscribe_invoice_preview(plan, address:, promotion_code: nil)
    price_id = plan.resolved_stripe_price_id(billing_currency)
    return nil if price_id.blank?

    payment_processor.api_record unless payment_processor.processor_id?

    params = {
      customer: payment_processor.processor_id,
      customer_details: {
        address: normalize_stripe_address(address),
        tax_exempt: "none"
      },
      subscription_details: {
        items: [ { price: price_id, quantity: 1 } ]
      }
    }
    params[:automatic_tax] = { enabled: true } if Billing::Tax.collect_vat?
    params[:discounts] = [ { promotion_code: promotion_code } ] if promotion_code.present?

    preview = ::Stripe::Invoice.create_preview(params)
    serialize_subscribe_invoice_preview(preview, plan)
  rescue ::Stripe::StripeError => e
    Rails.logger.warn("subscribe_invoice_preview failed for organization #{id}: #{e.message}")
    nil
  end

  # Wraps the live subscription in a Stripe Subscription Schedule whose current phase ends at
  # the period end, followed by one billing cycle on the cheaper price; end_behavior "release"
  # then hands the subscription back to normal renewals at that price. Replaces any previously
  # scheduled downgrade.
  def schedule_downgrade!(plan, reconciliation_choices: nil)
    cancel_scheduled_downgrade! if scheduled_downgrade?

    schedule_id, effective_at = schedule_price_change!(plan.resolved_stripe_price_id(billing_currency))
    attrs = {
      pending_plan_key: plan.key,
      pending_plan_change_at: effective_at,
      stripe_subscription_schedule_id: schedule_id
    }
    if reconciliation_choices.present?
      attrs[:plan_reconciliation_choices] = reconciliation_choices
      attrs[:plan_reconciliation_applied_at] = nil
    end
    update!(attrs)
  rescue ::Stripe::StripeError => e
    raise Pay::Stripe::Error, e
  end

  # Releases the schedule on Stripe (subscription continues on its current price as if the
  # downgrade/price migration was never requested) and clears the local pending state.
  def cancel_scheduled_downgrade!
    # Fetch from the DB column first, fallback to checking Stripe directly in case
    # the local DB column was cleared but the schedule was left infinitely running.
    sub = payment_processor&.subscription
    schedule_id = stripe_subscription_schedule_id || (sub&.active? ? sub.as_stripe_subscription.schedule : nil)

    if schedule_id.present?
      begin
        ::Stripe::SubscriptionSchedule.release(schedule_id)
      rescue ::Stripe::InvalidRequestError
        # Already released/completed/canceled on Stripe's side - only the local pointer is stale.
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end
    end
    clear_pending_plan_change!
  end

  # Local-only cleanup, used once a scheduled downgrade/price migration has actually taken
  # effect (the renewal webhook confirms it - see Billing::ReconcileOrganizationJob).
  def clear_pending_plan_change!
    update!(
      pending_plan_key: nil,
      pending_plan_change_at: nil,
      stripe_subscription_schedule_id: nil,
      pending_price_cents: nil,
      plan_reconciliation_choices: {},
      plan_reconciliation_applied_at: nil
    )
  end

  # --- Grandfathering & price migrations ---
  #
  # A grandfathered org is permanently excluded from Billing::MigratePriceJob - it keeps
  # whatever price it's already on until an admin explicitly un-grandfathers it. This is the
  # "keep some existing subscribers on their current price" half of a price increase; the
  # other half is #schedule_price_migration! below, which moves everyone else.

  def grandfathered?
    grandfathered_at.present?
  end

  def grandfather!
    update!(grandfathered_at: Time.current)
  end

  def ungrandfather!
    update!(grandfathered_at: nil)
  end

  # Same underlying mechanism as schedule_downgrade! (a Stripe Subscription Schedule taking
  # effect at the next renewal, no mid-cycle proration) but for a price change *within the
  # same plan* - e.g. migrating existing subscribers to a new, higher Price after a price
  # increase, driven by Billing::MigratePriceJob rather than a customer's own upgrade/downgrade
  # click. Deliberately refuses to run for a grandfathered org, or one that already has a plan
  # change (a downgrade) pending - a bulk price migration should never silently override either
  # of those without an admin looking at it first.
  def schedule_price_migration!(new_price_id:, new_price_cents:)
    raise ArgumentError, "organization is grandfathered" if grandfathered?
    raise ArgumentError, "a plan change is already pending" if pending_plan_key.present?

    cancel_scheduled_downgrade! if stripe_subscription_schedule_id.present?

    schedule_id, effective_at = schedule_price_change!(new_price_id)
    update!(pending_price_cents: new_price_cents, pending_plan_change_at: effective_at, stripe_subscription_schedule_id: schedule_id)
  rescue ::Stripe::StripeError => e
    raise Pay::Stripe::Error, e
  end

  private

  def normalize_stripe_address(address)
    {
      line1: address[:line1].presence || address["line1"],
      line2: address[:line2].presence || address["line2"],
      city: address[:city].presence || address["city"],
      state: address[:state].presence || address["state"],
      postal_code: address[:postal_code].presence || address["postal_code"],
      country: address[:country].presence || address["country"]
    }.compact_blank
  end

  def serialize_subscribe_invoice_preview(preview, plan)
    currency = preview.currency
    total = Pay::Currency.format(invoice_total_cents(preview), currency: currency)

    unless Billing::Tax.collect_vat?
      return {
        total: total,
        total_label: "Total due today",
        footnote: "Then #{total}/mo, billed monthly."
      }
    end

    ex_vat = Pay::Currency.format(invoice_subtotal(preview), currency: currency)

    {
      lines: invoice_preview_lines(preview, subtotal_label: "#{plan.name} (ex VAT)"),
      total: total,
      total_label: "Total due today",
      footnote: "Then #{ex_vat}/mo ex VAT · #{total}/mo inc VAT, billed monthly."
    }
  end

  def invoice_preview_lines(preview, subtotal_label:)
    currency = preview.currency
    lines = [
      {
        label: subtotal_label,
        amount: Pay::Currency.format(invoice_subtotal(preview), currency: currency)
      }
    ]

    invoice_tax_entries(preview).each do |tax|
      next if invoice_cents(tax.amount).zero?

      lines << {
        label: invoice_tax_label(tax),
        amount: Pay::Currency.format(invoice_cents(tax.amount), currency: currency)
      }
    end

    lines
  end

  def invoice_subtotal(preview)
    cents = if preview.respond_to?(:subtotal_excluding_tax) && !preview.subtotal_excluding_tax.nil?
      preview.subtotal_excluding_tax
    else
      preview.subtotal
    end
    invoice_cents(cents)
  end

  def invoice_total_cents(preview)
    cents = if preview.respond_to?(:amount_due) && !preview.amount_due.nil?
      preview.amount_due
    else
      preview.total
    end
    invoice_cents(cents)
  end

  def invoice_cents(value)
    value.to_f.round.to_i
  end

  def invoice_tax_entries(preview)
    if preview.respond_to?(:total_taxes) && preview.total_taxes.present?
      Array(preview.total_taxes)
    else
      Array(preview.try(:total_tax_amounts))
    end
  end

  def tax_rate_for_invoice_tax(tax)
    if tax.respond_to?(:tax_rate_details) && tax.tax_rate_details&.respond_to?(:tax_rate)
      tax.tax_rate_details.tax_rate
    else
      tax.tax_rate
    end
  end

  def invoice_tax_label(tax)
    rate = tax_rate_for_invoice_tax(tax)
    name = rate.display_name.presence if rate.respond_to?(:display_name)
    name ||= "VAT"

    percentage = if rate.respond_to?(:percentage) && rate.percentage
      rate.percentage.to_i
    elsif tax.respond_to?(:taxable_amount) && tax.taxable_amount.to_i.positive?
      (tax.amount.to_f / tax.taxable_amount * 100).round
    end

    percentage ? "#{name} (#{percentage}%)" : name
  end

  def time_to_minutes(time_str)
    hour, minute = time_str.to_s.split(":").map(&:to_i)
    hour * 60 + minute
  end

  def at_least_one_homescreen_button_visible
    return if kiosk_show_featured_service? || kiosk_show_services? || kiosk_show_appointments?

    errors.add(:base, "At least one homescreen button must be visible")
  end

  def featured_service_required_when_enabled
    return unless kiosk_show_featured_service?
    return if kiosk_featured_service_id.present?

    errors.add(:base, "A service must be selected for the featured slot")
  end

  def kiosk_featured_service_belongs_to_organization
    return if kiosk_featured_service_id.blank?
    return if id.blank?

    service = kiosk_featured_service
    if service.nil? || service.organization_id != id || service.deleted?
      errors.add(:kiosk_featured_service_id, "must be an active service in this organization")
    end
  end

  def normalize_custom_domain
    domain = custom_domain.to_s.downcase.strip.sub(/\Awww\./, "")
    self.custom_domain = domain.presence
  end

  def normalize_slug
    self.slug = slug.to_s.downcase.strip
  end

  def limited_slug_change?
    enforce_slug_change_limit && persisted? && will_save_change_to_slug?
  end

  def slug_change_allowed
    return unless slug_change_locked?

    errors.add(:slug, "can only be changed once every 30 days, next change allowed from #{slug_changeable_at.to_date.strftime('%d/%m/%Y')}")
  end

  def stamp_slug_change
    self.slug_changed_at = Time.current
  end

  def operating_hours_are_valid
    validate_weekly_time_ranges(:operating_hours, required_keys: %w[open close])
  end

  def validate_weekly_time_ranges(attribute, required_keys:)
    value = public_send(attribute)
    return if value.blank?

    value.each do |day, hours|
      unless WEEKDAYS.include?(day)
        errors.add(attribute, "includes unknown day #{day}")
        next
      end

      next if hours.nil?

      unless hours.is_a?(Hash)
        errors.add(attribute, "#{weekday_label_for_validation(day)} is invalid")
        next
      end

      required_keys.each do |key|
        validate_time_value(hours[key], attribute, "#{weekday_label_for_validation(day)} #{key}")
      end

      open_time = hours["open"]
      close_time = hours["close"]
      next if open_time.blank? || close_time.blank?
      next if errors[attribute].any?

      if time_to_minutes(open_time) >= time_to_minutes(close_time)
        errors.add(attribute, "#{weekday_label_for_validation(day)} close must be after open")
      end
    end
  end

  def validate_time_value(value, attribute, label)
    return if value.blank?
    return if value.match?(TIME_FORMAT)

    errors.add(attribute, "#{label} must use HH:MM format")
  end

  def weekday_label_for_validation(day)
    day.to_s.capitalize
  end

  TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  def custom_domain_requires_business_plan
    return if custom_domain.blank?

    # Pay's payment_processor may lock the owner row; avoid that while this
    # record still has unsaved custom_domain changes.
    allowed = persisted? ? self.class.find(id).custom_domain_allowed? : false
    return if allowed

    errors.add(:custom_domain, "requires the Business plan")
  end

  def clear_custom_domain_cache
    previous, current = saved_change_to_custom_domain
    Rails.cache.delete("#{DOMAIN_ORG_CACHE_PREFIX}#{previous}") if previous.present?
    Rails.cache.delete("#{DOMAIN_ORG_CACHE_PREFIX}#{current}") if current.present?
  end

  # Shared by schedule_downgrade! and schedule_price_migration! - both are "move the live
  # subscription to a different Price at its own next renewal, no proration" under the hood.
  # Returns [stripe_schedule_id, effective_at].
  def schedule_price_change!(new_price_id)
    subscription = payment_processor.subscription
    raise ArgumentError, "no active subscription" unless subscription&.active?

    schedule = ::Stripe::SubscriptionSchedule.create(from_subscription: subscription.processor_id)
    current_phase = schedule.phases.first

    ::Stripe::SubscriptionSchedule.update(schedule.id, {
      end_behavior: "release",
      phases: [
        {
          items: current_phase.items.map { |item| { price: item.price, quantity: item.quantity } },
          start_date: current_phase.start_date,
          end_date: current_phase.end_date
        },
        { items: [ { price: new_price_id, quantity: 1 } ], iterations: 1 }
      ]
    })

    [ schedule.id, Time.at(current_phase.end_date) ]
  end
end
