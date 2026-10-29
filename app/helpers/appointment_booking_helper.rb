# frozen_string_literal: true

module AppointmentBookingHelper
  BOOKING_TABLE_PER_PAGE = 10
  BOOKING_TABLE_PAGE_PARAMS = %w[openings_page blocked_dates_page].freeze

  def booking_table_page(scope, param_name)
    records = scope.page(request.query_parameters[param_name.to_s]).per(BOOKING_TABLE_PER_PAGE)
    return records unless records.out_of_range? && records.total_pages.positive?

    scope.page(records.total_pages).per(BOOKING_TABLE_PER_PAGE)
  end

  def booking_table_page_path(param_name, page)
    org_appointment_booking_path(request.query_parameters.slice(*BOOKING_TABLE_PAGE_PARAMS).merge(param_name.to_s => page))
  end
  def booking_date_label(date)
    date.strftime("%a %-d %b %Y")
  end

  def blocked_date_range_label(blocked_date)
    return booking_date_label(blocked_date.start_date) if blocked_date.single_day?

    "#{booking_date_label(blocked_date.start_date)} to #{booking_date_label(blocked_date.end_date)}"
  end

  def booking_calendars_for(organization, record = nil)
    assigned = record ? record.calendars.to_a : []
    (organization.calendars.active.ordered.to_a + assigned.select(&:archived?)).uniq
  end

  def show_calendar_scope_field?(organization, record = nil)
    organization.calendars.active.count > 1 || (record && record.calendars.any?(&:archived?))
  end

  def opening_days_label(opening)
    opening.bookable_days.map { |day| day.capitalize.first(3) }.join(", ")
  end

  def holiday_region_options
    PublicHolidayImporter::REGIONS.to_a
  end
end
