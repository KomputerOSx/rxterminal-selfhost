# frozen_string_literal: true

# Keys come from ACTIVE_RECORD_ENCRYPTION_* env vars. In production bin/docker-entrypoint
# generates them into storage/secrets.env on first boot. Losing them makes encrypted
# patient data unreadable. Generate manually with: bin/rails db:encryption:init
Rails.application.configure do
  keys = {
    primary_key: ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"],
    deterministic_key: ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"],
    key_derivation_salt: ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
  }

  # Fixed keys for development and test only. Never used in production.
  if Rails.env.local?
    keys[:primary_key] ||= "dev-only-primary-key-0123456789abcdef"
    keys[:deterministic_key] ||= "dev-only-deterministic-key-0123456789"
    keys[:key_derivation_salt] ||= "dev-only-key-derivation-salt-0123456789"
  end

  # assets:precompile runs in the Docker build stage with no secrets.
  # SECRET_KEY_BASE_DUMMY marks that boot.
  if keys.values.any?(&:blank?) && ENV["SECRET_KEY_BASE_DUMMY"].blank?
    raise <<~MSG.squish
      Missing ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY, ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
      or ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT. Run `bin/rails db:encryption:init`
      and set them in .env, or boot through bin/docker-entrypoint to generate them.
    MSG
  end

  config.active_record.encryption.primary_key = keys[:primary_key]
  config.active_record.encryption.deterministic_key = keys[:deterministic_key]
  config.active_record.encryption.key_derivation_salt = keys[:key_derivation_salt]

  # Fixture inserts and legacy plaintext rows remain readable in dev/test until re-encrypted.
  config.active_record.encryption.support_unencrypted_data = Rails.env.local?
end
