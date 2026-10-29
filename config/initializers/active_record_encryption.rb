# frozen_string_literal: true

# Keys live in Rails credentials under active_record_encryption (see config/credentials.example).
# Generate with: bin/rails db:encryption:init
Rails.application.configure do
  creds = Rails.application.credentials.active_record_encryption
  primary_key = creds&.primary_key
  deterministic_key = creds&.deterministic_key
  key_derivation_salt = creds&.key_derivation_salt

  # assets:precompile runs in the Docker build stage without RAILS_MASTER_KEY,
  # so credentials can't be decrypted yet. SECRET_KEY_BASE_DUMMY marks that boot.
  if [ primary_key, deterministic_key, key_derivation_salt ].any?(&:blank?) && ENV["SECRET_KEY_BASE_DUMMY"].blank?
    raise <<~MSG.squish
      Missing active_record_encryption credentials (primary_key, deterministic_key, key_derivation_salt).
      Run `bin/rails db:encryption:init` and add the output to credentials.
    MSG
  end

  config.active_record.encryption.primary_key = primary_key
  config.active_record.encryption.deterministic_key = deterministic_key
  config.active_record.encryption.key_derivation_salt = key_derivation_salt

  # Fixture inserts and legacy plaintext rows remain readable in dev/test until re-encrypted.
  config.active_record.encryption.support_unencrypted_data = Rails.env.local?
end
