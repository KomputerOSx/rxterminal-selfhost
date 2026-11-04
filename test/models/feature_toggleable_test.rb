require "test_helper"

class FeatureToggleableTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}")
  end

  test "an opt-in feature is off until the organization switches it on" do
    assert_not @organization.feature_enabled?(:online_appointment_booking)

    @organization.update_feature!(:online_appointment_booking, enabled: true)

    assert @organization.feature_enabled?(:online_appointment_booking)
  end

  test "a feature without org_opt_in_required is always on" do
    assert @organization.feature_enabled?(:public_portal)
  end

  test "an unknown feature is never enabled" do
    @organization.update_feature!(:widget_beta, enabled: true)

    assert_not @organization.feature_enabled?(:widget_beta)
  end

  test "update_feature! merges rather than replaces existing settings" do
    @organization.update_feature!(:waiting_time, enabled: true, note: "first")
    @organization.update_feature!(:waiting_time, enabled: false)

    settings = @organization.reload.feature_settings(:waiting_time)
    assert_equal "first", settings["note"]
    assert_equal false, settings["enabled"]
  end

  test "a NULL features column loads as an empty hash instead of raising" do
    @organization.update_column(:features, nil)

    reloaded = Organization.find(@organization.id)

    assert_equal({}, reloaded.features)
    assert_nothing_raised { reloaded.feature_enabled?(:waiting_time) }
  end

  test "waiting_time_reset_at returns nil until reset" do
    assert_nil @organization.waiting_time_reset_at
  end

  test "reset_waiting_time_timer! stores reset_at without dropping other settings" do
    @organization.update_feature!(:waiting_time, enabled: true, note: "keep")

    freeze_time do
      @organization.reset_waiting_time_timer!
      assert_in_delta Time.current.to_i, @organization.reload.waiting_time_reset_at.to_i, 1
      assert_equal "keep", @organization.feature_settings(:waiting_time)["note"]
      assert_equal true, @organization.feature_settings(:waiting_time)["enabled"]
    end
  end
end
