require "test_helper"

class MarketingPagesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "pricing page shows plans and trial call to action" do
    get pricing_path

    assert_response :success
    assert_match(/Simple, transparent pricing/i, response.body)
    assert_match(/Starter/i, response.body)
    assert_match(/Business/i, response.body)
    assert_match(/£9\.99/i, response.body)
    assert_match(/£29\.99/i, response.body)
    assert_match(/Is there a free trial\?/i, response.body)
    assert_match(/Can I run multiple branches\?/i, response.body)
    assert_no_match(/What hardware do I need\?/i, response.body)
    assert_no_match(/Common Questions/i, response.body)
    assert_select "[data-controller='roi-calculator']"
    assert_select "input[type=range][id=roi-bookings][value='60']"
    assert_select "input[type=range][id=roi-minutes][value='5']"
    assert_select "input[type=range][id=roi-wage][value='18']"
    assert_select "a", text: "Start your free trial"
    assert_match 'localStorage.getItem("theme")', response.body
    assert_match 'aria-label="Toggle theme"', response.body
  end

  test "contact page renders form" do
    get contact_path

    assert_response :success
    assert_match(/Let.*talk/i, response.body)
    assert_select "form[action=?]", contact_path
    assert_select "input[name=name]"
    assert_select "textarea[name=message]"
    assert_select "input[name=form_token]"
    assert_select "input[name=form_loaded_at]"
  end

  test "contact form sends enquiry and confirmation emails" do
    assert_enqueued_jobs 2, only: ActionMailer::MailDeliveryJob do
      post contact_path, params: valid_contact_params
    end

    assert_redirected_to contact_sent_path
    follow_redirect!

    assert_response :success
    assert_match(/Your message has been sent/i, response.body)
    assert_match(/Jane Smith/, response.body)
  end

  test "contact honeypot silently accepts spam submissions" do
    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      post contact_path, params: valid_contact_params.merge(website: "http://spam.test")
    end

    assert_redirected_to contact_sent_path
  end

  test "contact form rejects instant bot submissions" do
    get contact_path
    token = css_select("input[name=form_token]").first["value"]

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      post contact_path, params: valid_contact_params(form_token: token, form_loaded_at: Time.current.to_i)
    end

    assert_redirected_to contact_sent_path
  end

  test "contact form validates required fields" do
    post contact_path, params: valid_contact_params(name: "", email: "", message: "")

    assert_response :unprocessable_entity
    assert_match(/Please fill in your name, email, and message/i, response.body)
  end

  test "legal pages render on root domain with landing layout" do
    [
      [ legal_terms_path, /Terms/i ],
      [ legal_privacy_policy_path, /Privacy Policy/i ],
      [ legal_cookies_path, /Cookies Policy/i ],
      [ legal_gdpr_path, /GDPR/i ]
    ].each do |path, heading|
      get path

      assert_response :success
      assert_match heading, response.body
      assert_match "Strixon Ltd", response.body
      assert_match 'localStorage.getItem("theme")', response.body
      assert_select "a[href=?]", path
    end
  end

  private

  def valid_contact_params(overrides = {})
    get contact_path
    token = css_select("input[name=form_token]").first["value"]

    {
      name: "Jane Smith",
      email: "jane@example.com",
      phone: "01911231234",
      message: "Interested in a demo for our pharmacy.",
      form_token: token,
      form_loaded_at: 5.seconds.ago.to_i
    }.merge(overrides)
  end
end
