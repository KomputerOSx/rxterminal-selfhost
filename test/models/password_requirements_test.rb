require "test_helper"

class PasswordRequirementsTest < ActiveSupport::TestCase
  test "checks basic character requirements" do
    checks = PasswordRequirements.checks("Ab1")

    assert_not checks[:min_length]
    assert checks[:lowercase]
    assert checks[:uppercase]
    assert checks[:digit]
  end

  test "checks a strong valid password" do
    password = "Tr8kMvln52"
    checks = PasswordRequirements.checks(password, confirmation: password)

    assert PasswordRequirements.signup_requirements.all? { |req| checks[req.key] }
  end

  test "detects common and pattern failures" do
    checks = PasswordRequirements.checks("Password123", confirmation: "Password123")

    assert_not checks[:no_common]
    assert_not checks[:no_sequential]
  end

  test "confirmation match requires both fields" do
    assert_not PasswordRequirements.checks("Tr8kMvln52", confirmation: "")[:confirmation_match]
    assert PasswordRequirements.checks("Tr8kMvln52", confirmation: "Tr8kMvln52")[:confirmation_match]
  end
end
