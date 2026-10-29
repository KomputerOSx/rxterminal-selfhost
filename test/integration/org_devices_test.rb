# frozen_string_literal: true

require "test_helper"

class OrgDevicesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @device = @organization.devices.create!(
      device_id: "test_kiosk_01",
      name: "Front desk",
      api_key: SecureRandom.hex(32),
      status: "active"
    )
  end

  test "a member with app.devices.manage can view devices index" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_devices_path
    assert_response :success
    assert_match "Front desk", response.body
    assert_match "test_kiosk_01", response.body
  end

  test "a member with app.devices.manage can create a device and see api key once" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { @organization.devices.count }, 1 do
        post org_devices_path, params: {
          device: {
            device_id: "lobby_kiosk",
            name: "Lobby",
            status: "active"
          }
        }
      end
    end

    created = @organization.devices.find_by!(device_id: "lobby_kiosk")
    assert_redirected_to org_device_path(created)

    follow_redirect!
    assert_response :success
    assert_match "Save this API key now", response.body
  end

  test "a member with app.devices.manage can regenerate an api key" do
    post login_path, params: { email: @owner.email, password: "password123" }
    original_version = @device.token_version

    post regenerate_key_org_device_path(@device)
    assert_redirected_to org_device_path(@device)
    assert_operator @device.reload.token_version, :>, original_version
  end

  test "a member with app.devices.manage can revoke a device" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch set_status_org_device_path(@device, status: "revoked")
    assert_redirected_to org_device_path(@device)
    assert_equal "revoked", @device.reload.status
  end

  test "a member without app.devices.manage is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_devices_path
    assert_redirected_to root_path
  end
end
