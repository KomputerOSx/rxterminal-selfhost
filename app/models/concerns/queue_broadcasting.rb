# frozen_string_literal: true

module QueueBroadcasting
  extend ActiveSupport::Concern
  include ActionView::RecordIdentifier

  included do
    after_create_commit :broadcast_new_customer
    after_create_commit :broadcast_new_customer_to_waiting_display
    after_update_commit :broadcast_status_change
    after_update_commit :broadcast_status_change_to_waiting_display
    after_destroy_commit :broadcast_removal
    after_destroy_commit :broadcast_removal_to_waiting_display
  end

  private

  def queue_stream
    "organization_#{organization_id}_queue"
  end

  def waiting_display_stream
    "organization_#{organization_id}_waiting_display"
  end

  def broadcast_new_customer
    broadcast_append_to(
      queue_stream,
      target: "waiting-cards",
      partial: "org/queue/waiting_card",
      locals: { request: self }
    )

    broadcast_all_stats
  end

  def broadcast_new_customer_to_waiting_display
    broadcast_append_to(
      waiting_display_stream,
      target: "waiting-cards",
      partial: "org/waiting_display/waiting_number",
      locals: { request: self }
    )
  end

  def broadcast_status_change
    return unless saved_change_to_status?

    case status
    when "waiting"
      if previous_status == "in_progress"
        broadcast_remove_to(queue_stream, target: dom_id(self, :in_progress))
      end

      if previous_status == "completed"
        broadcast_remove_to(queue_stream, target: dom_id(self, :completed))
      end

      broadcast_prepend_to(
        queue_stream,
        target: "waiting-cards",
        partial: "org/queue/waiting_card",
        locals: { request: self }
      )
    when "in_progress"
      if previous_status == "waiting"
        broadcast_remove_to(queue_stream, target: dom_id(self, :waiting))
      end

      if previous_status == "completed"
        broadcast_remove_to(queue_stream, target: dom_id(self, :completed))
      end

      broadcast_append_to(
        queue_stream,
        target: "in-progress-cards",
        partial: "org/queue/in_progress_card",
        locals: { request: self }
      )
    when "completed"
      broadcast_remove_to(queue_stream, target: dom_id(self, :in_progress))

      broadcast_prepend_to(
        queue_stream,
        target: "completed-cards",
        partial: "org/queue/completed_card",
        locals: { request: self }
      )
    when "cancelled"
      broadcast_remove_to(queue_stream, target: dom_id(self, :waiting))
    end

    broadcast_all_stats
  end

  def broadcast_removal
    broadcast_remove_to(queue_stream, target: dom_id(self, :waiting))
    broadcast_remove_to(queue_stream, target: dom_id(self, :in_progress))
    broadcast_all_stats
  end

  def broadcast_all_stats
    today_scope = Date.current.all_day

    # waiting/in_progress intentionally aren't restricted to "today" - they mirror
    # Org::QueueController#load_queue_data's @waiting/@in_progress, which is what's actually
    # rendered on the board (a request can still be waiting/in progress past midnight). Only
    # completed/total need a "today" cutoff to mean anything.
    waiting_count = organization.service_requests.where(status: "waiting").count
    in_progress_count = organization.service_requests.where(status: "in_progress").count
    completed_count = organization.service_requests.where(status: "completed", created_at: today_scope).count
    total_count = organization.service_requests.where(created_at: today_scope).count

    broadcast_update_to(queue_stream, target: "stat-waiting", html: waiting_count.to_s)
    broadcast_update_to(queue_stream, target: "stat-in-progress", html: in_progress_count.to_s)
    broadcast_update_to(queue_stream, target: "stat-completed", html: completed_count.to_s)
    broadcast_update_to(queue_stream, target: "stat-total", html: total_count.to_s)

    broadcast_update_to(waiting_display_stream, target: "waitingCount", html: waiting_count.to_s)
    broadcast_update_to(waiting_display_stream, target: "inProgressCount", html: in_progress_count.to_s)

    return unless organization.waiting_time_enabled?

    avg = ServiceRequest.average_wait_minutes(organization_id, since: organization.waiting_time_reset_at)
    avg_html = avg ? "#{avg} min" : "N/A"
    broadcast_update_to(queue_stream, target: "stat-avg-wait", html: avg_html)
    broadcast_update_to(waiting_display_stream, target: "stat-avg-wait", html: avg_html)
  end

  def broadcast_status_change_to_waiting_display
    return unless saved_change_to_status?

    case status
    when "waiting"
      broadcast_remove_to(waiting_display_stream, target: dom_id(self, :waiting_display_in_progress))

      broadcast_prepend_to(
        waiting_display_stream,
        target: "waiting-cards",
        partial: "org/waiting_display/waiting_number",
        locals: { request: self }
      )
    when "in_progress"
      broadcast_remove_to(waiting_display_stream, target: dom_id(self, :waiting_display_waiting))

      broadcast_append_to(
        waiting_display_stream,
        target: "in-progress-cards",
        partial: "org/waiting_display/in_progress_number",
        locals: { request: self }
      )
    when "completed"
      broadcast_remove_to(waiting_display_stream, target: dom_id(self, :waiting_display_in_progress))
    when "cancelled"
      broadcast_remove_to(waiting_display_stream, target: dom_id(self, :waiting_display_waiting))
    end
  end

  def broadcast_removal_to_waiting_display
    broadcast_remove_to(waiting_display_stream, target: dom_id(self, :waiting_display_waiting))
    broadcast_remove_to(waiting_display_stream, target: dom_id(self, :waiting_display_in_progress))
  end
end
