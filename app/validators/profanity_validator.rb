# frozen_string_literal: true

class ProfanityValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    record.errors.add(attribute, options[:message] || "contains language that isn't allowed") if ProfanityFilter.match?(value)
  end
end
