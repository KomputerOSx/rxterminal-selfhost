require "test_helper"

class RegistrationConfirmationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "open sign-up is closed: the signup page redirects to login without an invitation" do
    get new_registration_path
    assert_redirected_to login_path

    assert_no_difference "User.count" do
      post registration_path, params: {
        user: { email: "walkin@example.com", password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52" }
      }
    end
    assert_redirected_to login_path
  end

  test "an invited person signs up, confirms and joins only the inviting organization" do
    email = "invitee@example.com"
    _invitation, token = invite(email)

    get invitation_path(token)
    assert_redirected_to new_registration_path(email: email)

    perform_enqueued_jobs do
      # The invitation's email wins over whatever is submitted.
      post registration_path, params: {
        user: { email: "someone-else@example.com", password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52" }
      }
    end
    assert_redirected_to new_confirmation_path

    code = ActionMailer::Base.deliveries.last.text_part.decoded[/(\d{6})/, 1]
    assert_no_difference "Organization.count" do
      assert_difference "User.count", 1 do
        post confirmations_path, params: { code: code.chars }
      end
    end
    assert_redirected_to dashboard_path

    user = User.find_by!(email: email)
    assert_not User.exists?(email: "someone-else@example.com")
    assert_equal [ @organization ], user.organizations.to_a
    assert user.onboarding_completed?
  end

  test "confirming without a matching invitation creates no account" do
    email = "stray@example.com"
    _invitation, token = invite(email)
    get invitation_path(token)

    perform_enqueued_jobs do
      post registration_path, params: {
        user: { email: email, password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52" }
      }
    end
    code = ActionMailer::Base.deliveries.last.text_part.decoded[/(\d{6})/, 1]
    OrganizationInvitation.update_all(accepted_at: Time.current)

    assert_no_difference "User.count" do
      post confirmations_path, params: { code: code.chars }
    end
    assert_redirected_to login_path
  end

  private

  def invite(email)
    role = Role.find_or_create_by!(scope: :app, name: Role::APP_USER)
    OrganizationInvitation.generate_for!(organization: @organization, email: email, role: role, invited_by: @owner)
  end
end
