require "test_helper"

class OrgWalkInsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15,
      allows_immediate: true
    )
  end

  test "a member with app.queue.manage can create a walk-in" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_difference "ServiceRequest.count", 1 do
      post org_walk_in_path, params: {
        service_request: {
          service_id: @service.id,
          first_name: "john",
          last_name: "smith",
          dob: "15-01-1990",
          postcode: "SW1A 1AA"
        }
      }
    end

    assert_redirected_to org_confirmed_walk_in_path
    walk_in_log = AuditLog.where(event_type: :walk_in_created).last
    assert_equal @organization.id, walk_in_log.metadata["organization_id"]
    assert_equal @owner.id, walk_in_log.user_id
    follow_redirect!
    assert_match "1", response.body
  end

  test "a member can create a walk-in without a dob when the organization does not collect it" do
    @organization.update!(kiosk_collect_dob: false)
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_difference "ServiceRequest.count", 1 do
      post org_walk_in_path, params: {
        service_request: {
          service_id: @service.id,
          first_name: "john",
          last_name: "smith",
          postcode: "SW1A 1AA"
        }
      }
    end

    assert_redirected_to org_confirmed_walk_in_path
    assert_nil ServiceRequest.last.dob
  end

  test "a member without app.queue.manage is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    post org_walk_in_path, params: {
      service_request: {
        service_id: @service.id,
        first_name: "john",
        last_name: "smith",
        dob: "15-01-1990",
        postcode: "SW1A 1AA"
      }
    }

    assert_redirected_to root_path
  end

  test "upsell decline returns to confirmed with one queue number" do
    post login_path, params: { email: @owner.email, password: "password123" }

    post org_walk_in_path, params: {
      service_request: {
        service_id: @service.id,
        first_name: "john",
        last_name: "smith",
        dob: "15-01-1990",
        postcode: "SW1A 1AA"
      }
    }
    follow_redirect!

    suggested = @organization.services.create!(
      internal_name: "blood-pressure",
      display_name: "Blood pressure check",
      estimated_duration: 10,
      allows_immediate: true
    )
    rule = @organization.upsell_rules.create!(
      name: "Flu to BP",
      trigger_service: @service,
      suggested_service: suggested,
      frequency_type: "every_nth_customer",
      frequency_value: 2,
      visit_type: "any",
      cooldown_days: 0,
      active: true,
      upsell_templates_attributes: [
        {
          title: "Free BP check",
          description: "Quick check while you wait.",
          cta_text: "Add blood pressure check"
        }
      ]
    )

    post org_walk_in_path, params: {
      service_request: {
        service_id: @service.id,
        first_name: "jane",
        last_name: "doe",
        dob: "20-05-1985",
        postcode: "SW1A 2AA"
      }
    }
    assert_redirected_to org_upsell_walk_in_path

    post org_upsell_decline_walk_in_path
    assert_redirected_to org_confirmed_walk_in_path
  end
end
