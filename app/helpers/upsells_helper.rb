# frozen_string_literal: true

module UpsellsHelper
  PERIODS = {
    "today" => -> { { date: Date.current } },
    "this_week" => -> { { date: Date.current.beginning_of_week..Date.current } },
    "this_month" => -> { { date: Date.current.beginning_of_month..Date.current } },
    "all_time" => -> { {} }
  }.freeze

  def rule_stats(rule, period: "all_time")
    scope = rule.upsell_counters.where(PERIODS.fetch(period.to_s, PERIODS["all_time"]).call)

    triggered = scope.sum(:total_triggered)
    conversions = scope.sum(:conversion_count)
    book_laters = scope.sum(:book_later_count)
    declines = scope.sum(:decline_count)
    revenue = scope.sum(:estimated_revenue)
    total_accepted = conversions + book_laters
    rate = triggered.positive? ? (total_accepted.to_f / triggered * 100).round(1) : 0

    {
      triggered: triggered,
      conversions: conversions,
      book_laters: book_laters,
      declines: declines,
      total_accepted: total_accepted,
      rate: rate,
      revenue: revenue
    }
  end

  def upsell_template_stats(template)
    interactions = UpsellInteraction.where(upsell_template: template)
    shown = interactions.count
    accepted = interactions.where(outcome: "accepted_immediate").count
    booked = interactions.where(outcome: "accepted_appointment").count
    declined = interactions.where(outcome: "declined").count
    rate = shown.positive? ? ((accepted + booked).to_f / shown * 100).round(1) : 0

    { shown: shown, accepted: accepted, booked: booked, declined: declined, rate: rate }
  end

  def upsell_sparkline_data(rule)
    7.downto(0).map do |days_ago|
      date = Date.current - days_ago
      counters = rule.upsell_counters.where(date: date)

      {
        date: date.strftime("%d %b"),
        conversions: counters.sum(:conversion_count) + counters.sum(:book_later_count),
        declines: counters.sum(:decline_count)
      }
    end
  end

  def upsell_variant_label(index)
    "Variant #{('A'.ord + index).chr}"
  end

  def upsell_frequency_label(rule)
    case rule.frequency_type
    when "every_nth_customer"
      "Every #{rule.frequency_value}#{ordinal_suffix(rule.frequency_value)} customer"
    when "percentage_based"
      "#{rule.frequency_value}% of customers"
    else
      rule.frequency_type.to_s.humanize
    end
  end

  def upsell_visit_type_label(visit_type)
    case visit_type
    when "first_visit" then "First visit only"
    when "returning" then "Returning only"
    else "Any visit"
    end
  end

  def upsell_revenue_label(amount, service)
    return "-" if service&.price.to_f.zero?

    number_to_currency(amount, unit: service.organization.service_currency_symbol, separator: ".", delimiter: ",")
  end

  def upsell_conversion_rate_class(rate)
    if rate >= 20
      "text-success"
    elsif rate >= 10
      "text-warning"
    else
      "text-base-content/40"
    end
  end

  private

  def ordinal_suffix(number)
    return "th" if (11..13).cover?(number % 100)

    case number % 10
    when 1 then "st"
    when 2 then "nd"
    when 3 then "rd"
    else "th"
    end
  end
end
