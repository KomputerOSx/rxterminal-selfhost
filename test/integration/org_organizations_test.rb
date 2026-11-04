require "test_helper"

class OrgOrganizationsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  test "an owner can rename the organization" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_organization_path, params: { organization: { name: "New Name" } }

    assert_redirected_to org_settings_path
    assert_equal "New Name", @organization.reload.name
    assert AuditLog.exists?(event_type: :organization_updated)
  end

  test "an owner can update slug and postcode region" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_organization_path, params: {
      organization: { slug: "acme-pharmacy", postcode_region: "us", kiosk_collect_postcode: "0", kiosk_collect_dob: "0" }
    }

    assert_redirected_to org_settings_path
    @organization.reload
    assert_equal "acme-pharmacy", @organization.slug
    assert_equal "us", @organization.postcode_region
    assert_not @organization.kiosk_collect_postcode?
    assert_not @organization.kiosk_collect_dob?
  end

  test "the slug can be changed repeatedly without a waiting period" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_organization_path, params: { organization: { slug: "acme-pharmacy" } }
    assert_redirected_to org_settings_path

    patch org_organization_path, params: { organization: { slug: "acme-chemist" } }
    assert_redirected_to org_settings_path
    assert_equal "acme-chemist", @organization.reload.slug
  end

  test "the slug field is always editable" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_settings_path

    assert_response :success
    assert_no_match(/<input[^>]*name="organization\[slug\]"[^>]*disabled/, response.body)
  end

  test "an owner can update the service price currency" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_equal "gbp", @organization.service_currency

    patch org_organization_path, params: { organization: { service_currency: "usd" } }

    assert_redirected_to org_settings_path
    assert_equal "usd", @organization.reload.service_currency
  end

  test "an invalid service price currency is rejected" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_organization_path, params: { organization: { service_currency: "jpy" } }

    assert_response :unprocessable_entity
    assert_equal "gbp", @organization.reload.service_currency
  end

  test "an owner can update contact details" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_organization_path, params: {
      organization: {
        address_line1: "123 High Street",
        address_city: "London",
        address_postal_code: "SW1A 1AA",
        address_country: "GB",
        contact_email: "pharmacy@example.com",
        contact_phone: "020 7946 0958"
      }
    }

    assert_redirected_to org_settings_path
    @organization.reload
    assert_equal "123 High Street", @organization.address_line1
    assert_equal "London", @organization.address_city
    assert_equal "pharmacy@example.com", @organization.contact_email
    assert_equal "020 7946 0958", @organization.contact_phone
  end

  test "slug update rejects reserved and invalid values" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_organization_path, params: { organization: { slug: "admin" } }

    assert_response :unprocessable_entity
    assert_not_equal "admin", @organization.reload.slug
  end

  test "an admin can update slug but not rename the organization" do
    admin = users(:two)
    @organization.memberships.create!(user: admin).grant_role!(Role.find_by!(scope: :app, name: Role::APP_ADMIN))

    post login_path, params: { email: admin.email, password: "password123" }

    patch org_organization_path, params: { organization: { slug: "team-pharmacy" } }
    assert_redirected_to org_settings_path
    assert_equal "team-pharmacy", @organization.reload.slug

    patch org_organization_path, params: { organization: { name: "Hijacked Name" } }
    assert_redirected_to root_path
    assert_not_equal "Hijacked Name", @organization.reload.name
  end

  test "update rerenders settings on a validation failure" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_organization_path, params: { organization: { name: "" } }

    assert_response :unprocessable_entity
    assert_not_equal "", @organization.reload.name
  end

  test "a plain member without app.organization.manage cannot rename the organization" do
    member = users(:two)
    @organization.memberships.create!(user: member).grant_role!(Role.find_by!(scope: :app, name: Role::APP_USER))

    post login_path, params: { email: member.email, password: "password123" }

    patch org_organization_path, params: { organization: { name: "Hijacked Name" } }

    assert_redirected_to root_path
    assert_not_equal "Hijacked Name", @organization.reload.name
  end

  test "any authenticated user can create an additional organization" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_difference "Organization.count", 1 do
      post org_organization_path, params: {
        organization: {
          name: "Branch Pharmacy",
          slug: "branch-pharmacy",
          address_line1: "99 Branch Lane",
          address_city: "London",
          address_postal_code: "SW1A 1AA",
          address_country: "GB",
          contact_email: "branch@example.com",
          contact_phone: "020 1234 5678"
        }
      }
    end

    second = Organization.order(:id).last
    assert_equal "Branch Pharmacy", second.name
    assert_equal "branch-pharmacy", second.slug
    assert_equal "99 Branch Lane", second.address_line1
    assert_equal "branch@example.com", second.contact_email
    assert_equal "020 1234 5678", second.contact_phone
    assert second.memberships.exists?(user: @owner)
    assert_redirected_to dashboard_path
    assert_equal second.id, session[:current_organization_id]
  end

  test "create organization validates name" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_no_difference "Organization.count" do
      post org_organization_path, params: { organization: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "create organization accepts a custom slug" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_difference "Organization.count", 1 do
      post org_organization_path, params: {
        organization: {
          name: "Branch Pharmacy",
          slug: "branch-pharmacy",
          address_line1: "99 Branch Lane",
          address_city: "London",
          address_postal_code: "SW1A 1AA",
          address_country: "GB",
          contact_email: "branch@example.com",
          contact_phone: "020 1234 5678"
        }
      }
    end

    second = Organization.order(:id).last
    assert_equal "branch-pharmacy", second.slug
    assert_redirected_to dashboard_path
  end

  test "create organization rejects a taken slug" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_no_difference "Organization.count" do
      post org_organization_path, params: {
        organization: {
          name: "Duplicate Branch",
          slug: @organization.slug,
          address_line1: "99 Branch Lane",
          address_city: "London",
          address_postal_code: "SW1A 1AA",
          address_country: "GB",
          contact_email: "branch@example.com",
          contact_phone: "020 1234 5678"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match @organization.slug, response.body
  end

  test "create organization requires an address and contact details" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_no_difference "Organization.count" do
      post org_organization_path, params: {
        organization: {
          name: "Branch Pharmacy",
          slug: "branch-pharmacy",
          address_line1: "",
          address_city: "",
          address_postal_code: "",
          address_country: "",
          contact_email: "",
          contact_phone: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Address line1", response.body
  end

  test "create organization rejects reserved and invalid slugs" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_no_difference "Organization.count" do
      post org_organization_path, params: {
        organization: {
          name: "Bad Branch",
          slug: "admin",
          address_line1: "99 Branch Lane",
          address_city: "London",
          address_postal_code: "SW1A 1AA",
          address_country: "GB",
          contact_email: "branch@example.com",
          contact_phone: "020 1234 5678"
        }
      }
    end

    assert_response :unprocessable_entity

    assert_no_difference "Organization.count" do
      post org_organization_path, params: {
        organization: {
          name: "Bad Branch",
          slug: "Not_Valid!",
          address_line1: "99 Branch Lane",
          address_city: "London",
          address_postal_code: "SW1A 1AA",
          address_country: "GB",
          contact_email: "branch@example.com",
          contact_phone: "020 1234 5678"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "an owner can change the kiosk fallback icon" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_equal "favorite", @organization.kiosk_fallback_icon

    patch org_organization_path, params: { organization: { kiosk_fallback_icon: "local_pharmacy" } }

    assert_redirected_to org_settings_path
    assert_equal "local_pharmacy", @organization.reload.kiosk_fallback_icon
  end

  test "an unrecognised kiosk fallback icon is rejected" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_organization_path, params: { organization: { kiosk_fallback_icon: "not_a_real_icon" } }

    assert_response :unprocessable_entity
    assert_equal "favorite", @organization.reload.kiosk_fallback_icon
  end

  test "kiosk_logo is not a writable param of the organization update (uploads go through organization_logo)" do
    post login_path, params: { email: @owner.email, password: "password123" }

    logo = Rack::Test::UploadedFile.new(StringIO.new("fake-logo-bytes"), "image/png", original_filename: "logo.png")
    patch org_organization_path, params: { organization: { kiosk_logo: logo } }

    assert_response :forbidden
    assert_not @organization.reload.kiosk_logo.attached?
  end

  test "only owners and system admins can create another organization (branch)" do
    member = users(:two)
    @organization.memberships.create!(user: member)
    post login_path, params: { email: member.email, password: "password123" }

    get new_org_organization_path
    assert_redirected_to root_path

    assert_no_difference "Organization.count" do
      post org_organization_path, params: { organization: { name: "Sneaky Branch", slug: "sneaky-branch" } }
    end
  end

  test "org switcher shows create link and other organizations" do
    second = Organization.create_for!(@owner, name: "Second Branch")
    post login_path, params: { email: @owner.email, password: "password123" }

    get dashboard_path

    assert_response :success
    assert_match "Create organization", response.body
    assert_match second.name, response.body
  end
end
