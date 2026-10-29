require "test_helper"

class BillingSubscriptionsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "a non-owner cannot subscribe" do
    member = users(:two)
    @organization.memberships.create!(user: member).grant_role!(Role.find_or_create_by!(scope: :app, name: Role::APP_USER))

    post login_path, params: { email: member.email, password: "password123" }

    post billing_subscription_path(plan: "starter")
    assert_redirected_to root_path
  end

  test "switching trial plan without a payment method succeeds" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_resolvable_price(Billing::Plans::BUSINESS) do
      assert_no_difference "Pay::Subscription.count" do
        post billing_subscription_path(plan: "business")
      end
    end

    assert_redirected_to billing_path
    assert_equal "business", @organization.reload.trial_plan_key
  end

  test "subscribing without a payment method redirects to Stripe Checkout when not on trial" do
    @organization.end_trial!
    org = create_personal_without_trial!(@owner)
    org.set_payment_processor(:stripe).update!(processor_id: "cus_test123")
    fake_session = Struct.new(:url).new("https://checkout.stripe.com/test/session")

    post login_path, params: { email: @owner.email, password: "password123" }
    post org_switch_path, params: { organization_id: org.id }

    with_resolvable_price(Billing::Plans::STARTER) do
      Stripe::Checkout::Session.stub(:create, fake_session) do
        assert_no_difference "Pay::Subscription.count" do
          post billing_subscription_path(plan: "starter")
        end
      end
    end

    assert_redirected_to "https://checkout.stripe.com/test/session"
  end

  test "converting from trial to paid with a payment method redirects to Stripe Checkout" do
    customer = @organization.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_test123")
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")
    fake_session = Struct.new(:url).new("https://checkout.stripe.com/test/session")

    post login_path, params: { email: @owner.email, password: "password123" }

    with_resolvable_price(Billing::Plans::STARTER) do
      Stripe::Checkout::Session.stub(:create, fake_session) do
        assert_no_difference "Pay::Subscription.count" do
          post billing_subscription_path(plan: "starter")
        end
      end
    end

    assert_redirected_to "https://checkout.stripe.com/test/session"
  end

  test "subscribing after the account trial was used charges immediately" do
    @organization.end_trial!
    @owner.update!(trial_granted_at: 1.year.ago)
    org = create_personal_without_trial!(@owner)

    customer = org.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    post login_path, params: { email: @owner.email, password: "password123" }
    post org_switch_path, params: { organization_id: org.id }

    with_resolvable_price(Billing::Plans::STARTER) do
      post billing_subscription_path(plan: "starter")
    end

    assert_redirected_to billing_path
    assert org.reload.subscribed?
  end

  test "subscribing sends default_payment_method (not payment_method) to Stripe without a trial period" do
    @organization.end_trial!
    org = create_personal_without_trial!(@owner)

    customer = org.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_test123")
    customer.payment_methods.create!(processor_id: "pm_test123", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    post login_path, params: { email: @owner.email, password: "password123" }
    post org_switch_path, params: { organization_id: org.id }

    captured_params = nil
    fake_stripe_subscription = Struct.new(:id).new("sub_test123")
    fake_pay_subscription = Object.new.tap { |o| o.define_singleton_method(:incomplete?) { false } }

    Stripe::Subscription.stub(:create, ->(params, _opts) { captured_params = params; fake_stripe_subscription }) do
      Pay::Stripe::Subscription.stub(:sync, fake_pay_subscription) do
        with_resolvable_price(Billing::Plans::STARTER) do
          post billing_subscription_path(plan: "starter")
        end
      end
    end

    assert_redirected_to billing_path
    assert_equal "pm_test123", captured_params[:default_payment_method]
    assert_not captured_params.key?(:payment_method)
    assert_not captured_params.key?(:trial_period_days)
    assert_equal({ enabled: true }, captured_params[:automatic_tax])
  end

  test "an applied promo code rides along on subscribe and is cleared afterward" do
    @organization.end_trial!
    org = create_personal_without_trial!(@owner)

    customer = org.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_test123")
    customer.payment_methods.create!(processor_id: "pm_test123", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    post login_path, params: { email: @owner.email, password: "password123" }
    post org_switch_path, params: { organization_id: org.id }

    coupon = Struct.new(:valid, :percent_off, :amount_off).new(true, 20, nil)
    promotion_code = Struct.new(:id, :code, :coupon).new("promo_test123", "SAVE20", coupon)
    Stripe::PromotionCode.stub(:list, [ promotion_code ]) do
      post billing_promo_code_path, params: { code: "SAVE20" }
    end

    captured_params = nil
    fake_stripe_subscription = Struct.new(:id).new("sub_test123")
    fake_pay_subscription = Object.new.tap { |o| o.define_singleton_method(:incomplete?) { false } }

    Stripe::Subscription.stub(:create, ->(params, _opts) { captured_params = params; fake_stripe_subscription }) do
      Pay::Stripe::Subscription.stub(:sync, fake_pay_subscription) do
        with_resolvable_price(Billing::Plans::STARTER) do
          post billing_subscription_path(plan: "starter")
        end
      end
    end

    assert_redirected_to billing_path
    assert_equal [ { promotion_code: "promo_test123" } ], captured_params[:discounts]
    assert_nil session[:promo_code_id]
  end

  test "the owner can switch from one paid plan to another without creating a second subscription" do
    post login_path, params: { email: @owner.email, password: "password123" }

    customer = @organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      with_resolvable_price(Billing::Plans::BUSINESS) do
        assert_no_difference "Pay::Subscription.count" do
          post billing_subscription_path(plan: "business")
        end
      end
    end

    assert_redirected_to billing_path
    assert AuditLog.exists?(event_type: :subscription_updated, resource_type: "Organization", resource_id: @organization.id)
  end

  test "checkout is refused for the Free plan" do
    post login_path, params: { email: @owner.email, password: "password123" }

    post billing_subscription_path(plan: "free")
    assert_redirected_to billing_path
  end

  test "checkout is refused for an unknown plan key" do
    post login_path, params: { email: @owner.email, password: "password123" }

    post billing_subscription_path(plan: "enterprise")
    assert_redirected_to billing_path
  end

  test "switching to a plan you're already on is refused" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_no_difference "AuditLog.count" do
      post billing_subscription_path(plan: @organization.trial_plan_key)
    end

    assert_redirected_to billing_path
  end

  test "downgrading schedules the change for period end instead of applying it now" do
    post login_path, params: { email: @owner.email, password: "password123" }

    customer = @organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    phase_item = Struct.new(:price, :quantity).new("price_fake_business_gbp", 1)
    phase = Struct.new(:items, :start_date, :end_date).new([ phase_item ], 10.days.ago.to_i, 20.days.from_now.to_i)
    fake_schedule = Struct.new(:id, :phases).new("sub_sched_test123", [ phase ])

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      with_resolvable_price(Billing::Plans::STARTER) do
        Stripe::SubscriptionSchedule.stub(:create, fake_schedule) do
          Stripe::SubscriptionSchedule.stub(:update, fake_schedule) do
            post billing_subscription_path(plan: "starter")
          end
        end
      end

      assert_equal "price_fake_business_gbp", @organization.payment_processor.subscription.processor_plan
    end

    assert_redirected_to billing_path
    assert_equal "starter", @organization.reload.pending_plan_key
    assert AuditLog.exists?(event_type: :subscription_downgrade_scheduled, resource_id: @organization.id)
  end

  test "the owner can cancel the scheduled downgrade to keep the current plan" do
    post login_path, params: { email: @owner.email, password: "password123" }

    @organization.update!(pending_plan_key: "starter", pending_plan_change_at: 20.days.from_now,
      stripe_subscription_schedule_id: "sub_sched_test123")

    Stripe::SubscriptionSchedule.stub(:release, true) do
      delete billing_subscription_scheduled_change_path
    end

    assert_redirected_to billing_path
    assert_nil @organization.reload.pending_plan_key
    assert AuditLog.exists?(event_type: :subscription_downgrade_cancelled, resource_id: @organization.id)
  end

  test "canceling a scheduled change when none exists shows an alert" do
    post login_path, params: { email: @owner.email, password: "password123" }

    delete billing_subscription_scheduled_change_path
    assert_redirected_to billing_path
    assert_nil AuditLog.find_by(event_type: :subscription_downgrade_cancelled, resource_id: @organization.id)
  end

  test "canceling keeps access until the end of the billing period in every environment" do
    post login_path, params: { email: @owner.email, password: "password123" }

    customer = @organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      delete billing_subscription_path

      subscription = @organization.payment_processor.subscription.reload
      assert subscription.active?
      assert subscription.ends_at.present?
      assert subscription.on_grace_period?
    end

    assert_redirected_to billing_path
    assert AuditLog.exists?(event_type: :subscription_cancelled, resource_id: @organization.id)
  end

  test "canceling twice is refused while already in the grace period" do
    post login_path, params: { email: @owner.email, password: "password123" }

    customer = @organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      delete billing_subscription_path
      assert_no_difference "AuditLog.where(event_type: :subscription_cancelled).count" do
        delete billing_subscription_path
      end
    end

    assert_redirected_to billing_path
  end

  test "the owner can resume a cancelled subscription during the grace period" do
    post login_path, params: { email: @owner.email, password: "password123" }

    customer = @organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.payment_processor.subscription.cancel

      post billing_subscription_resume_path

      subscription = @organization.payment_processor.subscription.reload
      assert subscription.active?
      assert_nil subscription.ends_at
    end

    assert_redirected_to billing_path
    assert AuditLog.exists?(event_type: :subscription_resumed, resource_id: @organization.id)
  end

  test "resuming with nothing cancelled shows an alert" do
    post login_path, params: { email: @owner.email, password: "password123" }

    customer = @organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      post billing_subscription_resume_path
    end

    assert_redirected_to billing_path
    assert_nil AuditLog.find_by(event_type: :subscription_resumed, resource_id: @organization.id)
  end

  test "a non-owner cannot resume or cancel scheduled changes" do
    member = users(:two)
    @organization.memberships.create!(user: member).grant_role!(Role.find_or_create_by!(scope: :app, name: Role::APP_USER))

    post login_path, params: { email: member.email, password: "password123" }

    post billing_subscription_resume_path
    assert_redirected_to root_path

    delete billing_subscription_scheduled_change_path
    assert_redirected_to root_path
  end

  test "ending a local trial locks the organization immediately" do
    post login_path, params: { email: @owner.email, password: "password123" }

    delete billing_subscription_path

    assert_redirected_to billing_path
    assert @organization.reload.locked?
    audit_log = AuditLog.where(event_type: :subscription_cancelled, resource_id: @organization.id).last
    assert_equal true, audit_log.metadata["trial"]
  end

  test "canceling with no active subscription and no trial is a no-op redirect" do
    @organization.end_trial!
    post login_path, params: { email: @owner.email, password: "password123" }

    delete billing_subscription_path
    assert_redirected_to billing_path
  end
end
