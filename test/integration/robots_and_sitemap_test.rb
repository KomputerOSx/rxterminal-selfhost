require "test_helper"

class RobotsAndSitemapTest < ActionDispatch::IntegrationTest
  setup do
    @plain_organization = Organization.create_personal_for!(users(:one))
    @custom_domain_organization = Organization.create_personal_for!(users(:two))
    with_active_subscription(@custom_domain_organization, Billing::Plans::BUSINESS) do
      @custom_domain_organization.update!(custom_domain: "shop.acme.test")
    end
    FeatureRegistry.sync!
    Feature.find_by!(key: "public_portal").update!(enabled: true, applies_to_all_organizations: true)
  end

  test "robots.txt on the primary host disallows internal areas and points to the primary sitemap" do
    get "/robots.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match "Disallow: /admin/", response.body
    assert_match "Disallow: /org/", response.body
    assert_match "Allow: /", response.body
    assert_match "Sitemap: http://www.example.com/sitemap.xml", response.body
  end

  test "robots.txt on a custom domain allows everything and points to that domain's sitemap" do
    host! "shop.acme.test"

    get "/robots.txt"

    assert_response :success
    assert_no_match "Disallow:", response.body
    assert_match "Allow: /", response.body
    assert_match "Sitemap: http://shop.acme.test/sitemap.xml", response.body
  end

  test "sitemap.xml on the primary host lists marketing pages and organizations without a custom domain" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match "http://www.example.com/", response.body
    assert_match "http://www.example.com/pricing", response.body
    assert_match "http://www.example.com/#{@plain_organization.slug}", response.body
    assert_no_match "shop.acme.test", response.body
  end

  test "sitemap.xml on a custom domain lists only that organization's own pages" do
    host! "shop.acme.test"

    get "/sitemap.xml"

    assert_response :success
    assert_match "http://shop.acme.test/", response.body
    assert_match "http://shop.acme.test/privacy-policy", response.body
    assert_no_match "/pricing", response.body
    assert_no_match @plain_organization.slug, response.body
  end

  test "sitemap.xml leaves out organizations whose portal is disabled" do
    Feature.find_by!(key: "public_portal").update!(enabled: false)

    get "/sitemap.xml"

    assert_response :success
    assert_no_match @plain_organization.slug, response.body

    host! "shop.acme.test"
    get "/sitemap.xml"

    assert_response :success
    assert_no_match "http://shop.acme.test/", response.body
  end

  test "sitemap.xml lists enabled info pages" do
    %w[portal_opening_times portal_contact_page].each do |key|
      Feature.find_by!(key: key).update!(enabled: true, applies_to_all_organizations: true)
    end
    @plain_organization.update_feature!(:portal_opening_times, enabled: true)
    @custom_domain_organization.update_feature!(:portal_contact_page, enabled: true)

    get "/sitemap.xml"
    assert_match "http://www.example.com/#{@plain_organization.slug}/opening-times", response.body
    assert_no_match "http://www.example.com/#{@plain_organization.slug}/contact", response.body

    host! "shop.acme.test"
    get "/sitemap.xml"
    assert_match "http://shop.acme.test/contact", response.body
    assert_no_match "opening-times", response.body
  end

  test "sitemap.xml.gz 404s instead of raising a missing template error" do
    get "/sitemap.xml.gz"

    assert_response :not_found
  end
end
