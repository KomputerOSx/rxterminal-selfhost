require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "slug must be unique and DNS-safe" do
    Organization.create!(name: "Acme", slug: "acme")

    duplicate = Organization.new(name: "Acme Two", slug: "acme")
    assert_not duplicate.valid?

    invalid = Organization.new(name: "Bad", slug: "Not_Valid!")
    assert_not invalid.valid?
  end

  test "reserved slugs are rejected" do
    org = Organization.new(name: "Admin", slug: "admin")
    assert_not org.valid?
  end

  test "a slug merely starting with a reserved word is allowed" do
    org = Organization.new(name: "Admin Extras", slug: "adminx")
    assert org.valid?
  end

  test "profane organization names and slugs are rejected" do
    name = Organization.new(name: "Big Cunt Ltd", slug: "acme")
    assert_not name.valid?
    assert_includes name.errors[:name], "contains language that isn't allowed"

    slug = Organization.new(name: "Acme", slug: "big-cunt-ltd")
    assert_not slug.valid?
    assert_includes slug.errors[:slug], "contains language that isn't allowed"
  end

  test "names that merely contain an allowlisted word are not flagged as profane" do
    org = Organization.new(name: "Scunthorpe Consulting", slug: "scunthorpe-consulting")
    assert org.valid?
  end

  test "create_personal_for! derives name and slug from the email local-part" do
    user = User.create!(email: "jane.doe@example.com", password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52", confirmed_at: Time.current)

    organization = Organization.create_personal_for!(user)

    assert_equal "Jane Doe", organization.name
    assert_equal "jane-doe", organization.slug
    assert user.memberships.exists?(organization: organization)
    assert user.memberships.first.has_role?(Role::APP_OWNER, scope: :app)
    assert_equal 1, user.organizations.first.calendars.count
    assert user.organizations.first.calendars.find_by!(is_default: true)
  end

  test "create_personal_for! resolves slug collisions across different email domains" do
    user_one = User.create!(email: "jane.doe@gmail.com", password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52", confirmed_at: Time.current)
    user_two = User.create!(email: "jane.doe@yahoo.com", password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52", confirmed_at: Time.current)

    org_one = Organization.create_personal_for!(user_one)
    org_two = Organization.create_personal_for!(user_two)

    assert_not_equal org_one.slug, org_two.slug
    assert_equal "jane-doe", org_one.slug
    assert_equal "jane-doe-2", org_two.slug
  end

  test "current_plan returns the trial plan while on a no-card trial" do
    organization = Organization.create_personal_for!(users(:one))

    assert_not organization.subscribed?
    assert_equal Billing::Plans::BUSINESS, organization.current_plan
    assert_nil organization.member_limit
  end

  test "current_plan resolves to the plan matching the active subscription's price" do
    organization = Organization.create_personal_for!(users(:one))

    with_active_subscription(organization, Billing::Plans::STARTER) do
      assert_equal Billing::Plans::STARTER, organization.current_plan
      assert_equal 1, organization.member_limit
    end
  end

  test "current_plan is nil once the subscription is canceled and trial cleared" do
    organization = create_personal_without_trial!(users(:one))

    with_active_subscription(organization, Billing::Plans::STARTER) do
      organization.payment_processor.subscription.update!(status: "canceled", ends_at: 1.day.ago)
    end

    assert_nil organization.current_plan
  end

  test "member_count_with_pending counts memberships and outstanding invitations, not revoked ones" do
    organization = Organization.create_personal_for!(users(:one))
    role = Role.find_or_create_by!(scope: :app, name: Role::APP_USER)

    assert_equal 1, organization.member_count_with_pending

    invitation, = OrganizationInvitation.generate_for!(organization: organization, email: "a@example.com", role: role)
    assert_equal 2, organization.member_count_with_pending

    invitation.revoke!
    assert_equal 1, organization.member_count_with_pending
  end

  test "at_member_limit? is true for a fresh unsubscribed org on starter limits" do
    organization = create_personal_without_trial!(users(:one))

    assert organization.at_member_limit?
    assert_equal 0, organization.remaining_seats
  end

  test "at_member_limit? is false on Business with unlimited seats" do
    organization = Organization.create_personal_for!(users(:one))

    with_active_subscription(organization, Billing::Plans::BUSINESS) do
      assert_not organization.at_member_limit?
      assert_nil organization.remaining_seats
    end
  end

  test "over_member_limit? reflects the over_member_limit_at flag, not a live recompute" do
    organization = Organization.create_personal_for!(users(:one))

    assert_not organization.over_member_limit?
    organization.update!(over_member_limit_at: Time.current)
    assert organization.over_member_limit?
  end

  test "change_plan! raises without a payment method when not on trial" do
    organization = create_personal_without_trial!(users(:one))

    with_resolvable_price(Billing::Plans::STARTER) do
      assert_raises(ArgumentError) { organization.change_plan!(Billing::Plans.find("starter")) }
    end
  end

  test "change_plan! switches trial plan without a payment method" do
    organization = Organization.create_personal_for!(users(:one))
    assert organization.on_trial?

    with_resolvable_price(Billing::Plans::BUSINESS) do
      assert_equal :trial_plan_changed, organization.change_plan!(Billing::Plans.find("business"))
    end

    assert_equal "business", organization.reload.trial_plan_key
    assert_equal Billing::Plans::BUSINESS, organization.current_plan
  end

  test "change_plan! converts trial to paid subscription with a payment method" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_resolvable_price(Billing::Plans::STARTER) do
      assert_difference "Pay::Subscription.count", 1 do
        assert_equal :converted, organization.change_plan!(Billing::Plans.find("starter"))
      end
    end

    assert organization.reload.subscribed?
    assert_not organization.on_trial?
    assert_nil organization.trial_plan_key
  end

  test "finalize_checkout_session! keeps local trial state when the synced subscription is still on a Stripe trial" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_test123")
    trial_ends_at = organization.trial_ends_at

    fake_stripe_subscription = customer.subscriptions.create!(
      name: "default", processor_id: "sub_test123", processor_plan: "price_fake_business_gbp",
      status: "trialing", trial_ends_at: trial_ends_at, quantity: 1
    )
    fake_session = Struct.new(:client_reference_id, :status, :subscription).new(
      Pay::Stripe.to_client_reference_id(organization), "complete", "sub_test123"
    )

    result = Stripe::Checkout::Session.stub(:retrieve, fake_session) do
      Pay::Stripe::Subscription.stub(:sync, fake_stripe_subscription) do
        organization.finalize_checkout_session!("cs_test123")
      end
    end

    assert_equal :complete, result
    organization.reload
    assert organization.subscribed?
    assert organization.on_trial?
    assert_equal trial_ends_at.to_i, organization.trial_ends_at.to_i
    assert_equal "business", organization.trial_plan_key
  end

  test "finalize_checkout_session! clears local trial state once the synced subscription is fully active" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_test123")

    fake_stripe_subscription = customer.subscriptions.create!(
      name: "default", processor_id: "sub_test123", processor_plan: "price_fake_business_gbp",
      status: "active", quantity: 1
    )
    fake_session = Struct.new(:client_reference_id, :status, :subscription).new(
      Pay::Stripe.to_client_reference_id(organization), "complete", "sub_test123"
    )

    result = Stripe::Checkout::Session.stub(:retrieve, fake_session) do
      Pay::Stripe::Subscription.stub(:sync, fake_stripe_subscription) do
        organization.finalize_checkout_session!("cs_test123")
      end
    end

    assert_equal :complete, result
    organization.reload
    assert organization.subscribed?
    assert_not organization.on_trial?
    assert_nil organization.trial_plan_key
  end

  test "change_plan! subscribes immediately when account trial was already used" do
    organization = create_personal_without_trial!(users(:one))
    customer = organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_resolvable_price(Billing::Plans::STARTER) do
      assert_equal :created, organization.change_plan!(Billing::Plans.find("starter"))
    end

    assert organization.reload.subscribed?
    assert_nil organization.payment_processor.subscription.trial_ends_at
  end

  test "change_plan! subscribes Business from a non-trialing org with no local trial" do
    organization = create_personal_without_trial!(users(:one))
    customer = organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_resolvable_price(Billing::Plans::BUSINESS) do
      assert_equal :created, organization.change_plan!(Billing::Plans.find("business"))
    end

    assert organization.reload.subscribed?
  end

  test "change_plan! upgrades in place, keeping a single subscription" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_active_subscription(organization, Billing::Plans::STARTER) do
      with_resolvable_price(Billing::Plans::BUSINESS) do
        assert_no_difference "Pay::Subscription.count" do
          assert_equal :upgraded, organization.change_plan!(Billing::Plans.find("business"))
        end
      end
    end
  end

  test "change_plan! passes an applied promotion code through to Stripe on upgrade" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_test123")
    customer.payment_methods.create!(processor_id: "pm_test123", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    # `swap` reads the subscription's current item id off the locally-synced `object` JSON
    # (Pay::Stripe::Subscription#subscription_items => stripe_object.items) rather than making a
    # live Stripe API call as long as that column is already populated - set it directly so this
    # test doesn't need to stub Stripe::Subscription.retrieve too.
    fake_stripe_subscription = customer.subscriptions.create!(
      name: "default", processor_id: "sub_test123", processor_plan: "price_fake_starter_gbp", status: "active", quantity: 1,
      object: { id: "sub_test123", items: { object: "list", data: [ { id: "si_test123" } ] } }
    )
    captured_params = nil
    # Pay::Stripe::Subscription#swap reads latest_invoice.payments off the Stripe::Subscription
    # update result (for SCA validation), then sync!s it - return a minimal Stripe-shaped
    # object and stub sync so this test only asserts the discounts kwargs we care about.
    stripe_update_result = Struct.new(:latest_invoice).new(Struct.new(:payments).new([]))

    Stripe::Subscription.stub(:update, ->(_id, params, _opts = nil) { captured_params = params; stripe_update_result }) do
      Pay::Stripe::Subscription.stub(:sync, fake_stripe_subscription) do
        Billing::Plans.stub(:for_stripe_price, Billing::Plans::STARTER) do
          with_resolvable_price(Billing::Plans::BUSINESS) do
            organization.change_plan!(Billing::Plans.find("business"), promotion_code: "promo_test123")
          end
        end
      end
    end

    assert_equal [ { promotion_code: "promo_test123" } ], captured_params[:discounts]
  end

  test "apply_promotion_code! attaches the discount to the live subscription" do
    organization = Organization.create_personal_for!(users(:one))
    captured_args = nil

    with_active_subscription(organization, Billing::Plans::STARTER) do
      subscription_id = organization.payment_processor.subscription.processor_id
      Stripe::Subscription.stub(:update, ->(id, params) { captured_args = [ id, params ] }) do
        organization.apply_promotion_code!("promo_test123")
      end
      assert_equal subscription_id, captured_args[0]
    end

    assert_equal [ { promotion_code: "promo_test123" } ], captured_args[1][:discounts]
  end

  test "apply_promotion_code! raises without an active subscription" do
    organization = Organization.create_personal_for!(users(:one))
    organization.set_payment_processor(:fake_processor, allow_fake: true)

    assert_raises(ArgumentError) { organization.apply_promotion_code!("promo_test123") }
  end

  test "remove_promotion_code! clears discounts from the live subscription" do
    organization = Organization.create_personal_for!(users(:one))
    captured_args = nil

    with_active_subscription(organization, Billing::Plans::STARTER) do
      Stripe::Subscription.stub(:update, ->(id, params) { captured_args = [ id, params ] }) do
        organization.remove_promotion_code!
      end
    end

    assert_equal [], captured_args[1][:discounts]
  end

  test "upcoming_invoice_preview returns nil (not an error) when there's nothing active" do
    organization = Organization.create_personal_for!(users(:one))
    assert_nil organization.upcoming_invoice_preview
  end

  test "upcoming_invoice_breakdown labels tax when Stripe returns a tax rate id string" do
    organization = Organization.create_personal_for!(users(:one))
    tax_rate_details = Struct.new(:tax_rate).new("txr_test123")
    tax_amount = Struct.new(:amount, :taxable_amount, :tax_rate_details).new(600, 2999, tax_rate_details)
    fake_preview = Struct.new(:currency, :subtotal, :total, :total_taxes).new("gbp", 2999, 3599, [ tax_amount ])

    with_active_subscription(organization, Billing::Plans::BUSINESS) do
      Billing::Tax.stub(:collect_vat?, true) do
        Stripe::Invoice.stub(:create_preview, fake_preview) do
          breakdown = organization.upcoming_invoice_breakdown

          assert_equal "VAT (20%)", breakdown[:lines].second[:label]
        end
      end
    end
  end

  test "upcoming_invoice_breakdown returns ex-VAT, tax, and inc-VAT totals" do
    organization = Organization.create_personal_for!(users(:one))
    tax_rate = Struct.new(:display_name, :percentage).new("VAT", 20.0)
    tax_rate_details = Struct.new(:tax_rate).new(tax_rate)
    tax_amount = Struct.new(:amount, :tax_rate_details).new(600, tax_rate_details)
    fake_preview = Struct.new(:currency, :subtotal, :total, :total_taxes).new("gbp", 2999, 3599, [ tax_amount ])

    with_active_subscription(organization, Billing::Plans::BUSINESS) do
      Billing::Tax.stub(:collect_vat?, true) do
        Stripe::Invoice.stub(:create_preview, fake_preview) do
          breakdown = organization.upcoming_invoice_breakdown

          assert_equal "Business (ex VAT)", breakdown[:lines].first[:label]
          assert_equal "£29.99", breakdown[:lines].first[:amount]
          assert_match "VAT", breakdown[:lines].second[:label]
          assert_equal "£6.00", breakdown[:lines].second[:amount]
          assert_equal "£35.99", breakdown[:total]
          assert_equal "", breakdown[:footnote]
        end
      end
    end
  end

  test "upcoming_invoice_breakdown omits VAT lines when collect_vat is false" do
    organization = Organization.create_personal_for!(users(:one))
    fake_preview = Struct.new(:currency, :subtotal, :total, :amount_due, :total_taxes).new("gbp", 2999, 2999.3, 2999.3, [])

    with_active_subscription(organization, Billing::Plans::BUSINESS) do
      Billing::Tax.stub(:collect_vat?, false) do
        Stripe::Invoice.stub(:create_preview, fake_preview) do
          breakdown = organization.upcoming_invoice_breakdown

          assert_nil breakdown[:lines]
          assert_equal "£29.99", breakdown[:total]
          assert_nil breakdown[:footnote]
        end
      end
    end
  end

  test "upcoming_invoice_preview reflects a live Stripe preview" do
    organization = Organization.create_personal_for!(users(:one))
    fake_preview = Struct.new(:total, :currency).new(0, "usd")

    with_active_subscription(organization, Billing::Plans::STARTER) do
      Stripe::Invoice.stub(:create_preview, fake_preview) do
        assert_equal fake_preview, organization.upcoming_invoice_preview
      end
    end
  end

  test "upcoming_invoice_preview returns nil instead of raising when Stripe errors" do
    organization = Organization.create_personal_for!(users(:one))

    with_active_subscription(organization, Billing::Plans::STARTER) do
      Stripe::Invoice.stub(:create_preview, ->(*) { raise Stripe::StripeError, "boom" }) do
        assert_nil organization.upcoming_invoice_preview
      end
    end
  end

  test "change_plan! schedules a downgrade at period end instead of applying it now" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    period_end = 20.days.from_now.to_i
    phase_item = Struct.new(:price, :quantity).new("price_fake_business_gbp", 1)
    phase = Struct.new(:items, :start_date, :end_date).new([ phase_item ], 10.days.ago.to_i, period_end)
    fake_schedule = Struct.new(:id, :phases).new("sub_sched_test123", [ phase ])
    schedule_update_args = nil

    with_active_subscription(organization, Billing::Plans::BUSINESS) do
      with_resolvable_price(Billing::Plans::STARTER) do
        Stripe::SubscriptionSchedule.stub(:create, fake_schedule) do
          Stripe::SubscriptionSchedule.stub(:update, ->(id, params) { schedule_update_args = [ id, params ]; fake_schedule }) do
            assert_equal :downgrade_scheduled, organization.change_plan!(Billing::Plans.find("starter"))
          end
        end
      end

      # The live subscription is untouched until Stripe flips it at renewal.
      assert_equal "price_fake_business_gbp", organization.payment_processor.subscription.processor_plan
    end

    organization.reload
    assert_equal "starter", organization.pending_plan_key
    assert_equal "sub_sched_test123", organization.stripe_subscription_schedule_id
    assert_in_delta period_end, organization.pending_plan_change_at.to_i, 1

    assert_equal "sub_sched_test123", schedule_update_args[0]
    assert_equal "release", schedule_update_args[1][:end_behavior]
    assert_equal "price_fake_starter_gbp", schedule_update_args[1][:phases].last[:items].first[:price]
  end

  test "cancel_scheduled_downgrade! releases the schedule and clears pending state" do
    organization = Organization.create_personal_for!(users(:one))
    organization.update!(pending_plan_key: "starter", pending_plan_change_at: 20.days.from_now,
      stripe_subscription_schedule_id: "sub_sched_test123")

    released_id = nil
    Stripe::SubscriptionSchedule.stub(:release, ->(id) { released_id = id }) do
      organization.cancel_scheduled_downgrade!
    end

    assert_equal "sub_sched_test123", released_id
    organization.reload
    assert_nil organization.pending_plan_key
    assert_nil organization.pending_plan_change_at
    assert_nil organization.stripe_subscription_schedule_id
  end

  test "schedule_price_migration! schedules the new price at period end without touching the live subscription" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    period_end = 20.days.from_now.to_i
    phase_item = Struct.new(:price, :quantity).new("price_fake_starter_gbp", 1)
    phase = Struct.new(:items, :start_date, :end_date).new([ phase_item ], 10.days.ago.to_i, period_end)
    fake_schedule = Struct.new(:id, :phases).new("sub_sched_test123", [ phase ])
    schedule_update_args = nil

    with_active_subscription(organization, Billing::Plans::STARTER) do
      Stripe::SubscriptionSchedule.stub(:create, fake_schedule) do
        Stripe::SubscriptionSchedule.stub(:update, ->(id, params) { schedule_update_args = [ id, params ]; fake_schedule }) do
          organization.schedule_price_migration!(new_price_id: "price_new_starter_gbp", new_price_cents: 1500)
        end
      end

      # The live subscription is untouched until Stripe flips it at renewal.
      assert_equal "price_fake_starter_gbp", organization.payment_processor.subscription.processor_plan
    end

    organization.reload
    assert_equal 1500, organization.pending_price_cents
    assert_nil organization.pending_plan_key
    assert_equal "sub_sched_test123", organization.stripe_subscription_schedule_id
    assert_in_delta period_end, organization.pending_plan_change_at.to_i, 1
    assert_equal "release", schedule_update_args[1][:end_behavior]
    assert_equal "price_new_starter_gbp", schedule_update_args[1][:phases].last[:items].first[:price]
  end

  test "schedule_price_migration! refuses to run for a grandfathered organization" do
    organization = Organization.create_personal_for!(users(:one))
    organization.grandfather!

    with_active_subscription(organization, Billing::Plans::STARTER) do
      assert_raises(ArgumentError) do
        organization.schedule_price_migration!(new_price_id: "price_new_starter_gbp", new_price_cents: 1500)
      end
    end
  end

  test "schedule_price_migration! refuses to run when a downgrade is already pending" do
    organization = Organization.create_personal_for!(users(:one))
    organization.update!(pending_plan_key: "starter", pending_plan_change_at: 20.days.from_now,
      stripe_subscription_schedule_id: "sub_sched_test123")

    with_active_subscription(organization, Billing::Plans::BUSINESS) do
      assert_raises(ArgumentError) do
        organization.schedule_price_migration!(new_price_id: "price_new_starter_gbp", new_price_cents: 1500)
      end
    end
  end

  test "grandfather!/ungrandfather! toggle grandfathered_at and grandfathered?" do
    organization = Organization.create_personal_for!(users(:one))
    assert_not organization.grandfathered?

    organization.grandfather!
    assert organization.grandfathered?

    organization.ungrandfather!
    assert_not organization.grandfathered?
  end

  test "Organization.on_stripe_price finds organizations with an active subscription on that price" do
    on_price = Organization.create_personal_for!(users(:one))
    with_active_subscription(on_price, Billing::Plans::STARTER) do
      other_price = Organization.create_personal_for!(users(:two))
      with_active_subscription(other_price, Billing::Plans::BUSINESS) do
        found = Organization.on_stripe_price("price_fake_starter_gbp")
        assert_includes found, on_price
        assert_not_includes found, other_price
      end
    end
  end

  test "cancel_subscription! cancels at period end and keeps the subscription active until then" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:fake_processor, allow_fake: true)
    customer.payment_methods.create!(processor_id: "pm_fake", default: true, payment_method_type: "card", brand: "Visa", last4: "4242")

    with_active_subscription(organization, Billing::Plans::STARTER) do
      organization.cancel_subscription!

      subscription = organization.payment_processor.subscription.reload
      assert subscription.active?
      assert subscription.ends_at.present?
      assert subscription.on_grace_period?
    end
  end

  test "create_personal_for! starts a no-card trial for the account's first org" do
    user = users(:two)
    assert user.trial_available?

    organization = Organization.create_personal_for!(user)

    assert organization.on_trial?
    assert_equal Billing::Plans::BUSINESS.key, organization.trial_plan_key
    assert user.reload.trial_granted_at.present?
    assert organization.trial_used_at.present?
  end

  test "create_personal_for! does not start a trial when the account already used one" do
    user = users(:one)
    user.update!(trial_granted_at: 1.year.ago)

    organization = Organization.create_personal_for!(user)

    assert_not organization.on_trial?
    assert_nil organization.trial_plan_key
  end

  test "trial_eligible? is always false under no-card trials" do
    organization = Organization.create_personal_for!(users(:one))

    assert_not organization.trial_eligible?(Billing::Plans::STARTER)
    assert_not organization.trial_eligible?(Billing::Plans::BUSINESS)
  end

  test "preferred_currency must be a supported currency" do
    organization = Organization.create_personal_for!(users(:one))

    organization.preferred_currency = "eur"
    assert_not organization.valid?

    organization.preferred_currency = "gbp"
    assert organization.valid?
  end

  test "billing_currency defaults to GBP while unsubscribed" do
    organization = Organization.create_personal_for!(users(:one))

    assert_equal "gbp", organization.billing_currency
  end

  test "billing_currency locks to the active subscription's currency once subscribed" do
    organization = Organization.create_personal_for!(users(:one))

    with_active_subscription(organization, Billing::Plans::STARTER, currency: "gbp") do
      assert_equal "gbp", organization.billing_currency
    end
  end

  test "stripe_billing_address is nil until any address field is set" do
    organization = Organization.create_personal_for!(users(:one))
    assert_nil organization.stripe_billing_address

    organization.update!(billing_address_city: "Springfield")
    assert_equal "Springfield", organization.stripe_billing_address[:city]
  end

  test "sync_billing_details! persists locally and pushes name/address to the Stripe customer" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_test123")

    update_attributes = nil
    fake_update = ->(_processor_id, attributes, _opts) { update_attributes = attributes }

    Stripe::Customer.stub(:update, fake_update) do
      organization.sync_billing_details!(name: "Jane Doe", address: { line1: "1 Main St", country: "US" })
    end

    assert_equal "Jane Doe", organization.billing_name
    assert_equal "1 Main St", organization.billing_address_line1
    assert_equal "Jane Doe", update_attributes[:name]
    assert_equal "1 Main St", update_attributes[:address][:line1]
  end

  test "the Stripe customer attributes fall back to the organization's own name until a billing name is set" do
    organization = Organization.create_personal_for!(users(:one))
    customer = organization.set_payment_processor(:stripe)

    assert_equal organization.name, customer.api_record_attributes[:name]
    assert_nil customer.api_record_attributes[:address]

    organization.update!(billing_name: "Custom Billing Name", billing_address_country: "US")
    assert_equal "Custom Billing Name", customer.api_record_attributes[:name]
    assert_equal "US", customer.api_record_attributes[:address][:country]
  end

  test "new organizations get default operating hours and bookable times" do
    organization = Organization.create!(name: "Hours Test", slug: "hours-test-#{SecureRandom.hex(4)}")

    assert_equal Organization::DEFAULT_OPERATING_HOURS, organization.operating_hours
    assert_equal Organization::DEFAULT_BOOKABLE_TIMES, organization.bookable_times
    assert_equal "uk", organization.postcode_region
  end

  test "postcode_region must be a supported region" do
    organization = Organization.create!(name: "Region Test", slug: "region-test-#{SecureRandom.hex(4)}")

    organization.postcode_region = "de"
    assert_not organization.valid?
    assert_includes organization.errors[:postcode_region], "is not included in the list"

    organization.postcode_region = "us"
    assert organization.valid?
  end

  test "new organizations default service_currency to gbp" do
    organization = Organization.create!(name: "Currency Test", slug: "currency-test-#{SecureRandom.hex(4)}")

    assert_equal "gbp", organization.service_currency
  end

  test "service_currency must be a supported currency" do
    organization = Organization.create!(name: "Currency Test", slug: "currency-test-2-#{SecureRandom.hex(4)}")

    organization.service_currency = "jpy"
    assert_not organization.valid?
    assert_includes organization.errors[:service_currency], "is not included in the list"

    organization.service_currency = "usd"
    assert organization.valid?
  end

  test "service_currency_symbol returns the symbol for the organization's service currency" do
    organization = Organization.create!(name: "Currency Test", slug: "currency-test-3-#{SecureRandom.hex(4)}")

    assert_equal "£", organization.service_currency_symbol

    organization.update!(service_currency: "usd")
    assert_equal "$", organization.service_currency_symbol

    organization.update!(service_currency: "eur")
    assert_equal "€", organization.service_currency_symbol
  end

  test "business_type must be a known preset key or blank" do
    organization = Organization.create!(name: "Business Type Test", slug: "business-type-test-#{SecureRandom.hex(4)}")

    assert organization.valid?

    organization.business_type = "not-a-real-preset"
    assert_not organization.valid?
    assert_includes organization.errors[:business_type], "is not included in the list"

    organization.business_type = "clinic"
    assert organization.valid?
  end

  test "kiosk homescreen toggles default correctly" do
    organization = Organization.create!(name: "Kiosk Defaults", slug: "kiosk-defaults-#{SecureRandom.hex(4)}")

    assert_not organization.kiosk_show_featured_service?
    assert organization.kiosk_show_services?
    assert organization.kiosk_show_appointments?
  end

  test "invalid when all homescreen buttons are hidden" do
    organization = Organization.new(
      name: "No Buttons",
      slug: "no-buttons-#{SecureRandom.hex(4)}",
      kiosk_show_featured_service: false,
      kiosk_show_services: false,
      kiosk_show_appointments: false
    )

    assert_not organization.valid?
    assert_includes organization.errors[:base], "At least one homescreen button must be visible"
  end

  test "invalid when featured service is enabled without a selected service" do
    organization = Organization.new(
      name: "Featured Missing",
      slug: "featured-missing-#{SecureRandom.hex(4)}",
      kiosk_show_featured_service: true,
      kiosk_featured_service_id: nil
    )

    assert_not organization.valid?
    assert_includes organization.errors[:base], "A service must be selected for the featured slot"
  end

  test "kiosk featured service must belong to the organization" do
    organization = Organization.create!(name: "Featured Org", slug: "featured-org-#{SecureRandom.hex(4)}")
    other = Organization.create!(name: "Other Org", slug: "other-org-#{SecureRandom.hex(4)}")
    foreign_service = other.services.create!(
      internal_name: "foreign",
      display_name: "Foreign",
      estimated_duration: 10
    )

    organization.kiosk_show_featured_service = true
    organization.kiosk_featured_service_id = foreign_service.id

    assert_not organization.valid?
    assert_includes organization.errors[:kiosk_featured_service_id], "must be an active service in this organization"
  end

  test "supports kiosk_logo attachment" do
    organization = Organization.create!(name: "Logo Org", slug: "logo-org-#{SecureRandom.hex(4)}")

    organization.kiosk_logo.attach(
      io: StringIO.new("fake-logo"),
      filename: "logo.txt",
      content_type: "text/plain"
    )

    assert organization.kiosk_logo.attached?
  end

  test "open_on? reflects configured hours and open_now? checks the current clock" do
    organization = Organization.create!(name: "Hours Org", slug: "hours-org-#{SecureRandom.hex(4)}")
    monday = Date.parse("2026-07-13")

    assert organization.open_on?(monday)
    assert_not organization.open_on?(monday + 6.days)

    travel_to monday.in_time_zone.change(hour: 10, min: 0) do
      assert organization.open_now?
    end

    travel_to monday.in_time_zone.change(hour: 19, min: 0) do
      assert_not organization.open_now?
    end
  end

  test "full_address joins the address fields" do
    organization = Organization.new(
      name: "Address Org", slug: "address-org-#{SecureRandom.hex(4)}",
      address_line1: "1 Market St", address_city: "San Francisco",
      address_state: "CA", address_postal_code: "94105", address_country: "US"
    )

    assert_equal "1 Market St, San Francisco, CA, 94105, US", organization.full_address
  end

  test "appointment_email_message_text falls back to the default message" do
    organization = Organization.create_personal_for!(users(:one))

    assert_nil organization.appointment_email_message
    assert_equal Organization::DEFAULT_APPOINTMENT_EMAIL_MESSAGE, organization.appointment_email_message_text
  end

  test "appointment_email_message stores a custom message with normalized line endings" do
    organization = Organization.create_personal_for!(users(:one))

    organization.update!(appointment_email_message: "  Bring your inhaler.\r\nPark round the back.  ")

    assert_equal "Bring your inhaler.\nPark round the back.", organization.reload.appointment_email_message
    assert_equal "Bring your inhaler.\nPark round the back.", organization.appointment_email_message_text
  end

  test "saving a blank or unchanged default appointment email message keeps following the default" do
    organization = Organization.create_personal_for!(users(:one))
    organization.update!(appointment_email_message: "Custom")

    organization.update!(appointment_email_message: "")
    assert_nil organization.reload.appointment_email_message

    organization.update!(appointment_email_message: Organization::DEFAULT_APPOINTMENT_EMAIL_MESSAGE.gsub("\n", "\r\n"))
    assert_nil organization.reload.appointment_email_message
  end

  test "appointment_email_message is limited in length" do
    organization = Organization.create_personal_for!(users(:one))

    organization.appointment_email_message = "a" * (Organization::APPOINTMENT_EMAIL_MESSAGE_MAX_LENGTH + 1)

    assert_not organization.valid?
    assert organization.errors[:appointment_email_message].any?
  end
end
