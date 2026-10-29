# frozen_string_literal: true

module Admin
  class CustomerPiiSearch
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :first_name, :string
    attribute :last_name, :string
    attribute :display_dob, :string
    attribute :postcode, :string

    validates :first_name, :last_name, presence: true
    validates :organization_ids, presence: {
      message: "must include at least one organization when no date of birth is given"
    }, if: -> { display_dob.blank? }
    validate :dob_format, if: -> { display_dob.present? }

    def initialize(attributes = {})
      @organization_ids = []
      super
    end

    def organization_ids
      @organization_ids
    end

    def organization_ids=(value)
      @organization_ids = Array(value).filter_map { |id| id.presence&.to_i }.uniq
    end

    def parsed_dob
      return @parsed_dob if defined?(@parsed_dob)

      @parsed_dob = DateOfBirthParser.parse(display_dob)
    end

    def lookup
      CustomerPiiLookup.new(
        organization_ids: organization_ids,
        first_name: first_name,
        last_name: last_name,
        dob: parsed_dob,
        postcode: postcode
      ).call
    end

    private

    def dob_format
      return if display_dob.blank?
      return if parsed_dob.present?

      errors.add(:display_dob, "Enter a valid date")
    end
  end
end
