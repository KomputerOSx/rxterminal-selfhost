class AddSlugChangedAtToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :slug_changed_at, :datetime
  end
end
