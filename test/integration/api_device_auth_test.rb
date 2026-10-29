# frozen_string_literal: true

require "test_helper"

class ApiDeviceAuthTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @api_key = SecureRandom.hex(32)
    @device = @organization.devices.create!(
      device_id: "api_kiosk",
      name: "API kiosk",
      api_key: @api_key,
      status: "active"
    )
  end

  test "device_auth returns a jwt for valid credentials" do
    assert_difference -> { AuditLog.where(event_type: :device_auth_success).count }, 1 do
      post api_v1_device_auth_path, params: {
        device_id: @device.device_id,
        api_key: @api_key
      }, as: :json
    end

    assert_response :success
    body = response.parsed_body
    assert body["token"].present?
    assert_equal @device.device_id, body["device_id"]
    assert_equal @organization.slug, body["organization_slug"]

    payload = JwtService.decode(body["token"])
    assert_equal @device.device_id, payload["device_id"]
    assert_equal @device.organization_id, payload["organization_id"]
  end

  test "device_auth rejects invalid api key" do
    assert_difference -> { AuditLog.where(event_type: :device_auth_failure).count }, 1 do
      post api_v1_device_auth_path, params: {
        device_id: @device.device_id,
        api_key: "bad"
      }, as: :json
    end

    assert_response :unauthorized
  end

  test "device_auth rejects unknown device id" do
    post api_v1_device_auth_path, params: {
      device_id: "missing_device",
      api_key: @api_key
    }, as: :json

    assert_response :not_found
  end
end
