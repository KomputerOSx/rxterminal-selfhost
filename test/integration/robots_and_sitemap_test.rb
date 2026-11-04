require "test_helper"

class RobotsAndSitemapTest < ActionDispatch::IntegrationTest
  setup do
    @plain_organization = Organization.create_personal_for!(users(:one))
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

  test "sitemap.xml on the primary host lists marketing pages and organizations" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match "http://www.example.com/", response.body
    assert_match "http://www.example.com/#{@plain_organization.slug}", response.body
  end

  test "sitemap.xml lists enabled info pages" do
    %w[portal_opening_times portal_contact_page].each do |key|
    end
    @plain_organization.update_feature!(:portal_opening_times, enabled: true)

    get "/sitemap.xml"
    assert_match "http://www.example.com/#{@plain_organization.slug}/opening-times", response.body
    assert_no_match "http://www.example.com/#{@plain_organization.slug}/contact", response.body
  end

  test "sitemap.xml.gz 404s instead of raising a missing template error" do
    get "/sitemap.xml.gz"

    assert_response :not_found
  end
end
