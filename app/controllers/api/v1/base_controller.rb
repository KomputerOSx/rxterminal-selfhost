# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      allow_unauthenticated_access
      skip_before_action :verify_authenticity_token

      protect_from_forgery with: :null_session
    end
  end
end
