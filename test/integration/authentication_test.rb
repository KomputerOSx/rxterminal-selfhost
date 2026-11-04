require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "root redirects anonymous visitors to login" do
    get root_path

    assert_redirected_to login_path
  end

  test "open sign-up is closed" do
    get new_registration_path

    assert_redirected_to login_path
    assert_select "a[href=?]", new_registration_path, count: 0
  end

  test "user can sign in and sign out" do
    post login_path, params: { email: users(:one).email, password: "password123" }

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_select "button", text: /Logout/

    delete session_path

    assert_redirected_to root_path
    follow_redirect!
    assert_redirected_to login_path
  end

  test "signing in from a new user agent logs a new_device_login audit event, a repeat from a known one does not, even across logout" do
    post login_path, params: { email: users(:one).email, password: "password123" }, headers: { "User-Agent" => "AgentOne" }
    assert_not AuditLog.exists?(event_type: "new_device_login", user: users(:one))

    delete session_path

    post login_path, params: { email: users(:one).email, password: "password123" }, headers: { "User-Agent" => "AgentOne" }
    assert_not AuditLog.exists?(event_type: "new_device_login", user: users(:one))

    delete session_path

    post login_path, params: { email: users(:one).email, password: "password123" }, headers: { "User-Agent" => "AgentTwo" }
    assert AuditLog.exists?(event_type: "new_device_login", user: users(:one))
  end

  test "account locks after too many failed login attempts" do
    5.times do
      post login_path, params: { email: users(:one).email, password: "wrong-password" }
    end

    assert users(:one).reload.locked?

    # Rack::Attack's own "logins/email" throttle (config/initializers/rack_attack.rb)
    # has the same limit (5 per 20 minutes) and has now also been tripped by the
    # attempts above, so it intercepts this request before the controller's own
    # account-lockout check runs - a real login attempt at this point would be
    # blocked by either layer.
    post login_path, params: { email: users(:one).email, password: "password123" }
    assert_response :too_many_requests
  end
end
