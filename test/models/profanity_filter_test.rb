require "test_helper"

class ProfanityFilterTest < ActiveSupport::TestCase
  test "matches a blocklisted word on its own" do
    assert ProfanityFilter.match?("shit")
  end

  test "matches a blocklisted word embedded in a longer name or slug" do
    assert ProfanityFilter.match?("Big Cunt Ltd")
    assert ProfanityFilter.match?("big-cunt-ltd")
  end

  test "matches leetspeak substitutions" do
    assert ProfanityFilter.match?("f4ggot")
    assert ProfanityFilter.match?("$hit")
  end

  test "is case-insensitive" do
    assert ProfanityFilter.match?("FUCK")
  end

  test "collapses stretched-out repeated characters" do
    assert ProfanityFilter.match?("fuuuuck")
    assert ProfanityFilter.match?("shiiiit")
  end

  test "folds Cyrillic look-alike letters to their Latin equivalents" do
    assert ProfanityFilter.match?("сunt") # Cyrillic "с" standing in for latin "c"
  end

  test "folds stylized/fullwidth unicode letters via NFKC normalization" do
    assert ProfanityFilter.match?("ｆｕｃｋ") # fullwidth "fuck"
  end

  test "does not flag allowlisted words that contain a blocklisted substring" do
    assert_not ProfanityFilter.match?("Scunthorpe Consulting")
    assert_not ProfanityFilter.match?("Classy Assistants")
  end

  test "does not flag business names that innocently contain 'rape' or 'dick'" do
    assert_not ProfanityFilter.match?("Riverside Therapy Clinic")
    assert_not ProfanityFilter.match?("Dickinson Family Dental")
    assert_not ProfanityFilter.match?("Grapevine Wine Bar")
  end

  test "does not flag business names that innocently contain 'arse'" do
    assert_not ProfanityFilter.match?("Arsenal Barbers")
    assert_not ProfanityFilter.match?("Coarse Hair Salon")
  end

  test "does not flag ordinary text" do
    assert_not ProfanityFilter.match?("Acme Hair Salon")
    assert_not ProfanityFilter.match?("")
    assert_not ProfanityFilter.match?(nil)
  end
end
