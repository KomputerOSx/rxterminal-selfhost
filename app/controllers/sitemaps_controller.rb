# frozen_string_literal: true

class SitemapsController < ApplicationController
  layout false

  allow_unauthenticated_access
  skip_before_action :enforce_onboarding_gate!
  skip_before_action :enforce_maintenance_mode!

  def show
    @urls = custom_domain_organization ? custom_domain_urls : primary_domain_urls

    render layout: false
  end

  private

  # On a tenant's custom domain, every route (including this one) resolves the
  # organization from the host - see CustomDomainConstraint / CustomDomainResolver.
  def custom_domain_organization
    return @custom_domain_organization if defined?(@custom_domain_organization)

    organization_id = request.env[CustomDomainResolver::ENV_KEY]
    @custom_domain_organization = organization_id && Organization.find_by(id: organization_id)
  end

  # url_for helpers default to the current request's host, so the same route
  # names resolve to this organization's own domain here.
  def custom_domain_urls
    return [] unless custom_domain_organization.public_portal_enabled?

    [
      { loc: root_url, changefreq: "weekly" },
      *info_page_urls(custom_domain_organization, root_url),
      { loc: legal_privacy_policy_url, changefreq: "yearly" },
      { loc: legal_terms_url, changefreq: "yearly" },
      { loc: legal_gdpr_url, changefreq: "yearly" },
      { loc: legal_cookies_url, changefreq: "yearly" }
    ]
  end

  def info_page_urls(organization, base_url)
    base_url = "#{base_url.delete_suffix("/")}/"
    urls = []
    urls << { loc: "#{base_url}opening-times", changefreq: "monthly" } if organization.portal_opening_times_enabled?
    urls << { loc: "#{base_url}contact", changefreq: "monthly" } if organization.portal_contact_page_enabled?
    urls
  end

  def primary_domain_urls
    marketing_urls = [
      { loc: root_url, changefreq: "weekly" },
      { loc: pricing_url, changefreq: "monthly" },
      { loc: contact_url, changefreq: "monthly" },
      { loc: legal_privacy_policy_url, changefreq: "yearly" },
      { loc: legal_terms_url, changefreq: "yearly" },
      { loc: legal_gdpr_url, changefreq: "yearly" },
      { loc: legal_cookies_url, changefreq: "yearly" }
    ]

    # Organizations with a verified custom domain are listed under their own
    # domain's sitemap instead, to avoid indexing the same portal twice.
    portal_urls = Organization.where(custom_domain: nil).find_each.select(&:public_portal_enabled?).flat_map do |organization|
      root = portal_root_url(organization_slug: organization.slug)
      [ { loc: root, changefreq: "weekly" }, *info_page_urls(organization, root) ]
    end

    marketing_urls + portal_urls
  end
end
