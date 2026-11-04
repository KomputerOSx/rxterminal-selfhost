require "test_helper"

class LegalPagesTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create_personal_for!(users(:one))
    @organization.update!(name: "High Street Pharmacy", contact_email: "hello@highstreet.test")
  end

  test "legal pages at the site root use the public portal layout and the organization's details" do
    [
      [ legal_terms_path, "Terms of Use" ],
      [ legal_privacy_policy_path, "Privacy Policy" ],
      [ legal_cookies_path, "Cookies Policy" ],
      [ legal_gdpr_path, "Data Protection Statement" ]
    ].each do |path, heading|
      get path

      assert_response :success
      assert_select "h1", text: heading
      assert_select "title", text: "#{heading} - High Street Pharmacy"
      assert_match "High Street Pharmacy", response.body
      assert_match "hello@highstreet.test", response.body
      assert_no_match(/strixon|{{|}}/i, response.body)
      # Same chrome as the rest of the portal: its footer links, not the old marketing layout.
      assert_select "footer a[href=?]", "/privacy-policy"
      assert_select "a", text: "Back"
      assert_no_match 'localStorage.getItem("theme")', response.body
      assert_no_match(/landing/, response.body)
    end
  end

  test "legal pages are also available under a branch's own slug" do
    get portal_privacy_policy_path(organization_slug: @organization.slug)

    assert_response :success
    assert_select "h1", text: "Privacy Policy"
  end

  test "pages contain no third-party analytics" do
    get login_path

    assert_no_match(/matomo|analytics\./i, response.body)
  end

  test "APP_NAME replaces the product name in page titles and the wordmark" do
    old = ENV["APP_NAME"]
    ENV["APP_NAME"] = "Queue Pro"
    get login_path

    assert_select "title", text: /Queue Pro/
    assert_no_match(/<title>[^<]*RxTerminal/, response.body)
  ensure
    ENV["APP_NAME"] = old
  end
end
