# frozen_string_literal: true

require "test_helper"

class Billing::TaxTest < ActiveSupport::TestCase
  test "collect_vat? is false when credential is unset" do
    Rails.application.credentials.stub(:dig, nil) do
      assert_not Billing::Tax.collect_vat?
    end
  end

  test "collect_vat? reads stripe.collect_vat from credentials" do
    dig = ->(root, *keys) { root == :stripe && keys == [ :collect_vat ] ? true : nil }

    Rails.application.credentials.stub(:dig, dig) do
      assert Billing::Tax.collect_vat?
    end
  end
end
