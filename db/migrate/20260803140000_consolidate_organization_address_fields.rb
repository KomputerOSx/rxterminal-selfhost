# frozen_string_literal: true

class ConsolidateOrganizationAddressFields < ActiveRecord::Migration[8.1]
  def change
    rename_column :organizations, :facility_address_line1, :address_line1
    rename_column :organizations, :facility_address_line2, :address_line2
    rename_column :organizations, :facility_address_city, :address_city
    rename_column :organizations, :facility_address_state, :address_state
    rename_column :organizations, :facility_address_postal_code, :address_postal_code
    rename_column :organizations, :facility_address_country, :address_country
    rename_column :organizations, :facility_latitude, :latitude
    rename_column :organizations, :facility_longitude, :longitude
    rename_column :organizations, :facility_geofence_radius_meters, :geofence_radius_meters
    rename_column :organizations, :facility_geocoded_at, :geocoded_at

    remove_column :organizations, :contact_address, :text
  end
end
