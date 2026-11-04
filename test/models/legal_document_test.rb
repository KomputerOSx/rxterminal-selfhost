require "test_helper"

class LegalDocumentTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create_personal_for!(users(:one))
    @organization.update!(name: "Acme <Pharmacy>", contact_email: "ops@acme.test", contact_phone: "0123 456")
    @tmp = Dir.mktmpdir
    @old_dir = ENV["LEGAL_DIR"]
    ENV["LEGAL_DIR"] = @tmp
  end

  teardown do
    ENV["LEGAL_DIR"] = @old_dir
    FileUtils.remove_entry(@tmp)
  end

  test "every default template exists, fills its placeholders and has no leftovers" do
    LegalDocument.names.each do |name|
      html = LegalDocument.render(name, organization: @organization)

      assert_no_match(/{{|}}/, html, name)
      assert_no_match(/strixon/i, html, name)
      assert_includes html, "ops@acme.test", name
    end
  end

  test "placeholder values are HTML-escaped" do
    html = LegalDocument.render("terms", organization: @organization)

    assert_includes html, "Acme &lt;Pharmacy&gt;"
    assert_not_includes html, "Acme <Pharmacy>"
  end

  test "a file in LEGAL_DIR overrides the default and is read without a restart" do
    assert_not LegalDocument.customised?("terms")
    File.write(File.join(@tmp, "terms.html"), "<p>Custom for {{organization_name}}</p><script>alert(1)</script>")

    assert LegalDocument.customised?("terms")
    html = LegalDocument.render("terms", organization: @organization)
    assert_includes html, "Custom for Acme &lt;Pharmacy&gt;"
    assert_no_match(/<script/, html)
  end

  test "retention days come from the retention job" do
    assert_equal DataRetentionJob::RETENTION_PERIOD.in_days.to_i.to_s, LegalDocument.placeholders(@organization)["pii_retention_days"]
  end

  test "unknown documents are rejected" do
    assert_raises(ArgumentError) { LegalDocument.path_for("../../etc/passwd") }
  end
end
