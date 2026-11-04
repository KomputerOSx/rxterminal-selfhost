require "test_helper"

class AppConfigTest < ActiveSupport::TestCase
  test "name defaults to RxTerminal and follows APP_NAME" do
    with_env("APP_NAME" => nil) { assert_equal "RxTerminal", AppConfig.name; assert AppConfig.default_name? }
    with_env("APP_NAME" => "Queue Pro") { assert_equal "Queue Pro", AppConfig.name; assert_not AppConfig.default_name? }
  end

  test "support email prefers SUPPORT_EMAIL, then the primary organization, then MAIL_FROM" do
    with_env("SUPPORT_EMAIL" => "help@x.test") { assert_equal "help@x.test", AppConfig.support_email }
    with_env("SUPPORT_EMAIL" => nil, "MAIL_FROM" => "My Shop <no-reply@shop.test>") do
      Organization.stub :primary, nil do
        assert_equal "no-reply@shop.test", AppConfig.support_email
      end
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
