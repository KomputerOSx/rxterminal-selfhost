# frozen_string_literal: true

class PublicHolidayImporter
  REGIONS = {
    "England and Wales" => "gb_eng",
    "Scotland" => "gb_sct",
    "Northern Ireland" => "gb_nir",
    "Ireland" => "ie",
    "United States" => "us",
    "Canada" => "ca",
    "Australia" => "au",
    "New Zealand" => "nz",
    "Germany" => "de",
    "France" => "fr",
    "Spain" => "es",
    "Italy" => "it",
    "Netherlands" => "nl",
    "Portugal" => "pt",
    "Sweden" => "se",
    "Norway" => "no",
    "Denmark" => "dk",
    "Poland" => "pl",
    "India" => "in",
    "South Africa" => "za"
  }.freeze
  LOOKAHEAD = 12.months

  Result = Struct.new(:created, :skipped, keyword_init: true)

  def self.region_label(code)
    REGIONS.key(code)
  end

  def initialize(organization, region:, calendar_ids: [], from: Date.current, to: nil)
    @organization = organization
    @region = region.to_s
    @calendar_ids = Array(calendar_ids).map(&:to_i).uniq
    @from = from
    @to = to || from + LOOKAHEAD
  end

  def valid_region?
    REGIONS.value?(@region)
  end

  def valid_calendars?
    @calendar_ids.empty? || @organization.calendars.where(id: @calendar_ids).count == @calendar_ids.size
  end

  def holidays
    Holidays.between(@from, @to, @region.to_sym, :observed)
      .uniq { |holiday| holiday[:date] }
      .sort_by { |holiday| holiday[:date] }
  end

  def call
    raise ArgumentError, "Unknown region #{@region}" unless valid_region?
    raise ArgumentError, "Unknown calendar" unless valid_calendars?

    created = 0
    skipped = 0
    AppointmentBlockedDate.transaction do
      holidays.each do |holiday|
        if already_blocked?(holiday[:date])
          skipped += 1
          next
        end

        block = @organization.appointment_blocked_dates.new(
          start_date: holiday[:date],
          end_date: holiday[:date],
          reason: holiday[:name],
          source: "imported"
        )
        block.assign_calendars(scope: @calendar_ids.any? ? "selected" : "all", ids: @calendar_ids)
        block.save!
        created += 1
      end
    end
    Result.new(created: created, skipped: skipped)
  end

  private

  def already_blocked?(date)
    covering = @organization.appointment_blocked_dates.covering(date).includes(:calendars).to_a
    return true if covering.any?(&:all_calendars?)
    return false if @calendar_ids.empty?

    covered_ids = covering.flat_map(&:calendar_ids)
    (@calendar_ids - covered_ids).empty?
  end
end
