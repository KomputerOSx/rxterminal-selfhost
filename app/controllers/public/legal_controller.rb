# frozen_string_literal: true

module Public
  class LegalController < BaseController
    skip_before_action :require_privacy_accepted

    def privacy_policy
    end

    def gdpr
    end

    def terms
    end

    def cookies_policy
    end

    private

    def portal_indexable?
      true
    end
  end
end
