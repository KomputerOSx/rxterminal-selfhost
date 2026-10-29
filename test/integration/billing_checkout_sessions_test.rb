# frozen_string_literal: true

require "test_helper"

class BillingCheckoutSessionsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @organization.set_payment_processor(:stripe)
    @organization.payment_processor.update!(processor_id: "cus_test123")

    post login_path, params: { email: @owner.email, password: "password123" }
  end

  test "redirects to Stripe Checkout for a subscribe session" do
    fake_session = Struct.new(:url).new("https://checkout.stripe.com/test/session")
    captured_args = nil
    capture = ->(args, *) { captured_args = args; fake_session }

    with_resolvable_price(Billing::Plans::BUSINESS) do
      Stripe::Checkout::Session.stub(:create, capture) do
        post billing_checkout_session_path, params: { plan: "business" }
      end
    end

    assert_redirected_to "https://checkout.stripe.com/test/session"
    assert_equal true, captured_args[:allow_promotion_codes]
    assert_nil captured_args[:discounts]
  end

  test "pre-applies a promo code from the billing session to checkout" do
    fake_session = Struct.new(:url).new("https://checkout.stripe.com/test/session")
    captured_args = nil
    capture = ->(args, *) { captured_args = args; fake_session }
    coupon = Struct.new(:valid, :percent_off, :amount_off, :currency).new(true, 20, nil, "gbp")
    promotion_code = Struct.new(:id, :code, :coupon).new("promo_test123", "SAVE20", coupon)

    Stripe::PromotionCode.stub(:list, [ promotion_code ]) do
      post billing_promo_code_path, params: { code: "SAVE20" }

      with_resolvable_price(Billing::Plans::BUSINESS) do
        Stripe::Checkout::Session.stub(:create, capture) do
          post billing_checkout_session_path, params: { plan: "business" }
        end
      end
    end

    assert_equal [ { promotion_code: "promo_test123" } ], captured_args[:discounts]
    assert_nil captured_args[:allow_promotion_codes]
  end

  test "defers billing to trial end when pre-paying the current trial plan" do
    fake_session = Struct.new(:url).new("https://checkout.stripe.com/test/session")
    captured_args = nil
    capture = ->(args, *) { captured_args = args; fake_session }

    with_resolvable_price(Billing::Plans::BUSINESS) do
      Stripe::Checkout::Session.stub(:create, capture) do
        post billing_checkout_session_path, params: { plan: "business" }
      end
    end

    assert_redirected_to "https://checkout.stripe.com/test/session"
    assert_equal @organization.trial_ends_at.to_i, captured_args.dig(:subscription_data, :trial_end)
  end

  test "also defers billing when checking out a different plan than the current trial plan" do
    fake_session = Struct.new(:url).new("https://checkout.stripe.com/test/session")
    captured_args = nil
    capture = ->(args, *) { captured_args = args; fake_session }

    with_resolvable_price(Billing::Plans::STARTER) do
      Stripe::Checkout::Session.stub(:create, capture) do
        post billing_checkout_session_path, params: { plan: "starter" }
      end
    end

    assert_redirected_to "https://checkout.stripe.com/test/session"
    assert_equal @organization.trial_ends_at.to_i, captured_args.dig(:subscription_data, :trial_end)
  end

  test "does not defer billing once already subscribed" do
    customer = @organization.payment_processor
    customer.subscriptions.create!(
      name: "default", processor_id: "sub_test123", processor_plan: "price_fake_starter_gbp", status: "active", quantity: 1
    )
    fake_session = Struct.new(:url).new("https://checkout.stripe.com/test/session")
    captured_args = nil
    capture = ->(args, *) { captured_args = args; fake_session }

    Billing::Plans.stub(:for_stripe_price, Billing::Plans::STARTER) do
      with_resolvable_price(Billing::Plans::STARTER) do
        Stripe::Checkout::Session.stub(:create, capture) do
          post billing_checkout_session_path, params: { plan: "starter" }
        end
      end
    end

    assert_redirected_to "https://checkout.stripe.com/test/session"
    assert_nil captured_args[:subscription_data]
  end

  test "refuses checkout for upgrade while subscribed" do
    customer = @organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      with_resolvable_price(Billing::Plans::BUSINESS) do
        post billing_checkout_session_path, params: { plan: "business" }
      end
    end

    assert_redirected_to billing_path
    assert_match "Change plan", flash[:alert]
  end
end
