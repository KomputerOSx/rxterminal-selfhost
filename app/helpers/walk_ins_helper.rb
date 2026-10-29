# frozen_string_literal: true

module WalkInsHelper
  POSTCODE_LABELS = {
    "uk" => "Postcode",
    "us" => "ZIP Code",
    "ca" => "Postal Code",
    "au" => "Postcode"
  }.freeze

  POSTCODE_EXAMPLES = {
    "uk" => "e.g. SW1A 1AA",
    "us" => "e.g. 90210",
    "ca" => "e.g. M5V 2T6",
    "au" => "e.g. 2000"
  }.freeze

  def walk_in_postcode_label(organization)
    POSTCODE_LABELS.fetch(organization.postcode_region, "Postcode")
  end

  def walk_in_postcode_example(organization)
    POSTCODE_EXAMPLES.fetch(organization.postcode_region, "Postcode")
  end

  def walk_in_services_json(services)
    services.map { |service|
      {
        id: service.id,
        eligibility: service.eligibility_requirements,
        has_eligibility: service.eligibility_requirements?,
        allows_private: service.allows_private_consultation
      }
    }.to_json
  end
end
