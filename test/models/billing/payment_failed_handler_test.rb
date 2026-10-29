require "test_helper"
require "ostruct"

class Billing::PaymentFailedHandlerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @organization = Organization.create_personal_for!(users(:one))
    @handler = Billing::PaymentFailedHandler.new
  end

  test "logs an audit event and dispatches a notification for the subscription's owning organization" do
    customer = @organization.set_payment_processor(:fake_processor, allow_fake: true)
    subscription = customer.subscribe(plan: "price_fake_starter")

    event = invoice_event(subscription.processor_id)

    assert_difference -> { AuditLog.where(event_type: :payment_failed).count }, 1 do
      assert_enqueued_with(job: NotificationDispatchJob) do
        @handler.call(event)
      end
    end
  end

  test "does nothing when no local subscription matches the invoice" do
    event = invoice_event("sub_unknown")

    assert_no_difference -> { AuditLog.count } do
      @handler.call(event)
    end
  end

  private

  def invoice_event(subscription_processor_id)
    OpenStruct.new(data: OpenStruct.new(object: OpenStruct.new(id: "in_test123", subscription: subscription_processor_id)))
  end
end
