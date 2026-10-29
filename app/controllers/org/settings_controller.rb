# frozen_string_literal: true

module Org
  class SettingsController < BaseController
    def index
      skip_authorization
    end
  end
end
