require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "slug must be unique and DNS-safe" do
    Organization.create!(name: "Acme", slug: "acme")

    duplicate = Organization.new(name: "Acme Two", slug: "acme")
    assert_not duplicate.valid?

    invalid = Organization.new(name: "Bad", slug: "Not_Valid!")
    assert_not invalid.valid?
  end

  test "reserved slugs are rejected" do
    org = Organization.new(name: "Admin", slug: "admin")
    assert_not org.valid?
  end

  test "a slug merely starting with a reserved word is allowed" do
    org = Organization.new(name: "Admin Extras", slug: "adminx")
    assert org.valid?
  end

  test "profane organization names and slugs are rejected" do
    name = Organization.new(name: "Big Cunt Ltd", slug: "acme")
    assert_not name.valid?
    assert_includes name.errors[:name], "contains language that isn't allowed"

    slug = Organization.new(name: "Acme", slug: "big-cunt-ltd")
    assert_not slug.valid?
    assert_includes slug.errors[:slug], "contains language that isn't allowed"
  end

  test "names that merely contain an allowlisted word are not flagged as profane" do
    org = Organization.new(name: "Scunthorpe Consulting", slug: "scunthorpe-consulting")
    assert org.valid?
  end

  test "create_personal_for! derives name and slug from the email local-part" do
    user = User.create!(email: "jane.doe@example.com", password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52", confirmed_at: Time.current)

    organization = Organization.create_personal_for!(user)

    assert_equal "Jane Doe", organization.name
    assert_equal "jane-doe", organization.slug
    assert user.memberships.exists?(organization: organization)
    assert user.memberships.first.has_role?(Role::APP_OWNER, scope: :app)
    assert_equal 1, user.organizations.first.calendars.count
    assert user.organizations.first.calendars.find_by!(is_default: true)
  end

  test "create_personal_for! resolves slug collisions across different email domains" do
    user_one = User.create!(email: "jane.doe@gmail.com", password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52", confirmed_at: Time.current)
    user_two = User.create!(email: "jane.doe@yahoo.com", password: "Tr8kMvln52", password_confirmation: "Tr8kMvln52", confirmed_at: Time.current)

    org_one = Organization.create_personal_for!(user_one)
    org_two = Organization.create_personal_for!(user_two)

    assert_not_equal org_one.slug, org_two.slug
    assert_equal "jane-doe", org_one.slug
    assert_equal "jane-doe-2", org_two.slug
  end

  test "new organizations get default operating hours and bookable times" do
    organization = Organization.create!(name: "Hours Test", slug: "hours-test-#{SecureRandom.hex(4)}")

    assert_equal Organization::DEFAULT_OPERATING_HOURS, organization.operating_hours
    assert_equal Organization::DEFAULT_BOOKABLE_TIMES, organization.bookable_times
    assert_equal "uk", organization.postcode_region
  end

  test "postcode_region must be a supported region" do
    organization = Organization.create!(name: "Region Test", slug: "region-test-#{SecureRandom.hex(4)}")

    organization.postcode_region = "de"
    assert_not organization.valid?
    assert_includes organization.errors[:postcode_region], "is not included in the list"

    organization.postcode_region = "us"
    assert organization.valid?
  end

  test "new organizations default service_currency to gbp" do
    organization = Organization.create!(name: "Currency Test", slug: "currency-test-#{SecureRandom.hex(4)}")

    assert_equal "gbp", organization.service_currency
  end

  test "service_currency must be a supported currency" do
    organization = Organization.create!(name: "Currency Test", slug: "currency-test-2-#{SecureRandom.hex(4)}")

    organization.service_currency = "jpy"
    assert_not organization.valid?
    assert_includes organization.errors[:service_currency], "is not included in the list"

    organization.service_currency = "usd"
    assert organization.valid?
  end

  test "service_currency_symbol returns the symbol for the organization's service currency" do
    organization = Organization.create!(name: "Currency Test", slug: "currency-test-3-#{SecureRandom.hex(4)}")

    assert_equal "£", organization.service_currency_symbol

    organization.update!(service_currency: "usd")
    assert_equal "$", organization.service_currency_symbol

    organization.update!(service_currency: "eur")
    assert_equal "€", organization.service_currency_symbol
  end

  test "business_type must be a known preset key or blank" do
    organization = Organization.create!(name: "Business Type Test", slug: "business-type-test-#{SecureRandom.hex(4)}")

    assert organization.valid?

    organization.business_type = "not-a-real-preset"
    assert_not organization.valid?
    assert_includes organization.errors[:business_type], "is not included in the list"

    organization.business_type = "clinic"
    assert organization.valid?
  end

  test "kiosk homescreen toggles default correctly" do
    organization = Organization.create!(name: "Kiosk Defaults", slug: "kiosk-defaults-#{SecureRandom.hex(4)}")

    assert_not organization.kiosk_show_featured_service?
    assert organization.kiosk_show_services?
    assert organization.kiosk_show_appointments?
  end

  test "invalid when all homescreen buttons are hidden" do
    organization = Organization.new(
      name: "No Buttons",
      slug: "no-buttons-#{SecureRandom.hex(4)}",
      kiosk_show_featured_service: false,
      kiosk_show_services: false,
      kiosk_show_appointments: false
    )

    assert_not organization.valid?
    assert_includes organization.errors[:base], "At least one homescreen button must be visible"
  end

  test "invalid when featured service is enabled without a selected service" do
    organization = Organization.new(
      name: "Featured Missing",
      slug: "featured-missing-#{SecureRandom.hex(4)}",
      kiosk_show_featured_service: true,
      kiosk_featured_service_id: nil
    )

    assert_not organization.valid?
    assert_includes organization.errors[:base], "A service must be selected for the featured slot"
  end

  test "kiosk featured service must belong to the organization" do
    organization = Organization.create!(name: "Featured Org", slug: "featured-org-#{SecureRandom.hex(4)}")
    other = Organization.create!(name: "Other Org", slug: "other-org-#{SecureRandom.hex(4)}")
    foreign_service = other.services.create!(
      internal_name: "foreign",
      display_name: "Foreign",
      estimated_duration: 10
    )

    organization.kiosk_show_featured_service = true
    organization.kiosk_featured_service_id = foreign_service.id

    assert_not organization.valid?
    assert_includes organization.errors[:kiosk_featured_service_id], "must be an active service in this organization"
  end

  test "supports kiosk_logo attachment" do
    organization = Organization.create!(name: "Logo Org", slug: "logo-org-#{SecureRandom.hex(4)}")

    organization.kiosk_logo.attach(
      io: StringIO.new("fake-logo"),
      filename: "logo.txt",
      content_type: "text/plain"
    )

    assert organization.kiosk_logo.attached?
  end

  test "open_on? reflects configured hours and open_now? checks the current clock" do
    organization = Organization.create!(name: "Hours Org", slug: "hours-org-#{SecureRandom.hex(4)}")
    monday = Date.parse("2026-07-13")

    assert organization.open_on?(monday)
    assert_not organization.open_on?(monday + 6.days)

    travel_to monday.in_time_zone.change(hour: 10, min: 0) do
      assert organization.open_now?
    end

    travel_to monday.in_time_zone.change(hour: 19, min: 0) do
      assert_not organization.open_now?
    end
  end

  test "full_address joins the address fields" do
    organization = Organization.new(
      name: "Address Org", slug: "address-org-#{SecureRandom.hex(4)}",
      address_line1: "1 Market St", address_city: "San Francisco",
      address_state: "CA", address_postal_code: "94105", address_country: "US"
    )

    assert_equal "1 Market St, San Francisco, CA, 94105, US", organization.full_address
  end

  test "appointment_email_message_text falls back to the default message" do
    organization = Organization.create_personal_for!(users(:one))

    assert_nil organization.appointment_email_message
    assert_equal Organization::DEFAULT_APPOINTMENT_EMAIL_MESSAGE, organization.appointment_email_message_text
  end

  test "appointment_email_message stores a custom message with normalized line endings" do
    organization = Organization.create_personal_for!(users(:one))

    organization.update!(appointment_email_message: "  Bring your inhaler.\r\nPark round the back.  ")

    assert_equal "Bring your inhaler.\nPark round the back.", organization.reload.appointment_email_message
    assert_equal "Bring your inhaler.\nPark round the back.", organization.appointment_email_message_text
  end

  test "saving a blank or unchanged default appointment email message keeps following the default" do
    organization = Organization.create_personal_for!(users(:one))
    organization.update!(appointment_email_message: "Custom")

    organization.update!(appointment_email_message: "")
    assert_nil organization.reload.appointment_email_message

    organization.update!(appointment_email_message: Organization::DEFAULT_APPOINTMENT_EMAIL_MESSAGE.gsub("\n", "\r\n"))
    assert_nil organization.reload.appointment_email_message
  end

  test "appointment_email_message is limited in length" do
    organization = Organization.create_personal_for!(users(:one))

    organization.appointment_email_message = "a" * (Organization::APPOINTMENT_EMAIL_MESSAGE_MAX_LENGTH + 1)

    assert_not organization.valid?
    assert organization.errors[:appointment_email_message].any?
  end
end
