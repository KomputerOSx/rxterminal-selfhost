# frozen_string_literal: true

class CustomerPiiMatcher
  def self.normalize_name(value)
    value.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def self.normalize_postcode(value)
    normalize_name(value).gsub(/\s+/, "")
  end

  def self.postcode_match?(record_postcode, query_postcode)
    return true if query_postcode.blank?

    normalize_postcode(record_postcode) == normalize_postcode(query_postcode)
  end

  def self.names_match?(record_first, record_last, query_first, query_last)
    normalize_name(record_first) == normalize_name(query_first) &&
      normalize_name(record_last) == normalize_name(query_last)
  end

  def self.dob_match?(record_dob, query_dob)
    return true if query_dob.blank?

    parsed = record_dob
    parsed = Date.parse(parsed.to_s) if parsed.is_a?(String)
    parsed.is_a?(Date) && parsed == query_dob
  rescue ArgumentError, Date::Error
    false
  end
end
