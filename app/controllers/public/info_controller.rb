# frozen_string_literal: true

module Public
  class InfoController < BaseController
    skip_before_action :require_privacy_accepted
    before_action -> { render_not_found unless @organization.portal_opening_times_enabled? }, only: :opening_times
    before_action -> { render_not_found unless @organization.portal_contact_page_enabled? }, only: :contact

    def opening_times
      @today = Time.current.strftime("%A").downcase
    end

    def contact
    end

    private

    def portal_indexable?
      true
    end

    def render_not_found
      render "public/errors/not_found", status: :not_found, layout: false
    end
  end
end
