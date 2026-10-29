# frozen_string_literal: true

require "test_helper"

class AuthLayoutTest < ActionDispatch::IntegrationTest
  test "login page links to kiosk and kiosk setup" do
    get login_path

    assert_response :success
    assert_select "a[href=?]", kiosk_root_path, text: "Kiosk"
    assert_select "a[href=?]", kiosk_setup_path, text: "Kiosk Setup"
  end

  test "signup page links to kiosk and kiosk setup" do
    get new_registration_path

    assert_response :success
    assert_select "a[href=?]", kiosk_root_path, text: "Kiosk"
    assert_select "a[href=?]", kiosk_setup_path, text: "Kiosk Setup"
  end

  test "other auth-layout pages do not link to kiosk or kiosk setup" do
    get new_password_reset_path

    assert_response :success
    assert_select "a[href=?]", kiosk_root_path, count: 0
    assert_select "a[href=?]", kiosk_setup_path, count: 0
  end
end
