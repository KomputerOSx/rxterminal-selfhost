class Organization < ApplicationRecord
  include FeatureToggleable
  include KioskTheming
  include PortalTheming

  SLUG_FORMAT = /\A[a-z0-9](?:[a-z0-9\-]*[a-z0-9])?\z/
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
  has_many :services, dependent: :destroy
  has_many :service_requests, dependent: :destroy
  has_many :calendars, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :appointment_openings, dependent: :destroy
  has_many :appointment_blocked_dates, dependent: :destroy
  has_many :upsell_rules, dependent: :destroy
  has_many :devices, dependent: :destroy

  attr_accessor :enforce_slug_change_limit

  before_validation :normalize_slug, if: -> { slug.present? && will_save_change_to_slug? }
  before_save :stamp_slug_change, if: :limited_slug_change?

  validates :name, presence: true, profanity: true
  validates :slug, presence: true, uniqueness: true,
    format: { with: SLUG_FORMAT },
    length: { maximum: 63 },
    exclusion: { in: ReservedSlug::WORDS },
    profanity: true
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

  # Self-serve org creation (signup uses #create_personal_for!).
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
    organization = new(name: name, slug: slug, **attrs)
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

  # The currency service prices are entered/displayed in across the org - kiosk, portal,
  # staff views, upsells -   # Applies org-wide, not per-service, since there's no per-location pricing concept.
  def service_currency_symbol
    SERVICE_CURRENCY_SYMBOLS.fetch(service_currency, SERVICE_CURRENCY_SYMBOLS.fetch(DEFAULT_SERVICE_CURRENCY))
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

  def owner_users
    memberships.joins(:roles).where(roles: { name: Role::APP_OWNER, scope: :app }).includes(:user).map(&:user)
  end

  # Single-line address string for display.
  def full_address
    [
      address_line1, address_line2, address_city,
      address_state, address_postal_code, address_country
    ].compact_blank.join(", ")
  end

  private

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
end
