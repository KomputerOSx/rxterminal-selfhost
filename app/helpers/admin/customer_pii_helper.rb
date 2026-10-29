# frozen_string_literal: true

module Admin
  module CustomerPiiHelper
    def customer_pii_organization_owner_emails(organization)
      organization.memberships.filter_map do |membership|
        next unless membership.membership_roles.any? { |membership_role|
          membership_role.role.scope == "app" && membership_role.role.name == Role::APP_OWNER
        }

        membership.user.email
      end.join(", ").presence || "-"
    end

    def customer_pii_organization_address(organization)
      organization.full_address.presence || "-"
    end
  end
end
