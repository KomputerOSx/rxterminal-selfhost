# frozen_string_literal: true

module AuditLogsHelper
  FILTER_DATETIME_FORMAT = "%Y-%m-%dT%H:%M"

  def audit_log_organization_label(log)
    organization = log.resolved_organization
    return "-" unless organization || log.resolved_organization_id

    if organization
      organization.slug
    else
      "##{log.resolved_organization_id}"
    end
  end

  def audit_log_organization_id_label(log)
    log.resolved_organization_id || "-"
  end

  def audit_log_filter_datetime(time)
    time.in_time_zone.strftime(FILTER_DATETIME_FORMAT)
  end

  def audit_log_retention_cutoff(max_retention_days)
    max_retention_days.days.ago
  end

  def audit_log_quick_ranges(max_retention_days: nil)
    now = Time.current
    ranges = [
      [ "Last hour", 1.hour.ago, now ],
      [ "Last 24h", 24.hours.ago, now ],
      [ "Last 7 days", 7.days.ago, now ],
      [ "Last 30 days", 30.days.ago, now ]
    ]

    if max_retention_days
      cutoff = audit_log_retention_cutoff(max_retention_days)
      ranges.select! { |_, from, _| from >= cutoff }
    end

    ranges.map do |label, from, to|
      [ label, audit_log_filter_datetime(from), audit_log_filter_datetime(to) ]
    end + [
      [ "Today", audit_log_filter_datetime(Date.current.beginning_of_day), audit_log_filter_datetime(Date.current.end_of_day) ]
    ]
  end

  def audit_log_filter_datetime_value(value)
    return if value.blank?

    normalized = value.to_s.sub(/\A(\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2})\s+\d{2}:\d{2}\z/, '\1')
    Time.zone.parse(normalized)&.strftime(FILTER_DATETIME_FORMAT)
  rescue ArgumentError, TypeError
    nil
  end

  def audit_log_resource_filter_params(log, query_parameters)
    query_parameters
      .except("page", "page")
      .merge(resource_type: log.resource_type, resource_id: log.resource_id)
  end

  def audit_log_time_ago(time)
    return "-" if time.blank?

    time = time.to_time.in_time_zone
    now = Time.current
    elapsed_seconds = (now - time).floor

    return "just now" if elapsed_seconds < 60

    minutes = elapsed_seconds / 60
    if minutes < 60
      return "#{minutes} #{"minute".pluralize(minutes)} ago"
    end

    hours = minutes / 60
    if hours < 24
      remaining_minutes = minutes % 60
      parts = [ "#{hours} #{"hour".pluralize(hours)}" ]
      parts << "#{remaining_minutes} #{"minute".pluralize(remaining_minutes)}" if remaining_minutes.positive?
      return "#{parts.join(" ")} ago"
    end

    days = (now.to_date - time.to_date).to_i
    return "yesterday" if days == 1
    return "#{days} days ago" if days < 7

    weeks = days / 7
    return "#{weeks} #{"week".pluralize(weeks)} ago" if days < 30

    months = calendar_months_between(time, now)
    return "#{months} #{"month".pluralize(months)} ago" if months < 12

    years = months / 12
    remaining_months = months % 12
    if remaining_months.zero?
      "#{years} #{"year".pluralize(years)} ago"
    else
      "#{years} #{"year".pluralize(years)} #{remaining_months} #{"month".pluralize(remaining_months)} ago"
    end
  end

  private

  def calendar_months_between(from_time, to_time)
    months = (to_time.year * 12 + to_time.month) - (from_time.year * 12 + from_time.month)
    months -= 1 if to_time.day < from_time.day
    [ months, 1 ].max
  end
end
