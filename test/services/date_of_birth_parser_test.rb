# frozen_string_literal: true

require "test_helper"

class DateOfBirthParserTest < ActiveSupport::TestCase
  test "parses dd-mm-yyyy" do
    assert_equal Date.new(1990, 10, 10), DateOfBirthParser.parse("10-10-1990")
  end

  test "parses dd/mm/yyyy" do
    assert_equal Date.new(1990, 10, 10), DateOfBirthParser.parse("10/10/1990")
  end

  test "parses yyyy-mm-dd" do
    assert_equal Date.new(1990, 10, 10), DateOfBirthParser.parse("1990-10-10")
  end

  test "returns Date unchanged" do
    date = Date.new(1990, 10, 10)
    assert_equal date, DateOfBirthParser.parse(date)
  end

  test "returns nil for invalid input" do
    assert_nil DateOfBirthParser.parse("not-a-date")
    assert_nil DateOfBirthParser.parse("")
  end
end
