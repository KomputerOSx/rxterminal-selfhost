require "test_helper"

class AppHostTest < ActiveSupport::TestCase
  test "https? follows APP_PROTOCOL and defaults to https" do
    with_env("APP_PROTOCOL" => nil) { assert AppHost.https? }
    with_env("APP_PROTOCOL" => "https") { assert AppHost.https? }
    with_env("APP_PROTOCOL" => "http") { assert_not AppHost.https? }
  end

  test "secure cookies are never used outside production" do
    with_env("APP_PROTOCOL" => "https") { assert_not AppHost.secure_cookies? }
  end

  test "only the configured host and its subdomains are allowed" do
    with_env("APP_HOST" => "pharmacy.example.com") do
      assert AppHost.allowed_request_host?("pharmacy.example.com")
      assert AppHost.allowed_request_host?("www.pharmacy.example.com:3000")
      assert_not AppHost.allowed_request_host?("evil.test")
    end
  end

  private

  def with_env(vars)
    old = vars.keys.index_with { |k| ENV[k] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end
end
