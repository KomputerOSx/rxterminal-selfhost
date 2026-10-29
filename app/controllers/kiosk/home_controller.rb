# frozen_string_literal: true

module Kiosk
  class HomeController < BaseController
    include KioskAuthentication

    def index
      @featured_service = if @organization.kiosk_show_featured_service? && @organization.kiosk_featured_service_id.present?
        @organization.services.visible.active.find_by(id: @organization.kiosk_featured_service_id)
      end
    end
  end
end
