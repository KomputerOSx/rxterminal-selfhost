# frozen_string_literal: true

require "fuzzy_match"

module Kiosk
  class ServicesController < BaseController
    include KioskAuthentication

    def index
      @services = @organization.services.visible.active.featured_first
    end

    def choose
      @service = @organization.services.visible.active.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to kiosk_services_path, alert: "Service not found."
    end

    def search
      all_services = @organization.services.visible.active.to_a
      @query = params[:q].to_s.strip

      @results = if @query.present?
        matcher = FuzzyMatch.new(all_services, read: :display_name)
        matcher.find_all(@query).presence || fuzzy_fallback(all_services, @query)
      else
        []
      end
    end

    private

    def fuzzy_fallback(services, query)
      words = query.downcase.split
      services.select { |s| words.any? { |w| s.display_name.downcase.include?(w) } }
    end
  end
end
