require "test_helper"

class SetupTest < ActionDispatch::IntegrationTest
  PASSWORD = "Tr8kMvln52"

  def params_for(email: "owner@example.com", org: "High Street Pharmacy")
    { organization_name: org, user: { email: email, password: PASSWORD, password_confirmation: PASSWORD } }
  end

  test "a fresh install redirects every page to /setup" do
    Setup.stub :required?, true do
      get login_path
      assert_redirected_to instance_setup_path

      get instance_setup_path
      assert_response :success
      assert_select "input[name=organization_name]"
    end
  end

  test "setup creates the owner, organization and system admin, then signs in" do
    Setup.stub :required?, true do
      assert_difference [ "User.count", "Organization.count" ], 1 do
        post instance_setup_path, params: params_for
      end
    end

    assert_redirected_to dashboard_path
    user = User.find_by!(email: "owner@example.com")
    assert user.confirmed?
    assert user.system_admin?
    organization = user.organizations.sole
    assert_equal "High Street Pharmacy", organization.name
    assert user.memberships.first.has_role?(Role::APP_OWNER, scope: :app)
    assert Session.exists?(user: user)
  end

  test "setup rejects a blank organization name and weak passwords" do
    Setup.stub :required?, true do
      assert_no_difference "User.count" do
        post instance_setup_path, params: params_for(org: "")
        assert_response :unprocessable_entity

        post instance_setup_path, params: { organization_name: "X", user: { email: "a@example.com", password: "short", password_confirmation: "short" } }
        assert_response :unprocessable_entity
      end
    end
  end

  test "setup is unavailable once a user exists" do
    get instance_setup_path
    assert_redirected_to login_path

    assert_no_difference "User.count" do
      post instance_setup_path, params: params_for
    end
    assert_redirected_to login_path
  end

  test "a second setup racing past the first is refused inside the transaction" do
    # true for the controller guard, false once the transaction re-checks.
    answers = [ true, false ]
    Setup.stub :required?, -> { answers.empty? ? false : answers.shift } do
      assert_no_difference "User.count" do
        post instance_setup_path, params: params_for
      end
    end
    assert_redirected_to login_path
  end
end
