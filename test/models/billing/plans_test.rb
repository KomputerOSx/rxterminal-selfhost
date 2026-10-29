require "test_helper"

class Billing::PlansTest < ActiveSupport::TestCase
  test "find looks plans up by key including legacy growth alias" do
    assert_equal Billing::Plans::STARTER, Billing::Plans.find(:starter)
    assert_equal Billing::Plans::BUSINESS, Billing::Plans.find("business")
    assert_equal Billing::Plans::BUSINESS, Billing::Plans.find("growth")
    assert_nil Billing::Plans.find("free")
    assert_nil Billing::Plans.find("nonexistent")
  end

  test "ALL and PAID list the two GBP paid plans" do
    assert_equal [ Billing::Plans::STARTER, Billing::Plans::BUSINESS ], Billing::Plans::ALL
    assert_equal Billing::Plans::ALL, Billing::Plans::PAID
  end

  test "starter limits match the launch spec" do
    limits = Billing::Plans::STARTER.limits

    assert_equal 1, limits.max_users
    assert_equal 3, limits.max_services
    assert_equal 1, limits.max_upsell_rules
    assert_equal 200, limits.max_monthly_requests
    assert_not limits.appointments_enabled
    assert_not limits.kiosk_enabled
    assert_not limits.custom_domain?
    assert_equal 7, limits.audit_log_retention_days
  end

  test "business limits are unlimited or fully enabled" do
    limits = Billing::Plans::BUSINESS.limits

    assert_nil limits.max_users
    assert_nil limits.max_services
    assert_nil limits.max_upsell_rules
    assert_nil limits.max_monthly_requests
    assert limits.appointments_enabled
    assert limits.kiosk_enabled
    assert limits.custom_domain?
    assert_nil limits.audit_log_retention_days
  end

  test "member_limit and custom_domain? delegate to limits for compatibility" do
    assert_equal 1, Billing::Plans::STARTER.member_limit
    assert_not Billing::Plans::STARTER.custom_domain?
    assert_nil Billing::Plans::BUSINESS.member_limit
    assert Billing::Plans::BUSINESS.custom_domain?
  end

  test "for_stripe_price returns nil for a blank or unmatched price id" do
    assert_nil Billing::Plans.for_stripe_price(nil)
    assert_nil Billing::Plans.for_stripe_price("")
    assert_nil Billing::Plans.for_stripe_price("price_unknown")
  end

  test "currency_for_stripe_price returns nil for a blank or unmatched price id" do
    assert_nil Billing::Plans.currency_for_stripe_price(nil)
    assert_nil Billing::Plans.currency_for_stripe_price("price_unknown")
  end

  test "resolved_stripe_price_id calls a lambda price id lazily" do
    plan = build_plan(stripe_price_id: -> { "price_from_lambda_gbp" })

    assert_equal "price_from_lambda_gbp", plan.resolved_stripe_price_id("gbp")
  end

  test "resolved_stripe_price_id passes a plain string id through unchanged" do
    plan = build_plan(stripe_price_id: "price_plain")

    assert_equal "price_plain", plan.resolved_stripe_price_id("gbp")
  end

  test "formatted_price shows GBP amounts" do
    assert_equal "£9.99", Billing::Plans::STARTER.formatted_price("gbp")
    assert_equal "£29.99", Billing::Plans::BUSINESS.formatted_price("gbp")
  end

  test "formatted_price shows cents correctly for non-round amounts" do
    plan = build_plan(cents: 999)

    assert_equal "£9.99", plan.formatted_price("gbp")
  end

  private

  def build_plan(cents: 500, stripe_price_id: "price_test_gbp")
    Billing::Plans::Plan.new(
      key: "test",
      name: "Test",
      limits: Billing::Plans::STARTER_LIMITS,
      prices: {
        "gbp" => Billing::Plans::Price.new(cents: cents, stripe_price_id: stripe_price_id)
      }
    )
  end
end
