# frozen_string_literal: true

require "test_helper"

class OrganizationLogoReviewMailerTest < ActionMailer::TestCase
  test "pending_reminder includes the count and a link to the review queue" do
    mail = OrganizationLogoReviewMailer.pending_reminder(users(:one), 3)

    assert_equal [ users(:one).email ], mail.to
    assert_equal "3 organization logos awaiting review", mail.subject
    assert_match "3 unverified organization logos", mail.text_part.body.to_s
    assert_match "/admin/organization_logos?status=pending", mail.html_part.body.to_s
  end

  test "pending_reminder uses singular wording for one logo" do
    mail = OrganizationLogoReviewMailer.pending_reminder(users(:one), 1)

    assert_equal "1 organization logo awaiting review", mail.subject
    assert_match "there is 1 unverified organization logo", mail.text_part.body.to_s
  end
end
