# frozen_string_literal: true

module AnalyticsHelper
  CHART_COLORS = {
    primary: "primary",
    success: "success",
    warning: "warning",
    info: "info",
    error: "error",
    walk_in: "warning",
    appointment: "info",
    day: "accent",
    hour: "warning"
  }.freeze

  ANALYTICS_PERIODS = [
    [ "Today", "today" ],
    [ "This week", "this_week" ],
    [ "This month", "this_month" ],
    [ "Last month", "last_month" ],
    [ "All time", "all_time" ]
  ].freeze

  def analytics_service_chart(by_service)
    {
      labels: by_service.map { |row| row[:name] },
      datasets: [
        {
          label: "Requests",
          backgroundColor: CHART_COLORS[:primary],
          data: by_service.map { |row| row[:count] }
        }
      ]
    }
  end

  def analytics_type_chart(immediate_count, appointment_count)
    {
      labels: [ "Walk-in", "Appointment" ],
      datasets: [
        {
          label: "Requests",
          backgroundColor: [ CHART_COLORS[:walk_in], CHART_COLORS[:appointment] ],
          data: [ immediate_count, appointment_count ]
        }
      ]
    }
  end

  def analytics_day_chart(by_day_of_week)
    day_names = %w[Sun Mon Tue Wed Thu Fri Sat]
    {
      labels: by_day_of_week.map { |dow, _| day_names[dow] },
      datasets: [
        {
          label: "Requests",
          backgroundColor: CHART_COLORS[:day],
          data: by_day_of_week.map { |_, count| count }
        }
      ]
    }
  end

  def analytics_hour_chart(hour_counts)
    {
      labels: (0..23).map { |hour| "#{hour}h" },
      datasets: [
        {
          label: "Requests",
          backgroundColor: CHART_COLORS[:hour],
          data: hour_counts
        }
      ]
    }
  end

  HEATMAP_DAY_LABELS = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

  def heatmap_cell_class(count, max)
    return "bg-base-200/30" if count.zero? || max.zero?

    ratio = count.to_f / max
    case ratio
    when 0.75.. then "bg-primary/80"
    when 0.5...0.75 then "bg-primary/60"
    when 0.25...0.5 then "bg-primary/40"
    else "bg-primary/20"
    end
  end
end
