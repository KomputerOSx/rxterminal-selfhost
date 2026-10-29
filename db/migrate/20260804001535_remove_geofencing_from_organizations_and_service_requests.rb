# frozen_string_literal: true

class RemoveGeofencingFromOrganizationsAndServiceRequests < ActiveRecord::Migration[8.1]
  def change
    remove_column :organizations, :latitude, :decimal, precision: 10, scale: 6
    remove_column :organizations, :longitude, :decimal, precision: 10, scale: 6
    remove_column :organizations, :geofence_radius_meters, :integer, default: 150, null: false
    remove_column :organizations, :geocoded_at, :datetime

    remove_column :service_requests, :submission_latitude, :decimal, precision: 10, scale: 6
    remove_column :service_requests, :submission_longitude, :decimal, precision: 10, scale: 6
    remove_column :service_requests, :submission_distance_meters, :integer
  end
end
