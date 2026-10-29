# frozen_string_literal: true

class AddContactDetailsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :contact_address, :text
    add_column :organizations, :contact_email, :string
    add_column :organizations, :contact_phone, :string
  end
end
