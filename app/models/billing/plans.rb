# frozen_string_literal: true

module Billing
  class Plans
    SUPPORTED_CURRENCIES = %w[gbp].freeze
    DEFAULT_CURRENCY = "gbp"

    Limits = Data.define(
      :max_users,
      :max_services,
      :max_upsell_rules,
      :max_monthly_requests,
      :appointments_enabled,
      :calendars_enabled,
      :kiosk_enabled,
      :custom_domain,
      :audit_log_retention_days
    ) do
      def unlimited_users? = max_users.nil?
      def unlimited_services? = max_services.nil?
      def unlimited_upsell_rules? = max_upsell_rules.nil?
      def unlimited_monthly_requests? = max_monthly_requests.nil?
      def custom_domain? = custom_domain
    end

    STARTER_LIMITS = Limits.new(
      max_users: 1,
      max_services: 3,
      max_upsell_rules: 1,
      max_monthly_requests: 200,
      appointments_enabled: false,
      calendars_enabled: false,
      kiosk_enabled: false,
      custom_domain: false,
      audit_log_retention_days: 7
    ).freeze

    BUSINESS_LIMITS = Limits.new(
      max_users: nil,
      max_services: nil,
      max_upsell_rules: nil,
      max_monthly_requests: nil,
      appointments_enabled: true,
      calendars_enabled: true,
      kiosk_enabled: true,
      custom_domain: true,
      audit_log_retention_days: nil
    ).freeze

    Price = Data.define(:cents, :stripe_price_id) do
      def resolved_stripe_price_id
        stripe_price_id.respond_to?(:call) ? stripe_price_id.call : stripe_price_id
      end
    end

    Plan = Data.define(:key, :name, :limits, :prices) do
      def member_limit = limits.max_users
      def custom_domain? = limits.custom_domain?

      def price_for(currency)
        prices.fetch(currency.to_s) { prices.fetch(Plans::DEFAULT_CURRENCY) }
      end

      def price_cents(currency) = price_for(currency).cents

      def formatted_price(currency = Plans::DEFAULT_CURRENCY)
        Pay::Currency.format(price_cents(currency), currency: currency)
      end

      def resolved_stripe_price_id(currency = Plans::DEFAULT_CURRENCY)
        price_for(currency).resolved_stripe_price_id
      end

      def all_stripe_price_ids
        SUPPORTED_CURRENCIES.flat_map { |currency|
          [ resolved_stripe_price_id(currency), *Plans.legacy_price_ids(key, currency) ]
        }.compact
      end
    end

    STARTER = Plan.new(
      key: "starter",
      name: "Starter",
      limits: STARTER_LIMITS,
      prices: {
        "gbp" => Price.new(cents: 999, stripe_price_id: -> { credential_price_id(:starter, :gbp) })
      }
    )

    BUSINESS = Plan.new(
      key: "business",
      name: "Business",
      limits: BUSINESS_LIMITS,
      prices: {
        "gbp" => Price.new(cents: 2999, stripe_price_id: -> { credential_price_id(:business, :gbp) })
      }
    )

    ALL = [ STARTER, BUSINESS ].freeze
    PAID = ALL

    def self.find(key)
      normalized = normalize_plan_key(key)
      ALL.find { |plan| plan.key == normalized }
    end

    def self.normalize_plan_key(key)
      case key.to_s
      when "growth" then "business"
      else key.to_s
      end
    end

    def self.credential_price_id(plan_key, currency)
      normalized = normalize_plan_key(plan_key)
      value = Rails.application.credentials.dig(:stripe, :price_ids, normalized.to_sym)
      value = Rails.application.credentials.dig(:stripe, :price_ids, :growth, currency.to_sym) if value.blank? && normalized == "business"
      value.is_a?(Hash) ? value[currency.to_sym] || value[currency.to_s] : value
    end

    def self.legacy_price_ids(plan_key, currency)
      legacy = {
        "business" => {
          "gbp" => [],
          "usd" => [ "price_1TqhWqRwyC7yy0N3ZtkgQg5U" ]
        },
        "growth" => {
          "gbp" => [],
          "usd" => [ "price_1TqhWqRwyC7yy0N3ZtkgQg5U" ]
        }
      }
      legacy.dig(normalize_plan_key(plan_key), currency.to_s) || []
    end

    def self.for_stripe_price(stripe_price_id)
      return nil if stripe_price_id.blank?
      PAID.find { |plan| plan.all_stripe_price_ids.include?(stripe_price_id) }
    end

    def self.currency_for_stripe_price(stripe_price_id)
      return nil if stripe_price_id.blank?
      PAID.each do |plan|
        SUPPORTED_CURRENCIES.each do |currency|
          if plan.resolved_stripe_price_id(currency) == stripe_price_id ||
             legacy_price_ids(plan.key, currency).include?(stripe_price_id)
            return currency
          end
        end
      end
      nil
    end
  end
end
