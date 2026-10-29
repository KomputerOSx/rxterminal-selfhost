# frozen_string_literal: true

require "test_helper"

class CustomerPiiMatcherTest < ActiveSupport::TestCase
  test "postcode_match? ignores spaces and case" do
    assert CustomerPiiMatcher.postcode_match?("N1 1AA", "n11aa")
    assert CustomerPiiMatcher.postcode_match?("N1 1AA", "N1 1AA")
  end

  test "postcode_match? passes when query postcode is blank" do
    assert CustomerPiiMatcher.postcode_match?("N1 1AA", nil)
    assert CustomerPiiMatcher.postcode_match?("N1 1AA", "")
  end

  test "names_match? is case insensitive" do
    assert CustomerPiiMatcher.names_match?("JANE", "DOE", "jane", "doe")
    assert CustomerPiiMatcher.names_match?("Jane", "Doe", "JANE", "DOE")
  end

  test "names_match? ignores surrounding whitespace" do
    assert CustomerPiiMatcher.names_match?("  JANE  ", "DOE", "jane", " doe ")
  end

  test "dob_match? compares dates" do
    assert CustomerPiiMatcher.dob_match?(Date.new(1990, 10, 10), Date.new(1990, 10, 10))
    assert_not CustomerPiiMatcher.dob_match?(Date.new(1990, 10, 11), Date.new(1990, 10, 10))
  end

  test "dob_match? passes when query dob is blank" do
    assert CustomerPiiMatcher.dob_match?(Date.new(1990, 10, 10), nil)
    assert CustomerPiiMatcher.dob_match?(nil, nil)
  end
end
