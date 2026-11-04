# frozen_string_literal: true

module Public
  class BaseController < ApplicationController
    include Public::PortalPathsHelper

    allow_unauthenticated_access
    layout "public"

    helper Public::PortalPathsHelper
    helper Public::AppointmentsHelper
    helper Public::PortalHelper
    helper Public::PortalSeoHelper
    helper_method :portal_indexable?

    before_action :load_and_verify_organization
    around_action :use_organization_time_zone
    before_action :require_privacy_accepted

    private

    def portal_indexable?
      false
    end

    def load_and_verify_organization
      @organization = params[:organization_slug] ? Organization.find_by(slug: params[:organization_slug]) : Organization.primary

      unless @organization&.public_portal_enabled?
        # At the site root there is nothing to show for visitors until the portal is switched on.
        return redirect_to(login_path) unless params[:organization_slug]

        render "public/errors/not_found", status: :not_found, layout: false
      end
    end

    # So "today"-driven slot availability/queue logic reflects the organization's own
    # local day, not the server's - see Org::BaseController for the staff-side equivalent.
    def use_organization_time_zone(&block)
      return yield unless @organization

      Time.use_zone(@organization.time_zone, &block)
    end

    def require_privacy_accepted
      return if session[:public_privacy_accepted]

      session[:public_privacy_return_to] = request.fullpath
      redirect_to portal_privacy_path
    end
  end
end
