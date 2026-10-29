# frozen_string_literal: true

module BillingHelper
  def billing_collect_vat?
    Billing::Tax.collect_vat?
  end

  def billing_currency_badge
    billing_collect_vat? ? "Prices ex VAT · GBP" : "Prices · GBP"
  end

  def billing_monthly_price_suffix
    billing_collect_vat? ? "/mo ex VAT" : "/mo"
  end

  def billing_next_bill_suffix(has_breakdown:)
    return billing_monthly_price_suffix unless has_breakdown

    billing_collect_vat? ? "/mo inc VAT" : "/mo"
  end
end
