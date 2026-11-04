# frozen_string_literal: true

class SitemapsController < ApplicationController
  layout false

  allow_unauthenticated_access
  skip_before_action :enforce_onboarding_gate!
  skip_before_action :enforce_maintenance_mode!

  def show
    @urls = primary_domain_urls

    render layout: false
  end

  private

  def info_page_urls(organization, base_url)
    base_url = "#{base_url.delete_suffix("/")}/"
    urls = []
    urls << { loc: "#{base_url}opening-times", changefreq: "monthly" } if organization.portal_opening_times_enabled?
    urls << { loc: "#{base_url}contact", changefreq: "monthly" } if organization.portal_contact_page_enabled?
    urls
  end

  def primary_domain_urls
    marketing_urls = [
      { loc: legal_privacy_policy_url, changefreq: "yearly" },
      { loc: legal_terms_url, changefreq: "yearly" },
      { loc: legal_gdpr_url, changefreq: "yearly" },
      { loc: legal_cookies_url, changefreq: "yearly" }
    ]

    portal_urls = Organization.find_each.select(&:public_portal_enabled?).flat_map do |organization|
      root = portal_root_url(organization_slug: organization.slug)
      [ { loc: root, changefreq: "weekly" }, *info_page_urls(organization, root) ]
    end

    marketing_urls + portal_urls
  end
end
