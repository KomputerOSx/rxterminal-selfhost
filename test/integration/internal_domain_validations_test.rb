require "test_helper"

class InternalDomainValidationsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create_personal_for!(users(:one))
  end

  test "returns OK for a Growth org custom domain from an internal IP" do
    @organization.update!(custom_domain: "shop.example.com")

    get internal_domain_validations_path, params: { domain: "shop.example.com" },
        headers: { "REMOTE_ADDR" => "127.0.0.1" }

    assert_response :ok
    assert_equal "OK", response.body
  end

  test "returns not found when the domain is unknown" do
    get internal_domain_validations_path, params: { domain: "unknown.example.com" },
        headers: { "REMOTE_ADDR" => "10.0.0.5" }

    assert_response :not_found
  end

  test "rejects non-internal remote IPs" do
    @organization.update!(custom_domain: "shop.example.com")

    get internal_domain_validations_path, params: { domain: "shop.example.com" },
        env: { "REMOTE_ADDR" => "8.8.8.8", "HTTP_X_FORWARDED_FOR" => "8.8.8.8" }

    assert_response :unauthorized
  end
end
