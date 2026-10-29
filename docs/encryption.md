# Active Record encryption

PII at rest uses [Active Record encryption](https://guides.rubyonrails.org/active_record_encryption.html).
Keys are stored in Rails credentials (`active_record_encryption`), not in plain-text env files.

## Keys

Generate a fresh set:

```bash
bin/rails db:encryption:init
```

Add the output to each environment's credentials (`bin/rails credentials:edit` or
`--environment production`). See `config/credentials.example`.

All environments require encryption keys in credentials; the app raises on boot if they are missing.

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

## New models (product rewrite)

When adding customer-facing models (queue, appointments, etc.), encrypt PII in the same migration
that adds the column. Follow the old app's pattern:

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
