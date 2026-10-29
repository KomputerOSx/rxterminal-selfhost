# frozen_string_literal: true

require "test_helper"

class Billing::PlanReconciliationsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "downgrading to Starter redirects into the wizard when over Starter limits" do
    post login_path, params: { email: @owner.email, password: "password123" }
    @organization.memberships.create!(user: users(:two))

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
    end

    assert_redirected_to billing_plan_reconciliation_path
  end

  test "plan reconciliation blocks operational pages until immediate setup completes" do
    post login_path, params: { email: @owner.email, password: "password123" }
    @organization.memberships.create!(user: users(:two))
    services = 4.times.map do |index|
      @organization.services.create!(
        internal_name: "svc_#{index}",
        display_name: "Service #{index}",
        estimated_duration: 15,
        display_order: index
      )
    end

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.require_plan_reconciliation_blocking!

      get org_services_path
      assert_redirected_to billing_plan_reconciliation_path

      patch billing_plan_reconciliation_path, params: { step: :intro }
      patch billing_plan_reconciliation_path, params: { step: :members }
      patch billing_plan_reconciliation_path, params: { step: :services, service_ids: services.first(3).map(&:id) }
      patch billing_plan_reconciliation_path, params: { step: :confirm }

      assert_redirected_to dashboard_path
      assert_not @organization.reload.plan_reconciliation_required?
      assert_equal 3, @organization.services.plan_active.count
    end
  end

  test "plan reconciliation go back preserves saved choices" do
    post login_path, params: { email: @owner.email, password: "password123" }
    @organization.memberships.create!(user: users(:two))
    services = 4.times.map do |index|
      @organization.services.create!(
        internal_name: "svc_#{index}",
        display_name: "Service #{index}",
        estimated_duration: 15,
        display_order: index
      )
    end
    kept_service_ids = services.first(3).map(&:id)

    with_active_subscription(@organization, Billing::Plans::STARTER) do
      @organization.require_plan_reconciliation_blocking!

      patch billing_plan_reconciliation_path, params: { step: :intro }
      patch billing_plan_reconciliation_path, params: { step: :members }
      patch billing_plan_reconciliation_path, params: { step: :services, service_ids: kept_service_ids }
      assert_redirected_to billing_plan_reconciliation_path(step: :confirm)

      get billing_plan_reconciliation_path(step: :services)
      assert_response :success
      assert_select "input[name='service_ids[]'][value='#{kept_service_ids.first}'][checked='checked']"

      get billing_plan_reconciliation_path(step: :members)
      assert_response :success
      assert_select "a.btn.btn-outline.btn-sm", text: "Go back", count: 1
      assert_select "a.btn.btn-outline.btn-sm[href=?]", billing_plan_reconciliation_path(step: :intro)
    end
  end
end
