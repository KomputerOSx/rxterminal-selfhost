# frozen_string_literal: true

# Static catalog of the per-organization feature switches, loaded from config/features.yml.
# Each organization stores its own on/off choices in organizations.features (see
# FeatureToggleable); features without org_opt_in_required are always on.
OrgFeature = Data.define(:key, :name, :description, :org_opt_in_required) do
  alias_method :org_opt_in_required?, :org_opt_in_required

  def self.all
    @all ||= YAML.load_file(Rails.root.join("config/features.yml")).map do |key, attrs|
      new(key: key, name: attrs.fetch("name"), description: attrs["description"],
          org_opt_in_required: attrs.fetch("org_opt_in_required", true))
    end.freeze
  end

  def self.find(key)
    all.find { |feature| feature.key == key.to_s }
  end

  def self.keys
    all.map(&:key)
  end
end
