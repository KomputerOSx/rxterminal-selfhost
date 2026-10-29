class AddBusinessTypeToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :business_type, :string
  end
end
