# frozen_string_literal: true

class DateOfBirthParser
  FORMATS = [
    "%d-%m-%Y",
    "%d/%m/%Y",
    "%Y-%m-%d"
  ].freeze

  def self.parse(value)
    return value if value.is_a?(Date)
    return if value.blank?

    string = value.to_s.strip
    FORMATS.each do |format|
      return Date.strptime(string, format)
    rescue ArgumentError, Date::Error
      next
    end

    nil
  end
end
