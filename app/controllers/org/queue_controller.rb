# frozen_string_literal: true

module Org
  class QueueController < BaseController
    before_action :authorize_view, only: [ :index, :poll ]
    before_action :authorize_manage, except: [ :index, :poll ]
    before_action :set_service_request, only: [ :update_status, :revert_completed, :revert_cancelled ]

    def index
      load_queue_data
    end

    def poll
      load_queue_data
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to org_queue_path }
      end
    end

    def refresh
      load_queue_data
      load_waiting_display_stats

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to org_queue_path }
      end
    end

    def call_next
      next_request = next_waiting_request

      if next_request
        next_request.call!
        log_audit(:customer_called, resource: next_request, metadata: queue_audit_metadata(next_request))
        respond_to_queue_update
      else
        respond_to_empty_queue
      end
    end

    def update_status
      previous_status = @service_request.status

      case params[:status]
      when "in_progress"
        @service_request.call!
      when "completed"
        @service_request.complete!
      when "cancelled"
        @service_request.cancel!
      when "waiting"
        @service_request.revert_to_waiting!
      else
        respond_to_queue_error("Invalid status.", status: :bad_request)
        return
      end

      log_audit(:customer_status_updated, resource: @service_request, metadata: queue_audit_metadata(@service_request).merge(
        previous_status: previous_status,
        new_status: @service_request.status
      ))
      respond_to_queue_update
    end

    def revert_completed
      unless @service_request.status == "completed"
        respond_to_queue_error("Can only revert completed requests.")
        return
      end

      @service_request.revert_from_completed!
      log_audit(:customer_reverted, resource: @service_request, metadata: queue_audit_metadata(@service_request).merge(
        reverted_to: @service_request.status
      ))
      respond_to_queue_update(notice: "Reverted queue number #{@service_request.queue_number}.")
    end

    def revert_cancelled
      unless @service_request.status == "cancelled"
        respond_to_queue_error("Can only revert cancelled requests.")
        return
      end

      @service_request.revert_to_waiting!
      log_audit(:customer_reactivated, resource: @service_request, metadata: queue_audit_metadata(@service_request))
      respond_to_queue_update(notice: "Restored queue number #{@service_request.queue_number}.")
    end

    def undo_last_cancelled
      service_request = Current.organization.service_requests
        .where(status: "cancelled")
        .order(updated_at: :desc)
        .first

      unless service_request
        respond_to_queue_error("No recently cancelled customers to restore.", redirect: true)
        return
      end

      service_request.revert_to_waiting!
      log_audit(:customer_reactivated, resource: service_request, metadata: queue_audit_metadata(service_request))
      respond_to_queue_update(notice: "Restored queue number #{service_request.queue_number}.")
    end

    def reset_wait_timer
      Current.organization.reset_waiting_time_timer!
      log_audit(:wait_timer_reset, resource: Current.organization)
      respond_to_queue_update(notice: "Wait timer reset.", refresh_stats: true)
    end

    private

    def authorize_view
      authorize Current.organization, :index?, policy_class: QueuePolicy
    end

    def authorize_manage
      authorize Current.organization, :manage?, policy_class: QueuePolicy
    end

    def set_service_request
      @service_request = Current.organization.service_requests.find(params[:id])
    end

    def load_queue_data
      @service_ids = filter_service_ids
      @services = Current.organization.services.visible.active.by_display_order
      requests = Current.organization.service_requests.for_services(@service_ids)

      @waiting = requests.where(status: "waiting")
        .includes(:service, :appointment)
        .order(:created_at)
      @in_progress = requests.where(status: "in_progress")
        .includes(:service, :appointment)
        .order(:called_at)
      @completed_today = requests.where(status: "completed", created_at: Date.current.all_day)
        .includes(:service)
        .order(completed_at: :desc)

      today_scope = requests.where(created_at: Date.current.all_day)
      @queue_stats = {
        waiting: @waiting.size,
        in_progress: @in_progress.size,
        completed_today: today_scope.where(status: "completed").count,
        total_today: today_scope.count
      }

      if Current.organization.waiting_time_enabled?
        avg = ServiceRequest.average_wait_minutes(
          Current.organization.id,
          since: Current.organization.waiting_time_reset_at
        )
        @queue_stats[:avg_wait] = avg ? "#{avg} min" : "N/A"
      end
    end

    def load_waiting_display_stats
      return unless Current.organization.waiting_time_enabled?

      avg = ServiceRequest.average_wait_minutes(
        Current.organization.id,
        since: Current.organization.waiting_time_reset_at
      )
      @avg_wait_display = avg ? "#{avg} min" : "N/A"
    end

    def filter_service_ids
      ids = params[:service_ids]
      return nil if ids.blank?

      Array(ids).map(&:to_i).select(&:positive?)
    end

    def next_waiting_request
      Current.organization.service_requests
        .where(status: "waiting")
        .for_services(filter_service_ids)
        .order(:created_at)
        .first
    end

    def queue_audit_metadata(service_request)
      {
        queue_number: service_request.queue_number,
        service_id: service_request.service_id
      }
    end

    def respond_to_queue_update(notice: nil, refresh_stats: false)
      respond_to do |format|
        format.turbo_stream do
          streams = []

          if refresh_stats
            load_queue_data
            streams << turbo_stream.update("stat-avg-wait", @queue_stats[:avg_wait].to_s)
          end

          if notice.present?
            flash.now[:toast] = { message: notice, type: "success" }
            streams << turbo_stream.update("flash_messages", partial: "shared/flash")
          end

          if streams.any?
            render turbo_stream: streams
          else
            head :ok
          end
        end
        format.html do
          redirect_to org_queue_path(service_ids: filter_service_ids), notice: notice
        end
      end
    end

    def respond_to_empty_queue
      respond_to do |format|
        format.turbo_stream { head :ok }
        format.html { redirect_to org_queue_path(service_ids: filter_service_ids) }
      end
    end

    def respond_to_queue_error(message, status: :unprocessable_entity, redirect: false)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:toast] = { message: message, type: "error" }
          render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash"), status: status
        end
        format.html do
          if redirect
            redirect_to org_queue_path, alert: message
          else
            head status
          end
        end
      end
    end
  end
end
