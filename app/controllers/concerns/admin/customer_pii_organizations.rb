# frozen_string_literal: true

module Admin
  module CustomerPiiOrganizations
    extend ActiveSupport::Concern

    included do
      helper Admin::CustomerPiiHelper
    end

    private

    def load_customer_pii_organizations
      @organizations = Organization.order(:name).includes(memberships: [ :user, { membership_roles: :role } ])
    end
  end
end
