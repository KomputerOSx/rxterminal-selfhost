# frozen_string_literal: true

module AppointmentsHelper
  APPOINTMENT_STATUS_LABELS = {
    "booked" => "Booked",
    "checked_in" => "Checked in",
    "cancelled" => "Cancelled",
    "no_show" => "No-show"
  }.freeze

  APPOINTMENT_STATUS_COLORS = {
    "booked" => "text-success",
    "checked_in" => "text-info",
    "cancelled" => "text-error",
    "no_show" => "text-warning"
  }.freeze

  def appointment_status_badge(appointment)
    case appointment.status
    when "booked"
      content_tag(:span, "Booked", class: "badge badge-success badge-sm")
    when "checked_in"
      content_tag(:span, "Checked in", class: "badge badge-info badge-sm")
    when "cancelled"
      content_tag(:span, "Cancelled", class: "badge badge-error badge-sm")
    when "no_show"
      content_tag(:span, "No-show", class: "badge badge-warning badge-sm")
    else
      content_tag(:span, appointment.status.humanize, class: "badge badge-ghost badge-sm")
    end
  end

  def appointment_customer_name(appointment)
    [ appointment.first_name, appointment.last_name ].compact.join(" ")
  end

  def appointment_time_value(appointment)
    appointment.appointment_time&.strftime("%H:%M")
  end

  def appointment_date_value(appointment)
    appointment.appointment_date&.iso8601
  end

  def appointment_manage_actions?(appointment)
    current_user.has_permission?("app.appointments.manage", organization: Current.organization) &&
      appointment.editable_by_staff?
  end

  def appointment_status_label(status)
    APPOINTMENT_STATUS_LABELS.fetch(status, status.humanize)
  end

  def appointment_status_color(status)
    APPOINTMENT_STATUS_COLORS.fetch(status, "text-base-content/70")
  end

  def appointment_calendar_path(**overrides)
    org_appointments_path({
      view: @view,
      date: @date.iso8601,
      calendar_id: @calendar&.id
    }.merge(overrides).compact)
  end

  def appointment_calendar_return_params
    return {} unless @view && @date

    { view: @view, date: @date.iso8601, calendar_id: @calendar&.id }.compact
  end

  def appointment_calendar_step(view, date, direction)
    case view
    when "week" then date + (7 * direction).days
    when "month" then date.beginning_of_month + direction.months
    else date + direction.days
    end
  end

  def appointment_calendar_period_label(view, period)
    case view
    when "week"
      first, last = period.first, period.last
      if first.year != last.year
        "#{first.strftime('%-d %b %Y')} - #{last.strftime('%-d %b %Y')}"
      elsif first.month != last.month
        "#{first.strftime('%-d %b')} - #{last.strftime('%-d %b %Y')}"
      else
        "#{first.day} - #{last.strftime('%-d %b %Y')}"
      end
    when "month"
      period.first.strftime("%B %Y")
    else
      period.first.strftime("%A, %-d %B %Y")
    end
  end

  def appointment_status_counts(appointments)
    counts = Appointment::STATUSES.index_with(0)
    appointments.each { |appointment| counts[appointment.status] += 1 }
    counts
  end

  def appointment_inactive?(appointment)
    appointment.status.in?(%w[cancelled no_show])
  end
end
