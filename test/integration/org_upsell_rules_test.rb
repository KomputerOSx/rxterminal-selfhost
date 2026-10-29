# frozen_string_literal: true

require "test_helper"

class OrgUpsellRulesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @trigger = @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15,
      allows_immediate: true,
      icon: "vaccines"
    )
    @suggested = @organization.services.create!(
      internal_name: "blood-pressure",
      display_name: "Blood pressure check",
      estimated_duration: 10,
      allows_immediate: true,
      icon: "monitor_heart"
    )
    @rule = @organization.upsell_rules.create!(
      name: "Flu to BP",
      trigger_service: @trigger,
      suggested_service: @suggested,
      frequency_type: "every_nth_customer",
      frequency_value: 3,
      visit_type: "any",
      cooldown_days: 30,
      active: true,
      priority: 0,
      upsell_templates_attributes: [
        {
          title: "Free BP check",
          description: "Quick check while you wait.",
          cta_text: "Add blood pressure check"
        }
      ]
    )
  end

  test "a member with app.upsells.manage can view upsell rules index" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_upsell_rules_path
    assert_response :success
    assert_match "Flu to BP", response.body
    assert_match "Flu Jab", response.body
    assert_match "Blood pressure check", response.body
    assert_no_match 'title="Delete"', response.body
  end

  test "a member with app.upsells.manage can create an upsell rule with multiple variants" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { @organization.upsell_rules.count }, 1 do
        post org_upsell_rules_path, params: {
          upsell_rule: {
            name: "BP to flu A/B",
            trigger_service_id: @suggested.id,
            suggested_service_id: @trigger.id,
            frequency_type: "percentage_based",
            frequency_value: 25,
            visit_type: "returning",
            cooldown_days: 14,
            active: true,
            upsell_templates_attributes: {
              "0" => {
                title: "Seasonal flu jab",
                description: "Protect yourself this winter.",
                cta_text: "Add flu jab"
              },
              "1" => {
                title: "Stay protected",
                description: "Quick flu jab while you wait.",
                cta_text: "Book flu jab"
              }
            }
          }
        }
      end
    end

    created = @organization.upsell_rules.find_by!(name: "BP to flu A/B")
    assert_redirected_to org_upsell_rule_path(created)
    assert_equal 2, created.upsell_templates.count
    assert_equal [ "Seasonal flu jab", "Stay protected" ], created.upsell_templates.order(:id).pluck(:title)
  end

  test "a member with app.upsells.manage can create an upsell rule" do
    post login_path, params: { email: @owner.email, password: "password123" }

    with_active_subscription(@organization, Billing::Plans::BUSINESS) do
      assert_difference -> { @organization.upsell_rules.count }, 1 do
        post org_upsell_rules_path, params: {
          upsell_rule: {
            name: "BP to flu",
            trigger_service_id: @suggested.id,
            suggested_service_id: @trigger.id,
            frequency_type: "percentage_based",
            frequency_value: 25,
            visit_type: "returning",
            cooldown_days: 14,
            active: true,
            upsell_templates_attributes: {
              "0" => {
                title: "Seasonal flu jab",
                description: "Protect yourself this winter.",
                cta_text: "Add flu jab"
              }
            }
          }
        }
      end
    end

    created = @organization.upsell_rules.find_by!(name: "BP to flu")
    assert_redirected_to org_upsell_rule_path(created)
    assert_equal "percentage_based", created.frequency_type
    assert_equal 1, created.upsell_templates.count
    assert_equal "Seasonal flu jab", created.upsell_templates.first.title
  end

  test "a member with app.upsells.manage can view A/B variant performance" do
    @rule.upsell_templates.create!(
      title: "Second headline",
      description: "Alternative copy.",
      cta_text: "Try this instead"
    )

    post login_path, params: { email: @owner.email, password: "password123" }

    get org_upsell_rule_path(@rule)
    assert_response :success
    assert_match "A/B variant performance", response.body
    assert_match "Variant A", response.body
    assert_match "Variant B", response.body
  end

  test "a member with app.upsells.manage can view an upsell rule" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_upsell_rule_path(@rule)
    assert_response :success
    assert_match "Flu to BP", response.body
    assert_match "Performance", response.body
    assert_match "Delete rule", response.body
  end

  test "a member with app.upsells.manage can update an upsell rule" do
    post login_path, params: { email: @owner.email, password: "password123" }

    template = @rule.upsell_templates.first
    patch org_upsell_rule_path(@rule), params: {
      upsell_rule: {
        name: "Flu to BP (updated)",
        trigger_service_id: @trigger.id,
        suggested_service_id: @suggested.id,
        frequency_type: "every_nth_customer",
        frequency_value: 2,
        visit_type: "first_visit",
        cooldown_days: 7,
        active: true,
        upsell_templates_attributes: {
          "0" => {
            id: template.id,
            title: "Updated title",
            description: template.description,
            cta_text: template.cta_text
          }
        }
      }
    }

    assert_redirected_to org_upsell_rule_path(@rule)
    @rule.reload
    assert_equal "Flu to BP (updated)", @rule.name
    assert_equal "first_visit", @rule.visit_type
    assert_equal "Updated title", @rule.upsell_templates.first.title
  end

  test "a member with app.upsells.manage can toggle an upsell rule" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert @rule.active?
    post toggle_org_upsell_rule_path(@rule)
    assert_redirected_to org_upsell_rules_path
    assert_not @rule.reload.active?
  end

  test "a member with app.upsells.manage can reorder upsell rules" do
    post login_path, params: { email: @owner.email, password: "password123" }

    other = @organization.upsell_rules.create!(
      name: "Second rule",
      trigger_service: @suggested,
      suggested_service: @trigger,
      frequency_type: "every_nth_customer",
      frequency_value: 5,
      visit_type: "any",
      cooldown_days: 0,
      active: true,
      priority: 5,
      upsell_templates_attributes: {
        "0" => { title: "Other", cta_text: "Accept" }
      }
    )

    patch move_up_org_upsell_rule_path(@rule)
    assert_redirected_to org_upsell_rules_path
    assert_equal 5, @rule.reload.priority
    assert_equal 0, other.reload.priority
  end

  test "a member with app.upsells.manage can delete an upsell rule" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_difference -> { @organization.upsell_rules.count }, -1 do
      delete org_upsell_rule_path(@rule)
    end

    assert_redirected_to org_upsell_rules_path
  end

  test "new form shows visit type and age targeting when the organization collects dob" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get new_org_upsell_rule_path
    assert_response :success
    assert_match "Visit type", response.body
    assert_match "Minimum age", response.body
    assert_match "Maximum age", response.body
  end

  test "new form hides visit type and age targeting when the organization does not collect dob" do
    @organization.update!(kiosk_collect_dob: false)
    post login_path, params: { email: @owner.email, password: "password123" }

    get new_org_upsell_rule_path
    assert_response :success
    assert_no_match "Visit type", response.body
    assert_no_match "Minimum age", response.body
    assert_no_match "Maximum age", response.body
  end

  test "index and show hide visit type and age range once the organization stops collecting dob" do
    @rule.update!(visit_type: "first_visit", min_age: 18)
    @organization.update!(kiosk_collect_dob: false)
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_upsell_rules_path
    assert_response :success
    assert_no_match "First visit only", response.body

    get org_upsell_rule_path(@rule)
    assert_response :success
    assert_no_match "Audience", response.body
    assert_no_match "Age range", response.body
  end

  test "a member without app.upsells.manage is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_upsell_rules_path
    assert_redirected_to root_path
  end
end
