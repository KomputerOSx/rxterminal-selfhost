require "test_helper"

class OrganizationLogoTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
  end

  def build_logo(status: "pending", decline_reason: nil)
    logo = @organization.organization_logos.build(uploaded_by: @owner, status: status, decline_reason: decline_reason)
    logo.image.attach(
      io: StringIO.new("fake-logo-bytes"), filename: "logo.png", content_type: "image/png"
    )
    logo
  end

  test "requires a decline_reason when declined" do
    logo = build_logo(status: "declined")
    assert_not logo.valid?
    assert_includes logo.errors[:decline_reason], "can't be blank"
  end

  test "rejects a 4th pending/approved logo for the same organization" do
    3.times { build_logo.save! }

    fourth = build_logo
    assert_not fourth.valid?
    assert_includes fourth.errors[:base], "You can have at most 3 logos pending or approved at a time"
  end

  test "declined logos do not count toward the cap" do
    2.times { build_logo(status: "declined", decline_reason: "not on brand").save! }
    3.times { build_logo.save! }

    assert_equal 5, @organization.organization_logos.count
    assert_equal 3, @organization.organization_logos.where(status: %w[pending approved]).count
  end

  test "approve! sets status, reviewer, and clears any prior decline reason" do
    logo = build_logo(status: "declined", decline_reason: "not on brand")
    logo.save!
    admin = users(:two)

    logo.approve!(reviewed_by: admin)

    assert logo.approved?
    assert_equal admin, logo.reviewed_by
    assert_not_nil logo.reviewed_at
    assert_nil logo.decline_reason
  end

  test "decline! sets status, reviewer, and reason" do
    logo = build_logo
    logo.save!
    admin = users(:two)

    logo.decline!(reviewed_by: admin, reason: "Low resolution")

    assert logo.declined?
    assert_equal admin, logo.reviewed_by
    assert_not_nil logo.reviewed_at
    assert_equal "Low resolution", logo.decline_reason
  end

  test "active? is true only when its image blob matches the organization's live kiosk_logo" do
    logo = build_logo(status: "approved")
    logo.save!

    assert_not logo.active?

    @organization.kiosk_logo.attach(logo.image.blob)
    assert logo.active?
  end
end
