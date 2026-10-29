# frozen_string_literal: true

# Lightweight substring-based profanity filter for organization names/slugs. This is
# not a substitute for a maintained wordlist gem (e.g. `obscenity`) - it exists to
# catch obvious cases cheaply without adding a dependency. Before matching, text is
# folded down to a plain a-z0-9 string: Unicode is NFKC-normalized (folds stylized/
# fullwidth letters back to ASCII), common Cyrillic look-alike letters are mapped to
# their Latin equivalents (a slug can't contain them - SLUG_FORMAT is ASCII-only -
# but an organization *name* can, and "с" (Cyrillic es) reads identically to "c" while
# being a different codepoint), leetspeak digits/symbols are mapped back to letters,
# runs of 3+ repeated characters are collapsed to one ("fuuuuck" -> "fuck"), and
# everything else (spaces, punctuation) is stripped - so "Big Cunt Ltd", "big-cunt-ltd"
# and "b1g c$$$unt ltd" are all caught the same way.
#
# ALLOWLIST guards against the "Scunthorpe problem": safe words that happen to
# contain a blocked word as a substring (e.g. "Scunthorpe", "assistant", and -
# notably for a clinic/appointment-booking app - "therapist"/"therapy", which
# contain "rape"). It is not exhaustive - substring matching on concatenated text
# can still produce false positives for words we haven't allowlisted yet.
module ProfanityFilter
  BLOCKLIST = %w[
    fuck shit cunt nigger nigga faggot fag retard whore slut bitch bastard
    dick pussy asshole rape paedo pedo cock twat wanker bollocks arse
  ].freeze

  ALLOWLIST = %w[
    class classic classroom classy assassin assistant assess assessment
    associate scunthorpe cockpit cocktail cockerel cumberland shitake
    therapist therapists therapy therapies grape grapes drape drapes
    draper drapery dickens dickson dickinson dickerson arsenal arsenic
    coarse hoarse sparse rehearse
  ].freeze

  LEETSPEAK_SUBSTITUTIONS = {
    "0" => "o", "1" => "i", "3" => "e", "4" => "a", "5" => "s", "7" => "t",
    "@" => "a", "$" => "s", "!" => "i", "+" => "t", "|" => "l"
  }.freeze

  # Cyrillic letters that are visually indistinguishable from Latin ones in most
  # fonts - a classic homoglyph trick for dodging ASCII-based filters.
  CONFUSABLE_SUBSTITUTIONS = {
    "а" => "a", "е" => "e", "о" => "o", "р" => "p", "с" => "c",
    "у" => "y", "х" => "x", "і" => "i", "ѕ" => "s"
  }.freeze

  def self.match?(text)
    normalized = normalize(text)
    return false if normalized.blank?

    BLOCKLIST.any? { |word| flagged_by?(normalized, word) }
  end

  def self.normalize(text)
    folded = text.to_s.unicode_normalize(:nfkc).downcase
    CONFUSABLE_SUBSTITUTIONS.each { |confusable, latin| folded = folded.gsub(confusable, latin) }
    LEETSPEAK_SUBSTITUTIONS.each { |symbol, letter| folded = folded.gsub(symbol, letter) }
    folded = folded.gsub(/(.)\1{2,}/, '\1')
    folded.gsub(/[^a-z0-9]/, "")
  end
  private_class_method :normalize

  # A hit only counts once any allowlisted word it's embedded in has been stripped
  # out of the text - so "assistant" removes itself before we check for "ass"-like
  # blocklist entries, but a bare occurrence of the blocked word still matches.
  def self.flagged_by?(normalized, word)
    return false unless normalized.include?(word)

    remaining = normalized
    ALLOWLIST.each { |safe| remaining = remaining.gsub(safe, "") if safe.include?(word) }
    remaining.include?(word)
  end
  private_class_method :flagged_by?
end
