require "test_helper"

class LegalPagesTest < ActionDispatch::IntegrationTest
  test "legal pages render on root domain with landing layout" do
    [
      [ legal_terms_path, /Terms/i ],
      [ legal_privacy_policy_path, /Privacy Policy/i ],
      [ legal_cookies_path, /Cookies Policy/i ],
      [ legal_gdpr_path, /GDPR/i ]
    ].each do |path, heading|
      get path

      assert_response :success
      assert_match heading, response.body
      assert_match "Strixon Ltd", response.body
      assert_match 'localStorage.getItem("theme")', response.body
      assert_select "a[href=?]", path
    end
  end
end
