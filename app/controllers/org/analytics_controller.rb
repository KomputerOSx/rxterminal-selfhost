# frozen_string_literal: true

module Org
  class AnalyticsController < BaseController
    include AnalyticsHelper

    # Time.current (not Date.current) so the range bounds are full timestamps -
    # a Date range's end bound has no time component and excludes same-day
    # rows created after midnight when compared against a datetime column.
    PERIODS = {
      "today" => -> { Time.current.all_day },
      "this_week" => -> { Time.current.all_week },
      "this_month" => -> { Time.current.all_month },
      "last_month" => -> { 1.month.ago.all_month },
      "all_time" => -> { nil }
    }.freeze

    before_action :authorize_view

    def index
      @period = params[:period].presence_in(PERIODS.keys) || "this_month"
      range = PERIODS[@period].call

      requests = Current.organization.service_requests
      requests = requests.where(created_at: range) if range

      @total = requests.count
      @completed = requests.where(status: "completed").count
      @cancelled = requests.where(status: "cancelled").count
      @completion_rate = @total.positive? ? ((@completed.to_f / @total) * 100).round : 0

      @immediate_count = requests.where(request_type: "immediate").count
      @appointment_count = requests.where(request_type: "appointment").count

      service_names = Current.organization.services.pluck(:id, :display_name).to_h
      @by_service = requests.group(:service_id).count
        .map { |service_id, count| { name: service_names[service_id] || "Unknown", count: count } }
        .sort_by { |row| -row[:count] }

      timestamps = requests.pluck(:created_at)
      by_day_of_week = timestamps.group_by(&:wday).transform_values(&:count).sort
      hour_counts = Array.new(24, 0)
      heatmap = Array.new(7) { Array.new(24, 0) }
      timestamps.each do |timestamp|
        zoned = timestamp.in_time_zone
        hour = zoned.hour
        hour_counts[hour] += 1
        heatmap[zoned.wday][hour] += 1
      end
      @heatmap_max = heatmap.flatten.max

      @service_chart = analytics_service_chart(@by_service)
      @type_chart = analytics_type_chart(@immediate_count, @appointment_count)
      @day_chart = analytics_day_chart(by_day_of_week)
      @hour_chart = analytics_hour_chart(hour_counts)
      @heatmap = heatmap
    end

    private

    def authorize_view
      authorize Current.organization, :show?, policy_class: AnalyticsPolicy
    end
  end
end
