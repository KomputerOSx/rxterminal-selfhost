# Active Record encryption

PII at rest uses [Active Record encryption](https://guides.rubyonrails.org/active_record_encryption.html).
Keys are supplied through environment variables (see Keys below).

## Keys

The three keys come from environment variables:

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

In Docker, `bin/docker-entrypoint` generates any missing key on first boot and saves it to
`storage/secrets.env` (inside the data volume). Variables you set yourself take priority over the
file. To print the current values: `bin/rails selfhost:show_secrets`. To generate a set by hand:
`bin/rails db:encryption:init`. Development and test use fixed, non-secret keys.

> **Back these keys up, and keep the backup separate from the database.**
> Without them the encrypted data (patient names, dates of birth, postcodes, staff emails) cannot be
> read, and nothing can recover it. A database backup stored next to `secrets.env` is not a safe
> backup. Copy the three values into a password manager or another secure place as soon as the
> server is running.
>
> Never change the keys on a database that already has data. That makes existing rows unreadable.
> Key rotation is not supported by this project's tooling.

## Field policy

| Field | Model | Type | Why |
| --- | --- | --- | --- |
| `email` | `User` | deterministic | login, uniqueness, lookups |
| `unconfirmed_email` | `User` | non-deterministic | email-change flow; display only |
| `first_name` | `User` | non-deterministic | profile display |
| `last_name` | `User` | non-deterministic | profile display |
| `totp_secret` | `User` | non-deterministic | 2FA secret |
| `first_name`, `last_name`, `postcode`, `description` | `ServiceRequest` | non-deterministic | queue customer PII |
| `dob` | `ServiceRequest` | deterministic | customer identification |
| `first_name`, `last_name`, `postcode`, `email`, `notes` | `Appointment` | non-deterministic | appointment customer PII |
| `dob` | `Appointment` | deterministic | age checks, upsell eligibility |
| `submission_ip` | `ServiceRequest` | **unencrypted** | request metadata, follows the existing unencrypted `audit_logs.ip_address` precedent. Cleared by `redact_pii!` like the other PII fields above. |

**Deterministic** - same plaintext always encrypts the same way; required for `find_by`, unique indexes, and validations that query the column.

**Non-deterministic** - stronger at-rest protection; use when the app never queries by the raw value.

## New models

When adding customer-facing models, encrypt PII in the same migration that adds the column. Follow
the existing pattern:

| Field | Typical type |
| --- | --- |
| `email` | deterministic (if searched) |
| `dob` | deterministic (if searched) |
| `first_name`, `last_name`, `postcode`, `notes`, `description` | non-deterministic |

Document new fields in this file when they are added.

## Local plaintext

`support_unencrypted_data` is enabled in development and test so legacy plaintext rows remain readable until re-encrypted.

Fixture inserts bypass encryption, so the test suite calls `User#encrypt` in `test/test_helper.rb` before each test.

For development databases with existing plaintext users:

```bash
bin/rails encryption:encrypt_users
```
