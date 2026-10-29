# frozen_string_literal: true

class AddGeolocationAuditToServiceRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :service_requests, :submission_latitude, :decimal, precision: 10, scale: 6
    add_column :service_requests, :submission_longitude, :decimal, precision: 10, scale: 6
    add_column :service_requests, :submission_distance_meters, :integer
    add_column :service_requests, :submission_ip, :string
  end
end
