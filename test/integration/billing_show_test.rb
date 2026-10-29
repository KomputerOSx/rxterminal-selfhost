require "test_helper"

class BillingShowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "billing history paginates at 10 charges per page" do
    customer = @organization.set_payment_processor(:stripe)
    15.times do |i|
      customer.charges.create!(processor_id: "ch_fake_#{i}", amount: 999, currency: "gbp", created_at: i.days.ago)
    end

    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path
    assert_response :success
    assert_select "table tbody tr", 10
    assert_select "a", text: "Next"

    get billing_path, params: { charges_page: 2 }
    assert_response :success
    assert_select "table tbody tr", 5
    assert_select "a", text: "Previous"
  end

  test "billing history shows no pagination controls when everything fits on one page" do
    customer = @organization.set_payment_processor(:stripe)
    3.times { |i| customer.charges.create!(processor_id: "ch_fake_#{i}", amount: 999, currency: "gbp") }

    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path
    assert_response :success
    assert_select "table tbody tr", 3
    assert_select "a", text: "Next", count: 0
  end

  test "shows plan usage breakdown for the current plan" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path

    assert_response :success
    assert_match "Plan usage", response.body
    assert_match "Members", response.body
    assert_match "Services", response.body
    assert_match "Requests this month", response.body
    assert_match "Audit log history", response.body
    assert_no_match "members used", response.body
  end

  test "end trial button is shown during a local no-card trial" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path
    assert_response :success
    assert_select "button", text: "End trial"
    assert_select "button", text: "Cancel subscription", count: 0
  end

  test "cancel subscription button is shown while on a paid plan" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      Stripe::Invoice.stub(:create_preview, Struct.new(:total, :subtotal, :currency).new(999, 999, "gbp")) do
        get billing_path
      end
    end

    assert_response :success
    assert_select "button", text: "Cancel subscription"
  end

  test "a cancelled subscription shows the resume banner and hides plan changes" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.payment_processor.subscription.cancel
      get billing_path
    end

    assert_response :success
    assert_select "button", text: "Resume subscription"
    assert_select "button", text: "Cancel subscription", count: 0
    assert_select "button", text: "Upgrade", count: 0
  end

  test "a scheduled downgrade shows the pending notice with an undo button" do
    post login_path, params: { email: @owner.email, password: "password123" }

    @organization.update!(pending_plan_key: "starter", pending_plan_change_at: 20.days.from_now,
      stripe_subscription_schedule_id: "sub_sched_test123")

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      Stripe::Invoice.stub(:create_preview, Struct.new(:total, :subtotal, :currency).new(2999, 2999, "gbp")) do
        get billing_path
      end
    end

    assert_response :success
    assert_select "button", text: "Keep current plan"
    assert_match "Your plan changes to", response.body
  end

  test "a local no-card trial shows the trial notice and trial end date" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path

    assert_response :success
    assert_match "30-day free trial", response.body
    assert_match @organization.trial_ends_at.to_date.to_fs(:long), response.body
  end

  test "an on-trial org can switch plans without a payment method" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path
    assert_response :success
    assert_match "Switch plan", response.body
  end

  test "an on-trial org can pre-pay its current trial plan to auto-bill after the trial ends" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path
    assert_response :success
    assert_select "button", text: "Subscribe", count: 2
  end

  test "does not show the pre-pay button once the org has already subscribed" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      Stripe::Invoice.stub(:create_preview, Struct.new(:total, :subtotal, :currency).new(999, 999, "gbp")) do
        get billing_path
      end
    end

    assert_response :success
    assert_select "button", text: "Subscribe", count: 0
  end

  test "a refunded charge is badged in billing history" do
    customer = @organization.set_payment_processor(:stripe)
    customer.charges.create!(processor_id: "ch_refunded", amount: 999, amount_refunded: 999, currency: "gbp")
    customer.charges.create!(processor_id: "ch_partial", amount: 999, amount_refunded: 400, currency: "gbp")

    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path
    assert_response :success
    assert_match "Partially refunded", response.body
    assert_match(/>\s*Refunded\s*</, response.body)
  end

  test "shows the live next-bill preview amount for an active subscription" do
    post login_path, params: { email: @owner.email, password: "password123" }

    fake_preview = Struct.new(:total, :subtotal, :currency).new(0, 0, "gbp")

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      Stripe::Invoice.stub(:create_preview, fake_preview) do
        get billing_path
      end
    end

    assert_response :success
    assert_match "Next bill", response.body
    assert_match "£0.00", response.body
  end

  test "falls back to the static plan price if the next-bill preview call fails" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      Stripe::Invoice.stub(:create_preview, ->(*) { raise Stripe::StripeError, "boom" }) do
        get billing_path
      end
    end

    assert_response :success
    assert_match Billing::Plans::STARTER.formatted_price("gbp"), response.body
  end

  test "does not duplicate trial copy in the next-bill section" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path
    assert_response :success
    assert_match "Subscribe to an available plan to maintain access", response.body
    assert_no_match "Your #{Organization::TRIAL_DAYS}-day free trial ends", response.body
  end

  test "shows no next-bill line when trial ended and unsubscribed" do
    @organization.end_trial!
    post login_path, params: { email: @owner.email, password: "password123" }

    get billing_path
    assert_response :success
    assert_no_match "Next bill", response.body
  end

  test "shows a price-increase-coming notice when a price migration is pending" do
    post login_path, params: { email: @owner.email, password: "password123" }

    @organization.update!(pending_price_cents: 1500, pending_plan_change_at: 20.days.from_now)

    fake_preview = Struct.new(:total, :currency).new(999, "gbp")
    with_active_subscription(@organization, Billing::Plans::STARTER) do
      Stripe::Invoice.stub(:create_preview, fake_preview) do
        get billing_path
      end
    end

    assert_response :success
    assert_match "your Starter price is changing to", response.body
    assert_match "£15.00", response.body
  end
end
