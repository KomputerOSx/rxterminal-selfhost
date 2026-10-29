class AddOrganizationLogosManagePermission < ActiveRecord::Migration[8.1]
  class Permission < ActiveRecord::Base; end
  class Role < ActiveRecord::Base; end
  class RolePermission < ActiveRecord::Base; end

  # See 20260712020001_add_demote_owner_permission.rb - RbacRegistry only attaches baseline
  # permissions to a role at the moment that role is first created, so an existing `system_admin`
  # role needs this new permission attached explicitly (docs/rbac.md #13-14).
  def up
    permission = Permission.find_or_create_by!(key: "system.organization_logos.manage") do |p|
      p.description = "Review and approve/decline organization logo uploads"
    end

    Role.where(scope: "system", name: "system_admin").find_each do |system_admin_role|
      RolePermission.find_or_create_by!(role_id: system_admin_role.id, permission_id: permission.id)
    end
  end

  def down
    permission = Permission.find_by(key: "system.organization_logos.manage")
    return unless permission

    RolePermission.where(permission_id: permission.id).delete_all
    permission.destroy
  end
end
