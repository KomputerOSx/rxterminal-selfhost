require "test_helper"

class LegalPagesTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create_personal_for!(users(:one))
    @organization.update!(name: "High Street Pharmacy", contact_email: "hello@highstreet.test")
  end

  test "legal pages render on the root domain with the organization's details" do
    [
      [ legal_terms_path, "Terms of Use" ],
      [ legal_privacy_policy_path, "Privacy Policy" ],
      [ legal_cookies_path, "Cookies Policy" ],
      [ legal_gdpr_path, "Data Protection Statement" ]
    ].each do |path, heading|
      get path

      assert_response :success
      assert_select "h1", text: heading
      assert_match "High Street Pharmacy", response.body
      assert_match "hello@highstreet.test", response.body
      assert_no_match(/strixon|{{|}}/i, response.body)
      assert_match 'localStorage.getItem("theme")', response.body
      assert_select "a[href=?]", path
    end
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
