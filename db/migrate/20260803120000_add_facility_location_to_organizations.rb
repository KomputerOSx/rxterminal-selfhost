# frozen_string_literal: true

class AddFacilityLocationToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :facility_address_line1, :string
    add_column :organizations, :facility_address_line2, :string
    add_column :organizations, :facility_address_city, :string
    add_column :organizations, :facility_address_state, :string
    add_column :organizations, :facility_address_postal_code, :string
    add_column :organizations, :facility_address_country, :string
    add_column :organizations, :facility_latitude, :decimal, precision: 10, scale: 6
    add_column :organizations, :facility_longitude, :decimal, precision: 10, scale: 6
    add_column :organizations, :facility_geofence_radius_meters, :integer, default: 150, null: false
    add_column :organizations, :facility_geocoded_at, :datetime
  end
end
