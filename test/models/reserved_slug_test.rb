require "test_helper"

class ReservedSlugTest < ActiveSupport::TestCase
  test "reserved? matches known reserved words case-insensitively" do
    assert ReservedSlug.reserved?("admin")
    assert ReservedSlug.reserved?("ADMIN")
  end

  test "reserved? does not match slugs that merely start with a reserved word" do
    assert_not ReservedSlug.reserved?("adminx")
  end

  test "reserved? does not match ordinary slugs" do
    assert_not ReservedSlug.reserved?("acme")
  end
end
