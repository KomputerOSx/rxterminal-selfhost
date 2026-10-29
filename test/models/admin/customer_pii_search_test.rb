# frozen_string_literal: true

require "test_helper"

module Admin
  class CustomerPiiSearchTest < ActiveSupport::TestCase
    test "requires first name and last name" do
      search = CustomerPiiSearch.new

      assert_not search.valid?
      assert_includes search.errors[:first_name], "can't be blank"
      assert_includes search.errors[:last_name], "can't be blank"
    end

    test "requires at least one organization when no dob is given" do
      search = CustomerPiiSearch.new(first_name: "Jane", last_name: "Doe")

      assert_not search.valid?
      assert_includes search.errors[:organization_ids], "must include at least one organization when no date of birth is given"
    end

    test "valid without a dob when at least one organization is selected" do
      search = CustomerPiiSearch.new(first_name: "Jane", last_name: "Doe")
      search.organization_ids = [ 1 ]

      assert search.valid?
    end

    test "accepts dob with slashes" do
      search = CustomerPiiSearch.new(
        first_name: "Jane",
        last_name: "Doe",
        display_dob: "10/10/1990"
      )

      assert search.valid?
      assert_equal Date.new(1990, 10, 10), search.parsed_dob
    end

    test "accepts dob with dashes" do
      search = CustomerPiiSearch.new(
        first_name: "Jane",
        last_name: "Doe",
        display_dob: "10-10-1990"
      )

      assert search.valid?
      assert_equal Date.new(1990, 10, 10), search.parsed_dob
    end

    test "accepts dob in iso format" do
      search = CustomerPiiSearch.new(
        first_name: "Jane",
        last_name: "Doe",
        display_dob: "1990-10-10"
      )

      assert search.valid?
      assert_equal Date.new(1990, 10, 10), search.parsed_dob
    end

    test "rejects invalid dob format" do
      search = CustomerPiiSearch.new(
        first_name: "Jane",
        last_name: "Doe",
        display_dob: "not-a-date"
      )

      assert_not search.valid?
      assert_includes search.errors[:display_dob], "Enter a valid date"
    end
  end
end
