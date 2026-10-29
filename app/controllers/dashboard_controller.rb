class DashboardController < ApplicationController
  def index
    return unless Current.organization

    org = Current.organization

    @waiting_count = org.service_requests.where(status: "waiting").count
    @in_progress_count = org.service_requests.where(status: "in_progress").count
    @completed_today_count = org.service_requests.today.where(status: "completed").count
    @cancelled_today_count = org.service_requests.today.where(status: "cancelled").count

    @today_appointments_count = org.appointments.where(appointment_date: Date.current).count
    @average_wait_minutes = ServiceRequest.average_wait_minutes(org.id)
    @active_services_count = org.services.visible.active.count

    if current_user.has_permission?("app.upsells.manage", organization: org)
      todays_counters = UpsellCounter.where(organization: org, date: Date.current)
      @upsell_conversions_today = todays_counters.sum(:conversion_count)
      @upsell_revenue_today = todays_counters.sum(:estimated_revenue)
    end

    if current_user.has_permission?("app.analytics.view", organization: org)
      @week_chart = weekly_requests_chart(org)
    end
  end

  private

  def weekly_requests_chart(org)
    range_start = 6.days.ago.to_date
    timestamps = org.service_requests.where(created_at: range_start.all_day.begin..Time.current).pluck(:created_at)
    counts_by_date = timestamps.group_by { |timestamp| timestamp.in_time_zone.to_date }.transform_values(&:count)
    dates = (range_start..Date.current).to_a

    {
      labels: dates.map { |date| date.strftime("%a") },
      datasets: [
        {
          label: "Requests",
          backgroundColor: "primary",
          data: dates.map { |date| counts_by_date[date] || 0 }
        }
      ]
    }
  end
end
