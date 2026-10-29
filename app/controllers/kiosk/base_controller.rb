# frozen_string_literal: true

module Kiosk
  class BaseController < ApplicationController
    include KioskPreviewMode

    layout "kiosk"

    allow_unauthenticated_access
  end
end
