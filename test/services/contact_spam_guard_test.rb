require "test_helper"

class ContactSpamGuardTest < ActiveSupport::TestCase
  test "detects honeypot fields" do
    session = { contact_form_token: "abc" }

    assert ContactSpamGuard.bot_submission?(params: { website: "http://spam.test", form_token: "abc", form_loaded_at: 5.seconds.ago.to_i }, session: session)
    assert ContactSpamGuard.bot_submission?(params: { company: "Acme", form_token: "abc", form_loaded_at: 5.seconds.ago.to_i }, session: session)
  end

  test "detects missing or mismatched form token" do
    session = { contact_form_token: "abc" }
    loaded_at = 5.seconds.ago.to_i

    assert ContactSpamGuard.bot_submission?(params: { form_token: "", form_loaded_at: loaded_at }, session: session)
    assert ContactSpamGuard.bot_submission?(params: { form_token: "wrong", form_loaded_at: loaded_at }, session: session)
  end

  test "detects submissions that are too fast or too old" do
    session = { contact_form_token: "abc" }

    assert ContactSpamGuard.bot_submission?(params: { form_token: "abc", form_loaded_at: Time.current.to_i }, session: session)
    assert ContactSpamGuard.bot_submission?(params: { form_token: "abc", form_loaded_at: 25.hours.ago.to_i }, session: session)
  end

  test "accepts a normal submission" do
    session = { contact_form_token: "abc" }

    assert_not ContactSpamGuard.bot_submission?(params: { form_token: "abc", form_loaded_at: 5.seconds.ago.to_i }, session: session)
  end
end
