# frozen_string_literal: true

class PasswordRequirements
  Requirement = Data.define(:key, :label)

  COMMON_PASSWORDS = %w[
    password password123 12345678 qwerty123 admin123
    welcome1 letmein1 Password1 Qwerty123 Admin123
    pass123 passw0rd Passw0rd Welcome123
  ].freeze

  COMMON_WORDS = %w[password pass admin welcome letmein].freeze

  KEYBOARD_PATTERNS = %w[
    qwerty qwertyui asdfgh asdfghjk zxcvbn zxcvbnm
    qwert asdf zxcv 1qaz 2wsx
    !qaz @wsx
  ].freeze

  SIGNUP = [
    Requirement.new(key: :min_length, label: "8+ characters"),
    Requirement.new(key: :lowercase, label: "Lowercase"),
    Requirement.new(key: :uppercase, label: "Uppercase"),
    Requirement.new(key: :digit, label: "Number"),
    Requirement.new(key: :no_common, label: "Not common"),
    Requirement.new(key: :no_sequential, label: "No sequences"),
    Requirement.new(key: :no_repeated, label: "No repeats"),
    Requirement.new(key: :no_keyboard, label: "No keyboard rows"),
    Requirement.new(key: :confirmation_match, label: "Passwords match")
  ].freeze

  class << self
    def signup_requirements = SIGNUP

    def checks(password, confirmation: nil)
      pwd = password.to_s
      lower = pwd.downcase
      confirmation = confirmation.to_s

      {
        min_length: pwd.length >= User::MIN_PASSWORD_LENGTH,
        lowercase: pwd.match?(/[a-z]/),
        uppercase: pwd.match?(/[A-Z]/),
        digit: pwd.match?(/\d/),
        no_common: pwd.present? && !common_password?(pwd) && !common_word?(pwd),
        no_sequential: pwd.present? && !sequential?(lower),
        no_repeated: pwd.present? && !repeated?(pwd),
        no_keyboard: pwd.present? && !keyboard?(lower),
        confirmation_match: pwd.present? && confirmation.present? && pwd == confirmation
      }
    end

    def common_password?(password)
      COMMON_PASSWORDS.any? { |candidate| password.downcase == candidate.downcase }
    end

    def common_word?(password)
      lower = password.downcase
      COMMON_WORDS.any? { |word| lower.include?(word) }
    end

    def sequential?(password_lower)
      password_lower.match?(/012|123|234|345|456|567|678|789|890/) ||
        password_lower.match?(/abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz/) ||
        password_lower.match?(/987|876|765|654|543|432|321|210/)
    end

    def repeated?(password)
      password.match?(/(.)\1{2,}/)
    end

    def keyboard?(password_lower)
      KEYBOARD_PATTERNS.any? { |pattern| password_lower.include?(pattern) }
    end
  end
end
