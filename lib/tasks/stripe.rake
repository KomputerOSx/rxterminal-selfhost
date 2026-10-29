namespace :stripe do
  desc "Replay a specific Stripe event through the normal webhook processing pipeline"
  task :replay_event, [ :event_id ] => :environment do |_, args|
    event_id = args[:event_id]
    abort "Usage: bin/rails stripe:replay_event[evt_xxx]" if event_id.blank?

    if Billing::StripeEventReceipt.exists?(stripe_event_id: event_id)
      abort "Event #{event_id} already has a receipt - it was already received. Skipping to avoid duplicate processing."
    end

    event = Stripe::Event.retrieve(event_id)

    record = Pay::Webhook.create!(processor: :stripe, event_type: event.type, event: event.to_hash)
    record.process!

    puts "Replayed #{event.id} (#{event.type})."
  end
end
