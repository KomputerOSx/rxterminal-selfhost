require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "fresh-user@example.com", password: "Xk92!vTqZmR7", confirmed_at: Time.current)
    @organization = Organization.create_personal_for!(@user)
    post login_path, params: { email: @user.email, password: "Xk92!vTqZmR7" }
  end

  test "show defaults to the first step for a brand-new user" do
    get onboarding_path
    assert_response :success
  end

  test "show redirects an already-onboarded user straight to the dashboard" do
    @user.update_columns(onboarding_completed_at: Time.current)

    get onboarding_path

    assert_redirected_to dashboard_path
  end

  test "show won't let a user jump ahead of the furthest step they've reached" do
    get onboarding_step_path("organization")

    assert_redirected_to onboarding_step_path("welcome")
  end

  test "show allows revisiting an earlier step once further progress has been made" do
    @user.update_columns(onboarding_step: "organization")

    get onboarding_step_path("welcome")

    assert_response :success
  end

  test "update advances the pointer to the next step" do
    patch onboarding_step_path("welcome")

    assert_redirected_to onboarding_step_path("profile")
    assert_equal "profile", @user.reload.onboarding_step
  end

  test "update on the last step completes onboarding" do
    @user.update_columns(onboarding_step: "finish")

    patch onboarding_step_path("finish")

    assert_redirected_to dashboard_path
    assert @user.reload.onboarding_completed?
  end

  test "update does not rewind progress when resubmitting an earlier step" do
    @user.update_columns(onboarding_step: "organization")

    patch onboarding_step_path("welcome")

    assert_equal "organization", @user.reload.onboarding_step
  end

  test "profile step saves first and last name" do
    patch onboarding_step_path("profile"), params: {
      user: { first_name: "Alex", last_name: "Rivera" }
    }

    assert_redirected_to onboarding_step_path("organization")
    @user.reload
    assert_equal "Alex", @user.first_name
    assert_equal "Rivera", @user.last_name
  end

  test "profile step requires first and last name" do
    @user.update_columns(onboarding_step: "profile")

    patch onboarding_step_path("profile"), params: {
      user: { first_name: "", last_name: "" }
    }

    assert_response :unprocessable_entity
    assert_match "First name", response.body
    assert_equal "profile", @user.reload.onboarding_step
  end

  test "organization step saves org details including the mandatory address" do
    @user.update_columns(onboarding_step: "organization")

    patch onboarding_step_path("organization"), params: {
      organization: {
        name: "High Street Pharmacy",
        slug: "high-street-pharmacy",
        contact_email: "pharmacy@example.com",
        contact_phone: "020 7946 0958",
        address_line1: "1 Market St",
        address_city: "San Francisco",
        address_state: "CA",
        address_postal_code: "94105",
        address_country: "US"
      }
    }

    assert_redirected_to onboarding_step_path("business_type")
    @organization.reload
    assert_equal "High Street Pharmacy", @organization.name
    assert_equal "high-street-pharmacy", @organization.slug
    assert_equal "pharmacy@example.com", @organization.contact_email
    assert_equal "020 7946 0958", @organization.contact_phone
    assert_equal "1 Market St, San Francisco, CA, 94105, US", @organization.full_address
  end

  test "organization step fails without an address" do
    @user.update_columns(onboarding_step: "organization")

    patch onboarding_step_path("organization"), params: {
      organization: {
        name: "High Street Pharmacy",
        slug: "high-street-pharmacy",
        contact_email: "pharmacy@example.com",
        contact_phone: "020 7946 0958"
      }
    }

    assert_response :unprocessable_entity
    assert_predicate @organization.reload.address_line1, :blank?
  end

  test "business_type step seeds the preset's starter services and one upsell rule" do
    @user.update_columns(onboarding_step: "business_type")

    assert_difference -> { @organization.services.count } => 3, -> { @organization.upsell_rules.count } => 1 do
      patch onboarding_step_path("business_type"), params: { organization: { business_type: "clinic" } }
    end

    assert_redirected_to onboarding_step_path("data_collection")
    assert_equal "clinic", @organization.reload.business_type
    assert_equal %w[Consultation Vaccination Follow-up\ appointment], @organization.services.order(:id).pluck(:display_name)
  end

  test "business_type step seeds nothing for general/other" do
    @user.update_columns(onboarding_step: "business_type")

    assert_no_difference -> { @organization.services.count } do
      patch onboarding_step_path("business_type"), params: { organization: { business_type: "general" } }
    end

    assert_redirected_to onboarding_step_path("data_collection")
    assert_equal "general", @organization.reload.business_type
  end

  test "business_type step does not re-seed when revisited with a different preset" do
    @user.update_columns(onboarding_step: "business_type")
    patch onboarding_step_path("business_type"), params: { organization: { business_type: "clinic" } }
    assert_equal 3, @organization.reload.services.count

    patch onboarding_step_path("business_type"), params: { organization: { business_type: "salon" } }

    @organization.reload
    assert_equal "salon", @organization.business_type
    assert_equal 3, @organization.services.count
    assert_equal %w[Consultation Vaccination Follow-up\ appointment], @organization.services.order(:id).pluck(:display_name)
  end

  test "business_type step rejects an unknown preset key" do
    @user.update_columns(onboarding_step: "business_type")

    patch onboarding_step_path("business_type"), params: { organization: { business_type: "not-a-real-preset" } }

    assert_response :unprocessable_entity
    assert_equal "business_type", @user.reload.onboarding_step
  end

  test "data_collection step saves the customer-data toggles" do
    @user.update_columns(onboarding_step: "data_collection")

    patch onboarding_step_path("data_collection"), params: {
      organization: { kiosk_collect_dob: "0", kiosk_collect_postcode: "1" }
    }

    assert_redirected_to onboarding_step_path("time_zone")
    @organization.reload
    assert_not @organization.kiosk_collect_dob?
    assert @organization.kiosk_collect_postcode?
  end

  test "time_zone step saves the organization's time zone" do
    @user.update_columns(onboarding_step: "time_zone")

    patch onboarding_step_path("time_zone"), params: {
      organization: { time_zone: "London" }
    }

    assert_redirected_to onboarding_step_path("currency")
    assert_equal "London", @organization.reload.time_zone
  end

  test "currency step renders a service currency select defaulting to the organization's currency" do
    @user.update_columns(onboarding_step: "currency")

    get onboarding_step_path("currency")

    assert_response :success
    assert_select "select.select-field[name=?]", "organization[service_currency]" do
      assert_select "option[selected][value=?]", @organization.service_currency
      assert_select "option", count: Organization::SERVICE_CURRENCIES.size
    end
  end

  test "currency step saves the organization's service currency" do
    @user.update_columns(onboarding_step: "currency")

    patch onboarding_step_path("currency"), params: {
      organization: { service_currency: "usd" }
    }

    assert_redirected_to onboarding_step_path("finish")
    assert_equal "usd", @organization.reload.service_currency
  end

  test "currency step rejects an unsupported currency" do
    @user.update_columns(onboarding_step: "currency")

    patch onboarding_step_path("currency"), params: {
      organization: { service_currency: "jpy" }
    }

    assert_response :unprocessable_entity
    assert_equal "currency", @user.reload.onboarding_step
    assert_equal "gbp", @organization.reload.service_currency
  end

  test "time_zone step rejects an unrecognized time zone" do
    @user.update_columns(onboarding_step: "time_zone")

    patch onboarding_step_path("time_zone"), params: {
      organization: { time_zone: "Not A Real Zone" }
    }

    assert_response :unprocessable_entity
    assert_equal "time_zone", @user.reload.onboarding_step
  end

  test "organization step requires essential contact fields" do
    @user.update_columns(onboarding_step: "organization")

    patch onboarding_step_path("organization"), params: {
      organization: {
        name: "High Street Pharmacy",
        slug: "high-street-pharmacy",
        address_line1: "",
        address_city: "",
        address_postal_code: "",
        address_country: "",
        contact_email: "",
        contact_phone: ""
      }
    }

    assert_response :unprocessable_entity
    assert_match "Address line1", response.body
    assert_equal "organization", @user.reload.onboarding_step
  end

  test "organization step rejects a taken slug" do
    other = Organization.create_for!(users(:two), name: "Other Pharmacy", slug: "other-pharmacy")
    @user.update_columns(onboarding_step: "organization")

    patch onboarding_step_path("organization"), params: {
      organization: {
        name: "Duplicate Pharmacy",
        slug: other.slug,
        address_line1: "456 Market Street",
        address_city: "London",
        address_postal_code: "SW1A 1AA",
        address_country: "GB",
        contact_email: "dup@example.com",
        contact_phone: "020 1111 2222"
      }
    }

    assert_response :unprocessable_entity
    assert_match other.slug, response.body
  end

  test "skip button uses confirm-modal" do
    get onboarding_path

    assert_response :success
    assert_match 'data-controller="confirm-modal"', response.body
    assert_match "confirm-modal#confirm", response.body
    assert_no_match "turbo_confirm", response.body
  end

  test "skip marks onboarding complete without requiring any steps" do
    post skip_onboarding_path

    assert_redirected_to dashboard_path
    assert @user.reload.onboarding_completed?
  end
end
