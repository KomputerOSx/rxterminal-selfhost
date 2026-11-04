# Self-host conversion: handover

> **Current status (2026-11-04):** Phases 0-5 are done and Phase 7 is prepared. **Phase 6 (patient
> payments) is deliberately out of v1.0** and the `stripe` gem and `STRIPE_*` settings were removed.
> What remains is on you: see "Before v1.0.0" at the bottom. Older sections below are history; where
> they say "not done", check this note first.

Status as of 2026-10-29. Goal: turn RxTerminal from a hosted multi-customer service into an
open-source app that one pharmacy or clinic runs on its own server (`docker compose up`).
The full plan has 8 phases (0-7); this file records what is done, what is not, and what to
watch out for. The plan text itself is the source of truth for scope.

## Repository and git state

- Remote: `git@github.com:KomputerOSx/rxterminal-selfhost.git`. `origin/main` is a single clean
  commit `6993bfa` ("Initial commit", fresh history, force-pushed). The old history, which held
  the encrypted production credentials and server details, is no longer on the branch.
  GitHub may still serve the old commit `dd46bc9` by hash and forks keep it: ask GitHub support
  to purge it, or delete and recreate the repo before going public.
- Nothing after Phase 0 has been pushed. Local branches are stacked, each built on the previous:

| Branch | Content |
|---|---|
| `main` (local) | `origin/main` plus `62ece69`, a snapshot of partly finished Phase 1 edits (not made by the assistant's commit step). Phase 1 supersedes it. |
| `phase-1-config` | Phase 1: SQLite default, env-var config, secrets bootstrap |
| `phase-2a-remove-billing` | Phase 2a: billing, trials and plan limits removed |
| `phase-2b-feature-flags` (current) | Phase 2b: platform feature flags replaced by a static catalog |

- Intended flow is one pull request per phase, in order. Open them stacked (2b into 2a into 1
  into main), or merge each in turn and rebase.

## Done

### Phase 0: secret hygiene
- Deleted `config/credentials.yml.enc`, `config/credentials/production.yml.enc`,
  `config/credentials.example`, `config/deploy.yml`, `.kamal/`, `config/Caddyfile`, `bin/kamal`,
  the `kamal` gem, `lib/tasks/credentials.rake`, and the Kamal deploy job from
  `.github/workflows/ci.yml` (it held a hard-coded server IP).
- A manual grep for keys and IPs found nothing else. **gitleaks has not been run** (docker was
  not usable in the session). Run `gitleaks detect` or enable GitHub secret scanning before
  making the repo public.
- **Still on you:** rotate every secret that was in the old production credentials (Stripe,
  SMTP, OAuth apps, AWS, Sentry, Kamal registry); the Google/GitHub OAuth apps are no longer used, so delete them.

### Phase 1: database and configuration
- `config/database.yml`: production primary is `storage/production.sqlite3`, or `DATABASE_URL`
  if set. Cache, queue and cable stay SQLite. The `pg` gem is kept.
- All settings now come from environment variables (see `.env.example`): `APP_HOST`,
  `APP_PROTOCOL`, `SMTP_*`, `MAIL_FROM`, `JWT_SECRET_KEY`, `ACTIVE_RECORD_ENCRYPTION_*`,
  `SENTRY_DSN`, `STRIPE_*` (not used until Phase 6).
- `bin/docker-entrypoint` generates missing secrets into `storage/secrets.env` (mode 600) on first
  boot; env vars win over the file. `bin/rails selfhost:show_secrets` prints them. Dev and test
  fall back to fixed non-secret keys (in the encryption initializer and `JwtService`).
- Optional services switch off cleanly: no `SENTRY_DSN` skips
  Sentry, no `SMTP_ADDRESS` logs mail and shows a banner in the admin area.
- Verified: a production boot with only `APP_HOST` set generates secrets, builds the SQLite
  databases, and serves `/login` and `/up`.
- Concurrency check: `test/concurrency/appointment_booking_check.rb` runs five threads booking
  one slot; exactly one wins. It is **not** in the normal suite, because it commits real rows and
  corrupts later tests in the same worker. Run it on its own (CI has a separate step).
  Finding: removing `with_lock` does not fail it, because `save` already runs validation and
  INSERT inside one `BEGIN IMMEDIATE` transaction on SQLite. The test is a regression guard.

### Phase 2a: billing removed
- Deleted billing controllers, models, jobs, views, helpers, policy and concerns; the `pay` gem
  and initializers; trial mailer and job; the pricing page; admin price migrations,
  grandfathering and webhook events; the payment and subscription notification rules.
- Plan limits and plan gating are gone: every limit and gated feature is now unlimited or on.
- Audit-log retention is `AUDIT_LOG_RETENTION_DAYS` (unset keeps everything), applied in
  `DataRetentionJob`.
- RBAC: removed `app.billing.manage` and `system.billing.manage`; added `system.jobs.manage` for
  the Job Inspector (Mission Control).
- Kept on purpose: `SoleOwnerGuard` (blocks the last owner leaving or deleting their account)
  and the ownership-promotion mailer, since neither is billing-specific.
- The `stripe` gem is still in the Gemfile for Phase 6.

### Phase 5 (partly done): debranding, legal templates, user guide (branch `phase-5-debrand`)
- **Matomo analytics to `analytics.strixon.co.uk` removed** from the staff layout (it sent every staff
  page view to the original operator). No third-party analytics remain.
- `AppConfig` (`APP_NAME`, `SUPPORT_EMAIL`, `LOGO_URL`; fallbacks to the primary org) drives titles,
  wordmark, PWA manifest, emails, footer. "Powered by RxTerminal" credit now links to the project repo.
- Legal pages are templates: `config/legal/*.html` with `{{placeholders}}`, rendered by `LegalDocument`
  (sanitised). Operators override by putting a file in `storage/legal/` (or `LEGAL_DIR`); read per
  request. `bin/rails selfhost:legal:export` / `selfhost:legal:status`. The old SaaS terms (Strixon as
  processor, SLA, fees, liability cap) were rewritten as a plain portal Terms of Use. **These are
  templates, not legal advice; the UK GDPR/ICO wording is the default.**
- User guide: billing chapter replaced by "Branding and Legal Pages"; plan limits, trial, custom
  domain, logo review and OAuth sign-up text removed or rewritten.
- Still to do in Phase 5: README, AGPL `LICENSE` (copyright holder not decided), `SECURITY.md`,
  `CONTRIBUTING.md`, `CHANGELOG.md`, delete `docs/rewrite-plan.md`, review `docs/plans/`, trim
  `landing.css`, fix `docs/rbac.md`/`design.md` leftovers. Cookie name `_rxterminal_session` and the
  `RxTerminal-Title*.png` email logos are kept (renaming the cookie logs everyone out).

### Phase 4: Docker and releases (branch `phase-4-docker`) - NOT RUN, see below
- `Dockerfile`: `SOLID_QUEUE_IN_PUMA=true` (jobs run inside the web process), `/rails/storage` created
  and owned by the non-root user and declared a `VOLUME`, `HEALTHCHECK` on `/up`. `/up` is excluded
  from the force-SSL redirect so it answers 200 over plain HTTP inside the container.
- `docker-compose.yml`: `app` (image `ghcr.io/komputerosx/rxterminal-selfhost`, override with
  `RXTERMINAL_IMAGE`, or `build: .`), plus optional profiles `https` (Caddy, `docker/Caddyfile`),
  `backup` (Litestream, `docker/litestream.yml`, replicates `production.sqlite3` only) and `postgres`
  (needs `POSTGRES_PASSWORD` and `DATABASE_URL` in `.env`). `.env` is required (`cp .env.example .env`).
- `.github/workflows/release.yml`: on `v*` tags builds amd64+arm64 and pushes to GHCR (`latest` only
  for tags without a `-`). Dependabot now also watches the Dockerfile.
- **Verified:** `docker compose config` passes for every profile combination; a production boot with
  `SOLID_QUEUE_IN_PUMA=true` runs Solid Queue inside Puma and `/up` returns 200 over plain HTTP.
- **NOT verified (no Docker daemon access in the session):** `docker build`, `docker compose up`,
  the Caddy certificate flow, Litestream replicate/restore, the Postgres profile, and the release
  workflow. Do these in Phase 7. Known gaps: Litestream does not cover uploaded files or
  `storage/secrets.env`; Postgres has not been tried with the baseline migration.

### Phase 3: one business per install (branch `phase-3-single-business`)
- `/setup` (first run, first come first served, deliberately no token): creates the owner, the
  organization and the system admin role in one transaction; every page redirects to it until a
  user exists (`SetupGate`, `Setup.required?`). Race guard: re-check inside the transaction
  (SQLite serialises writes; Postgres takes an advisory lock).
- Open sign-up is closed. `RegistrationsController` and `ConfirmationsController` only work for
  someone holding a valid organization invitation (email forced to the invitation's); invited users
  get no personal organization and skip onboarding. "Sign up" links removed.
- **OAuth removed entirely** (omniauth gems, callbacks controller, helper, initializer, buttons,
  `Identity` model/table, `GOOGLE_*`/`GITHUB_*` env vars). Email + password (plus optional TOTP
  two-factor) is the only sign-in method.
- Creating another organization (branch) requires the system admin role or an owner role.
- **Root portal:** `/` serves the public portal of `Organization.primary` (lowest id), with
  root-relative links (`/appointments`, `/walk-in`, `/arrive`, ...; routes in
  `config/routes/public_portal_root.rb`). Branches keep `/:slug` portals, and `/:slug` still works
  for the primary org too (no redirect was added, so printed QR codes keep working). QR/portal URLs
  and the sitemap for the primary org now point at the root. The root redirects to `/login` when no
  organization exists. `HomeController` is gone.
- `root_path` now means the public portal, so internal "go home" redirects (unauthorized, sidebar
  Dashboard link, notifications) use `dashboard_path`. Words used by root portal paths are reserved
  slugs.
- The root-level legal pages (`/privacy-policy`, `/terms`, ...) are the app-wide ones (still say
  "Strixon Ltd" until Phase 5 templates them); the portal's per-org legal pages exist only under
  `/:slug/`.
- "Admin" labels renamed "Instance settings" (paths remain `/admin`).
- Verified on a fresh production SQLite DB: `/` and `/login` redirect to `/setup`; posting setup
  creates the owner and lands on onboarding; `/setup` then redirects to login; `/` serves the portal;
  `/signup` redirects to login.

### Phase 2f: schema squash (branch `phase-2f-schema-squash`, on top of the simplify branch)
- The 98 migrations are replaced by `db/migrate/20261104000000_baseline_schema.rb`, built from the
  cleaned `schema.rb`. Dropped: `pay_*`, billing event receipts, `features`,
  `feature_organization_accesses`, campaign tables, `organization_logos`, and the billing, trial,
  plan, grandfathering, `custom_domain`, `preferred_currency`, `slug_changed_at` columns on
  `organizations` plus `users.email_preferences` and `users.trial_granted_at`. `organizations.features`
  (the per-org choices) stays.
- Verified: migrating an empty database reproduces `schema.rb` exactly; 789 tests pass; a production
  boot on a fresh SQLite file serves `/up` and `/login` and `/` redirects.
- **Existing databases cannot upgrade to this baseline** (the old migration versions are gone). Only
  fresh installs are supported; the hosted service data is not carried over.
- Also fixed `db/seeds.rb`, which still called the deleted `Billing`/`OrganizationTrial` code.
- The "gutted dev roles" gotcha below is gone for databases built from the baseline; recreate old dev DBs.

### Extra simplifications (branch `simplify-slug-and-logos`, stacked on 2e)
- Removed the 30-day slug change limit (`Organization#slug_change_locked?` etc.; the slug field is
  always editable). The `slug_changed_at` column stays until 2f.
- Removed the logo approval workflow: `OrganizationLogo` model, admin review UI, review mailer and
  reminder job, the three logo notification rules, the `system.organization_logos.manage`
  permission. Logos now upload straight to `organization.kiosk_logo` via
  `PUT/POST/DELETE /org/organization_logo` (one file, PNG/JPEG/GIF/WebP, max 5 MB). Audit events
  are `organization_logo_uploaded` / `organization_logo_removed`.
- Add the `organization_logos` table and `organizations.slug_changed_at` to the 2f drop list.
- Heads-up: changing a slug still breaks old links/QR codes. Phase 3 plans `/<slug>` to `/` redirects.

### Phase 2e: marketing pages removed (branch `phase-2e-marketing-pages`)
- Deleted the landing home page, `pages/features`, `pages/security`, the contact form
  (`ContactController`, `ContactMailer`, `ContactSpamGuard`) and their tests/views.
- `HomeController#index` is now a placeholder: logged in goes to the dashboard, otherwise `/login`.
  Phase 3 replaces it with the real root behaviour.
- **Deviation:** `layouts/landing`, `landing.css` (2.6k lines, mostly now-unused marketing styles),
  and `shared/_public_header`/`_public_footer` are kept because the legal pages still use them.
  Trim `landing.css` and rebrand the header/footer in Phase 5 when the legal pages are templated.
  Header/footer lost the Features/Security/Contact/"Start free trial" links.
- Sitemap lists only legal pages plus portals. Sign-up still exists until Phase 3.

### Phase 2d: email campaigns removed (branch `phase-2d-email-campaigns`)
- Deleted campaign models, job, mailer, admin UI, image upload, the TipTap editor (JS, CSS,
  importmap pins), the public email-preferences page and the profile "Marketing emails" card, the
  `system.email_campaigns.manage` permission and policy, and the campaign audit actions.
- `User#email_preferences` helpers are gone (they only served campaigns). Activity-notification
  preferences (`Notifications`) are separate and stay. The mailer footer lost its campaign variant.
- Tables/columns (`email_campaigns`, `email_campaign_recipients`, `users.email_preferences`) stay until 2f.
- Flaky: `public_portal_test` "walk-in joins beyond the rate limit are throttled" failed once in a
  full parallel run and passed on every rerun; likely shared Rack::Attack cache state.

### Phase 2c: custom domains removed (branch `phase-2c-custom-domains`)
- Deleted the custom-domain constraint, resolver middleware, DNS check, `org/custom_domains`,
  `internal/domain_validations`, `SitesController`, the root-mounted portal routes and the related
  tests and `docs/custom_domain.md`. Portal helpers, robots and sitemaps only handle `/:slug` URLs.
- `AppHost` allows only `APP_HOST`, `localhost`, `127.0.0.1` and their subdomains.
- The `custom_domain` column stays until the 2f schema squash. 822 tests pass.

### Phase 2b: feature flags
- Deleted the `Feature` and `FeatureOrganizationAccess` models, `FeatureRegistry`, its boot
  initializer, and the `/admin/features` area.
- **Deviation from the plan:** the plan said to treat every feature as enabled and delete
  `org/features`. Six of the seven switches (online booking, mobile service request, online
  check-in, opening-times page, contact page, waiting time) are choices the pharmacy makes for
  itself, so they stay. `config/features.yml` is now a static catalog read by `OrgFeature`;
  `FeatureToggleable#feature_enabled?` is true when the feature has no opt-in requirement
  (`public_portal`) or the organization switched it on. Org choices still live in
  `organizations.features`.

### Verification at the tip of `phase-2b-feature-flags`
- `bin/rails test`: 851 runs, 0 failures. `bin/rubocop` clean. `bin/brakeman` 0 warnings.
- A dev server returns 200 for `/login` and `/`.

## Not done

### Rest of Phase 2 (suggested order, one PR each)
1. **2c custom domains (DONE, see above):** `CustomDomainConstraint`, `CustomDomainResolver` middleware,
   `CustomDomainDnsCheck`, `org/custom_domains`, `internal/domain_validations`,
   `config/routes/public_portal_custom_domain.rb`, the JS status controller, the `custom_domain`
   column, plus `Organization#custom_domain_allowed?` (now just returns `true`), the sidebar
   link, `AppHost.allowed_request_host?`, `config.hosts` in production, and the related tests.
2. **2d email campaigns (DONE, see below):** `EmailCampaign`, recipients, `SendEmailCampaignJob`, mailer,
   `admin/email_campaigns`, `email_campaign_images`, the `system.email_campaigns.manage`
   permission. `User#email_preferences` and `EmailCampaign::OPTIONAL_CATEGORIES` are used by the
   profile page: check before deleting.
3. **2e marketing pages (DONE, see below):** `home#index`, `pages/features`, `pages/security`, contact
   (`ContactMailer`, `ContactSpamGuard`), sitemaps, `layouts/landing`, `landing.css`, the
   marketing parts of robots. The public header and footer still link to them.
4. **2f schema squash (DONE, see below):** drop the leftover columns and tables (`pay_*`, `billing_*`,
   `pending_plan_*`, `plan_reconciliation_*`, `trial_*` on organizations and users,
   `grandfathered_at`, `organization_logos`, `slug_changed_at`, `over_member_limit_at`, `stripe_subscription_schedule_id`,
   `preferred_currency`, `custom_domain`, the `features` and `feature_organization_accesses`
   tables, and the campaign tables). Replace `db/migrate/*` with one baseline migration generated
   from the cleaned schema, and check `bin/rails db:prepare` on an empty database.
   Also drop the `trial_granted_at` user column.

### Later phases
- **3 one business per install** (root-URL decision, agreed 2026-11-04: one domain, `APP_HOST`, for
  everything; the public portal moves to `/` so the `/<slug>` prefix disappears, staff use `/login`,
  `/admin` becomes "Instance settings". Keep `/<slug>` redirecting to `/` so printed QR codes and
  arrival links still work. No host-based routing and no separate staff subdomain): close sign-up (remove `RegistrationsController` and routes;
  OAuth only for existing users), first-run `/setup`, branch creation limited to system role or
  owners, rename `/admin` to "Instance settings", new root-URL behaviour.
- **4 Docker and releases (files written, unrun, see above):** `SOLID_QUEUE_IN_PUMA=true`, `docker-compose.yml` with `https`,
  `backup` (Litestream) and `postgres` profiles, Caddyfile, `litestream.yml`, a `/up` healthcheck,
  and a GitHub Actions workflow publishing amd64 and arm64 images to GHCR on `v*` tags.
- **5 debranding, docs, licence:** `APP_NAME`, `SUPPORT_EMAIL`, `LOGO_URL`; remove about 24
  `strixon` and `rxterminal.co.uk` references; template legal pages; README; AGPL-3.0
  `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`; update `docs/user-guide`; delete
  `docs/rewrite-plan.md` and `docs/custom_domain.md`.
- **6 patient payments:** Stripe PaymentIntents per service (`payment_mode`), appointment payment
  columns, webhook, hold expiry job, refunds, tests.
- **7 first public release:** clean-install test on Ubuntu and arm64, CI matrix on SQLite and
  Postgres, tag `v1.0.0`.

## Things to know before continuing

1. **Test-database hygiene.** Anything that commits data outside a transaction (like the
   concurrency check) can leave orphaned rows and make unrelated tests fail at random. If the
   suite acts strangely: `rm -f storage/test*; RAILS_ENV=test bin/rails db:prepare`.
2. **Dev database may have gutted roles.** Dev databases built by running the old migrations can
   have an `owner` or `system_admin` role with almost no permissions (a data migration created the
   role before `RbacRegistry` synced), which hides most of the sidebar. Fix:
   `RbacRegistry.attach_baseline_permissions!(role, keys)` per role from `config/rbac.yml`, or
   reset the dev database. A fresh install (schema load plus seeds) is not affected, and the
   schema squash removes the cause.
3. **Restart the dev server after deleting initializers or models.** A stale server raised
   `uninitialized constant Billing` from the deleted `pay.rb`.
4. **Ruby 4.0.5 and `ostruct`.** Some old tests required `ostruct` and could not load; they were
   billing tests and are gone. Watch for new ones.
5. **`bundle remove` boots Rails** and, as a side effect, once emptied `db/cable_schema.rb` and
   `db/queue_schema.rb` and regenerated `config/credentials.yml.enc`. Check `git status` after
   running Bundler commands. `/config/credentials.yml.enc` is now gitignored.
6. **Never run `git checkout -- .` blindly.** Use `git restore <paths>` after looking at the diff.
7. **Line endings.** `app/views/shared/_sidebar_nav.html.erb` and a few helpers were CRLF and are
   now LF, so their diffs look like whole-file rewrites. Use `git diff -w` or
   `--ignore-space-at-eol` when reviewing.
8. **Encryption keys.** `storage/secrets.env` sits in the same volume as the database. Losing the
   `ACTIVE_RECORD_ENCRYPTION_*` keys makes patient data unreadable, and the README (Phase 5) must
   say so in bold, and say to back the keys up separately from the database.
9. **Setup race and takeover (Phase 3).** `/setup` must create the first user atomically (two
   concurrent requests must not make two owners) and anyone reaching a fresh server first becomes
   the system owner. Consider an optional `SETUP_TOKEN`.
10. **Payment holds (Phase 6).** Never call Stripe inside a database transaction on SQLite (it
    would hold the single write lock during a network call). Handle a `payment_intent.succeeded`
    webhook that arrives after the 15-minute hold expired (rebook if the slot is free, otherwise
    refund).

## How to verify any phase

```
bin/rails test        # whole suite, SQLite
bin/rubocop
bin/brakeman -q --no-pager
bin/rails test test/concurrency/appointment_booking_check.rb   # separately
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner 'Rails.application.eager_load!'
```

A useful check after removing code: boot a production-mode server with only `APP_HOST` set and
request `/login` and `/up`.

## Before v1.0.0 (what is left)

Done in the last pass: README, `LICENSE` (AGPL-3.0, no per-file headers), `SECURITY.md`,
`CONTRIBUTING.md`, `CHANGELOG.md`, stale hosted-service docs deleted, vulnerable gems updated
(`bin/bundler-audit` clean), CI extended with a PostgreSQL job and a Docker smoke job.

**Never run, because this environment had no Docker daemon and no PostgreSQL. CI is the first real
test of each:**
1. `docker compose up --build` end to end (the new `docker-smoke` CI job covers the basic path).
2. Caddy certificate issuance, Litestream backup and restore, the release workflow.
3. The whole suite on PostgreSQL (`test-postgres` CI job, set `continue-on-error: true` until it is
   green; remove that line then). Real PostgreSQL behaviour of the baseline migration is unproven.
4. A clean install on Ubuntu and on arm64.

**Needs a person (outward-facing, not done on purpose):**
1. Push the stacked branches and open pull requests in order (1, 2a-2f, simplify, 3, 4, 5).
   Nothing after Phase 0 has been pushed.
2. Rotate every secret that was in the old production credentials; run gitleaks (a plain grep
   for common key patterns found nothing); get the old commit `dd46bc9` purged from GitHub or
   recreate the repo.
3. Have the legal templates (`config/legal/`) reviewed, and decide the copyright holder wording.
4. Tag `v1.0.0` only after the CI jobs above are green, and fill in the release date in CHANGELOG.
5. Decide what to do with the Dependabot branches on origin.

Known leftovers: `landing.css` (2.6k lines, mostly unused marketing styles) is not trimmed; the cookie
name `_rxterminal_session` and the `RxTerminal-Title*.png` email logos still carry the product name;
one flaky test (walk-in rate limit) failed once in a parallel run.
