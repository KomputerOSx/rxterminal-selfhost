# RxTerminal rewrite plan

Master checklist for porting product features from `old_repo/rxterminal-rails` onto the new template.
Check boxes as work completes. Reference: `old_repo/rxterminal-rails/RELEASE.md`, `docs/rbac.md`, `docs/design.md`.

---

## Locked decisions

- [x] RBAC: `owner` / `admin` / `user` + Pundit permissions (no namespace-based roles)
- [x] No head office - multi-location staff join each org via invite (admin or co-owner), switch via org picker
- [x] Email-only auth (no username)
- [x] Active Record encryption for all customer/staff PII
- [x] Single app shell (no `/staff` or `/manager` namespaces) - RBAC gates nav and actions
- [x] Production DB: PostgreSQL (primary); SQLite for cache, queue, cable. Dev/test: SQLite everywhere
- [x] Greenfield - no production data migration
- [x] UI: follow `docs/design.md` on every surface; keep it simple; use current DaisyUI semantic colors only (no custom palette yet)
- [x] No service templates - new orgs start with zero services; no admin service publishing
- [x] Org slug: user-editable, globally unique (cannot take a slug already in use); no ODS code or org code
- [x] Kiosk device auth: `device_id` + org `slug` + API key (org identified by slug only)
- [x] All secrets and config values in Rails credentials - not plain text in `deploy.yml` or `.env` (Kamal may `credentials:fetch` at deploy time; only `RAILS_MASTER_KEY` unlocks credentials)
- [x] Password expiry dropped; password history kept (last 10, already in template)
- [x] All product features available on every billing plan for now - tier-based limits come later

---

## Design & UI (all surfaces)

Every new screen and partial must follow `docs/design.md`. Refinements later are fine - until then, treat the design doc as the source of truth.

**Applies to:** authenticated app (queue, appointments, config, admin), kiosk, public portal, waiting display, marketing/landing pages.

**Rules for now (keep simple):**

- [x] DaisyUI `dark` theme + existing semantic tokens only (`base-100`, `base-200`, `base-300`, `primary`, `error`, etc.) - no custom hex colors or new themes
- [x] Custom field classes (`input-field`, `select-field`, `textarea-field`, `checkbox-field`, `radio-field`) - not DaisyUI `input`/`select` classes
- [x] Buttons/badges/cards/tables per design doc (e.g. `card border border-base-300`, no shadows, `btn-sm` for nav actions)
- [x] Material Symbols Outlined for icons (not Lucide from old app)
- [x] Turbo/Stimulus patterns from design doc (modals, confirm-modal, turbo streams)
- [ ] Kiosk + waiting display: touch-friendly sizing/layout allowed, but same colors and component language as the main app
- [ ] Public portal: customer-facing but same token set; org logo/branding only where explicitly configured

**Do not port from old app:** old DaisyUI theme variants (`kiosk_theme` green/warm), Lucide icons, shadow-heavy cards, or namespace-specific styling - rebuild to match the template.

---

## Phase 0 - Platform foundation

### Database & deployment

- [x] Add `pg` gem; keep `sqlite3` for dev/test and secondary DBs
- [x] Update `config/database.yml` - PG primary in production (from credentials), SQLite cache/queue/cable
- [x] Update `config/deploy.yml` - remove plain-text host/IP/email from clear env; fetch via credentials where needed
- [x] Verify Solid Cache / Queue / Cable work against SQLite in production

### Configuration (credentials-first)

- [x] App host, server IP, database URL, ACME email, Kamal registry password, Stripe/OAuth/SMTP, encryption keys - all in credentials
- [x] `AppHost` and mailers read from credentials (ENV override in development only, e.g. ngrok)
- [x] `bin/rails credentials:fetch` task for Kamal `.kamal/secrets` (no plain-text secrets in repo)

### Encryption

- [x] Generate and configure Active Record encryption keys (credentials)
- [x] Encrypt `User` PII: `email` (deterministic), `first_name`, `last_name`, `totp_secret`
- [x] Define encryption policy doc (deterministic vs non-deterministic per field)
- [ ] Add encryption to all new customer-facing models as they are introduced

### Gems & services (from old app)

- [x] `jwt` - kiosk device tokens (gem added; `JwtService` in Phase 2)
- [x] `fuzzy_match` - service/name search (gem added; wired in kiosk/appointments phases)
- [x] `kaminari` - pagination (default 20/page; controllers in Phase 3/7)
- [x] `sentry-ruby` + `sentry-rails` - error tracking (credentials `sentry.dsn`, production only)
- [x] ~~Password expiry~~ - dropped; password history (10) already in template (`User::PASSWORD_HISTORY_LIMIT`)

### Explicit exclusions (do not port)

- [ ] ~~Head office~~ (`HeadOffice`, `HeadOfficeRole`, org picker for head office)
- [ ] ~~Username~~ field and all username-based auth/validation
- [ ] ~~`/staff` and `/manager` namespaces~~
- [ ] ~~Data migration scripts~~
- [ ] ~~Service templates~~ (`ServiceTemplate`, admin publish/unpublish, default services on org create)
- [ ] ~~ODS code / org code~~ (org slug is the only org identifier for kiosk, portal, and routing)

---

## Phase 1 - RBAC for product features

Extend `config/rbac.yml` with product permissions. Map to roles:

| Role | Intended access |
|------|-----------------|
| `owner` | Full org control (settings, billing, devices, config) |
| `admin` | Day-to-day management (services, staff invites, queue config, analytics) |
| `user` | Front-line ops (queue, appointments view/update - no org config) |

### Define permissions

- [x] `app.queue.view` - view live queue and waiting display
- [x] `app.queue.manage` - call, complete, cancel, revert queue entries
- [x] `app.appointments.view` - view appointment list/detail
- [x] `app.appointments.manage` - create, edit, cancel, check-in, no-show
- [x] `app.services.manage` - CRUD services, toggle active, assign staff
- [x] `app.calendars.manage` - CRUD calendars, hours, slot config
- [x] `app.upsells.manage` - CRUD upsell rules and templates
- [x] `app.devices.manage` - provision/revoke kiosk devices (org-scoped, not platform admin)
- [x] `app.kiosk.configure` - branding, homescreen layout, preview, featured service
- [x] `app.analytics.view` - dashboards and stats
- [x] `app.portal.configure` - org slug (portal URL), hours, postcode region, portal printout
- [x] ~~`system.organizations.manage`~~ - dropped; orgs are customer-created, not platform CRUD
- [x] ~~`system.devices.manage`~~ - dropped; devices are org-scoped via `app.devices.manage`
- [x] `system.customer_erasure.manage` - GDPR erasure tool
- [x] `system.subject_access.manage` - GDPR SAR export

### Wire permissions

- [x] Update default role matrices in `config/rbac.yml`
- [x] Add Pundit policies for each new resource
- [x] Update sidebar nav (`shared/_sidebar_nav`) - product links gated by permission
- [x] Move members UI to `/org/members` (sidebar + dedicated page)
- [x] Org settings placeholders moved to dedicated pages (calendars, custom domain, opening hours, appointment booking)
- [ ] Integration tests for permission enforcement per role (deferred to Phase 14)

---

## Phase 2 - Core domain models

Naming: `Organization` (not Organisation). All tables scoped by `organization_id`.

### Services catalog

No global templates. Every org builds its own catalog from scratch.

- [x] `Service` - org-scoped only (no template link); calendar FK deferred to Section 2.3
- [x] New orgs start with **zero services** - no seeds, no admin publishing
- [x] Service CRUD owned by org (owner/admin via `app.services.manage`) - Phase 3 UI
- [x] Service toggle (active/inactive), soft delete
- [x] ~~Staff-to-service assignment~~ - dropped; all org members see all services

### Queue

- [x] `ServiceRequest` - status, queue number, queue date, request type, PII fields encrypted
- [x] Queue number assignment (daily reset per org)
- [x] Status lifecycle: waiting → in_progress → completed / cancelled
- [x] Undo/revert completed and cancelled (model methods; UI in Phase 3)
- [x] Average wait time calculation
- [x] PII redaction fields (`pii_redacted_at`) for retention job
- [x] Privacy mode flag per request (`privacy_requested`)
- [x] Turbo Stream broadcasts (Phase 4)
- [x] Optimistic updates + skeleton placeholders on queue actions (ported from old_repo)

### Calendars & appointments

- [x] `Calendar` - org-scoped, default + named, archive flag
- [x] New orgs start with a **default calendar** (auto-created on signup; cannot be archived or deleted)
- [x] `Appointment` - encrypted PII, links to service/calendar/service_request
- [x] `SlotAvailabilityService` - available slot computation
- [x] Booking window (`appointment_days_ahead` on org); service eligibility via `eligibility_requirements`
- [x] Check-in, no-show, cancel flows (model methods; UI in Phase 3)
- [x] ICS file generation for confirmations (`AppointmentCalendarExport`; mailer attachments + public portal download)

### Upsells

- [x] `UpsellRule` - trigger service → suggested service
- [x] `UpsellTemplate` - title, description, CTA copy
- [x] `UpsellCounter` - daily conversion counts
- [x] `UpsellInteraction` - anonymised interaction log
- [x] `UpsellEngine` service - rule evaluation and outcome routing

### Devices (kiosk)

- [x] `Device` - public `device_id`, API key digest, JWT token_version, IP pin, status lifecycle
- [x] Kiosk auth inputs: **device_id + organization slug + API key** (model/service ready; API in Phase 5)
- [x] `JwtService` - encode/decode device tokens (claims include org slug + device)
- [x] Device provisioning UI (org-scoped, permission-gated) - Phase 3
- [x] Kiosk session cookie (encrypted JWT) - Phase 5

### Org settings extensions

- [x] **Org slug** - editable by owner/admin (slug exists; edit UI in Phase 3/6)
- [x] Slug drives public portal URL (`/:slug`), custom domain routing, and kiosk device auth - Phase 6/5
- [x] No ODS code, no separate org code field
- [x] Partial appointment settings: `bookable_times`, `appointment_slot_minutes`, `appointment_days_ahead`, `kiosk_collect_postcode`
- [x] Default `operating_hours` and `bookable_times` on new orgs
- [x] `postcode_region` (uk/us/ca/au)
- [x] Kiosk homescreen toggles + `kiosk_featured_service` FK; `kiosk_logo` (Active Storage)
- [x] `open_on?` / `open_now?` helpers on `Organization`
- [x] Kiosk logo/homescreen **UI** - Phase 3
- [x] Opening hours **UI** - Phase 3 (page at `/org/opening_hours`)
- [x] Portal printout / QR page - Phase 3 (staff UI; public portal in Phase 6)

---

## Phase 3 - Staff-facing UI (unified app shell)

Build under current template layout (`application.html.erb` drawer shell). No new namespaces.

**Design:** every view/partials in this phase must conform to `docs/design.md` and the Design & UI section above.

### Navigation & dashboard

- [x] Product section in sidebar (Queue, Walk-in, Services linked; other product pages pending)
- [x] Role-appropriate dashboard landing (owner/admin vs user)

### Queue dashboard

- [x] Live queue view (Waiting / In Progress columns)
- [x] Call next, per-entry actions (call, complete, cancel, revert)
- [x] Filter by service (all org members see all services)
- [x] Queue refresh / poll fallback endpoint
- [x] Cross-screen refresh broadcast (queue + waiting display) — see Phase 4
- [x] Reset wait timer (org feature flag: `waiting_time` - not billing-tier gated during rewrite)
- [x] Walk-in create form (staff-initiated)
- [x] Upsell step in staff walk-in flow (book later placeholder until appointments UI)

### Waiting area display

- [x] Full-screen waiting display page (design: `docs/design.md` tokens; large typography OK, same colors)
- [x] Persistent display token (staff stamps once, 30-day cookie)
- [x] Real-time updates + poll fallback
- [x] Service filter, average wait badge

### Appointments (staff)

- [x] Today's appointments list
- [x] Create/edit/cancel/check-in/no-show
- [x] Print day view
- [x] Slot picker (AJAX/turbo)
- [x] Search preview

### Configuration (owner/admin permissions)

- [x] Services CRUD + reorder
- [x] Calendars CRUD + archive
- [x] Upsell rules CRUD + reorder + toggle
- [x] Kiosk customization (branding, layout, featured service)
- [x] Org settings: portal printout, features opt-in
- [x] Opening hours UI (page at `/org/opening_hours`)
- [x] Appointment booking settings UI (page at `/org/appointment_booking`)
- [x] Devices list + provision/regenerate key/revoke
- [x] Analytics dashboard
- [x] Portal printout page

### Stats

- [x] Requests per day, wait time, upsell conversion, service breakdown
- [x] Hourly heatmap

---

## Phase 4 - Real-time (ActionCable)

- [x] `QueueChannel` - org-scoped subscription
- [x] Turbo Stream broadcasts on `ServiceRequest` create/update/destroy
- [x] Separate streams for queue dashboard vs waiting display
- [x] Stimulus/Turbo reconnect + poll fallback when cable drops
- [x] Tests: channel authorization scoped to org membership
- [x] Tests: queue live sync integration (`org_queue_live_sync_test`)
- [x] Optimistic updates + skeleton placeholders on queue actions (ported from `old_repo`)
- [x] Queue mutation responses defer to broadcasts (`head :ok`; no full card-container replace on actions)
- [x] Queue card placement rules: in-progress append (bottom), waiting prepend (top) on return/revert
- [x] Keyboard shortcuts (`keyboard_nav_controller` — navigation, call next, complete, refresh, undo)
- [x] Voice announcements (`voice_announcement_controller` — toggle, auto-call on in-progress, manual recall)
- [x] New-customer sound alerts (`sound_alert_controller` — beep on new IDs only, not returns to waiting)
- [x] `POST /org/queue/refresh` — broadcasts full state to all queue dashboards and waiting displays
- [x] Queue mutation audit logs: `customer_called`, `customer_status_updated`, `customer_reactivated`, `customer_reverted`, `wait_timer_reset`
- [x] Tests: queue manage actions create audit logs (`org_queue_test`)

---

## Phase 5 - Kiosk UI

Separate minimal layout (touch-optimised, full-screen). JWT device auth, not staff session.

**Design:** Recreate old kiosk screen structure from `old_repo`, but style with DaisyUI semantic tokens only (`primary`, `success`, `accent`, `base-*`) — no custom `kiosk-*` CSS. Per-org theming via `data-theme` on the kiosk layout.

- [x] Kiosk layout (`layouts/kiosk.html.erb`) — full-screen, semantic tokens, theme hook via `data-theme`
- [x] Kiosk setup flow (device ID + API key entry, first auth, IP capture)
- [x] `/api/v1/device_auth` endpoint (device_id + api_key → JWT)
- [x] Home screen (featured service, services list; appointments button stubbed)
- [x] Services list + service choose screen (walk-in form next)
- [x] Device auth audit logs (`device_auth_success`, `device_auth_failure`)
- [x] Tests: kiosk setup + API device auth
- [x] Service search + walk-in service request form (name, DOB, postcode)
- [x] Upsell screen (accept / book later / decline)
- [x] Appointment booking flow (calendar, slots, confirmation)
- [x] Appointment check-in flow
- [x] Kiosk idle timer (overlay on flow screens, auto-submit on upsell, auto-redirect on confirmation/result screens)
- [x] Kiosk preview mode (staff walks the real kiosk flow without a physical device; no queue/appointment writes)

---

## Phase 6 - Public portal

Two entry points: org slug (`/:slug`) and custom domain (`CustomDomainConstraint`).

**Design:** customer-facing `public` layout with DaisyUI tokens and form/button conventions from `docs/design.md`.

### Routing

- [x] Slug-based public routes under `/:organization_slug` (constraint excludes reserved words)
- [x] Custom domain routes serve same portal controllers
- [x] Master switch: `public_portal` feature flag

### Portal features (each feature-flagged)

- [x] Privacy consent gate (online portal flows only)
- [x] Online appointment booking (`online_appointment_booking`)
- [x] Mobile walk-in / service request (`mobile_service_request`)
- [x] Appointment check-in via QR (`online_appointment_check`)
- [x] Walk-in upsell flow
- [x] ICS download on confirmation
- [x] Signed tokens for walk-in QR / my-queue links
- [x] Rack::Attack throttles on public appointment POST + calendar/slots GET
- [x] Legal pages (privacy, GDPR, terms, cookies) - per portal or shared

### Feature flags (product)

Org-level toggles only (admin grant + manager opt-in). **Not** gated by billing plan during rewrite - all plans get full product access for now.

Add to `config/features.yml` (or equivalent):

- [x] `waiting_time`
- [x] `public_portal`
- [x] `online_appointment_booking`
- [x] `mobile_service_request`
- [x] `online_appointment_check`

---

## Phase 7 - Admin extensions (platform)

Extend existing `Admin::` namespace. Use `system.*` permissions.

- [x] Customer erasure tool (GDPR soft redaction via `PiiRedactable`)
- [x] Subject access request (SAR) export
- [x] Shared search UI: first/last name + DOB + optional postcode; optional org filter table
- [x] CSV download + optional email via `CustomerPiiReportMailer`
- [x] Audit events: `customer_pii_redacted`, `customer_pii_report_exported`, `subject_access_exported`
- [x] Org contact fields on settings (supports GDPR org picker)

---

## Phase 8 - Background jobs

- [x] `AppointmentReminderJob` - email before appointment
- [x] `AppointmentNoShowJob` - mark no-shows after slot time
- [x] `DataRetentionJob` - redact customer PII after retention period
- [x] `CleanupExpiredSessionsJob` - already may exist; verify
- [x] Recurring schedule in `config/recurring.yml` or Solid Queue config

---

## Phase 9 - Mailers

- [x] `AppointmentMailer` - confirmation + reminder + ICS (+ staff resend confirmation)
- [x] `ContactMailer` - marketing contact form (enquiry to team + sender confirmation)
- [x] `CustomerPiiReportMailer` - GDPR CSV email delivery (erasure + SAR)
- [x] Unified branded layout - `MailerTheme`, shared header/footer partials, powered-by footer on all transactional mailers
- [x] Reuse existing: password reset, two-factor, invitation, email change, account deletion, ownership promotion/demotion mailers (ported to shared layout)

---

## Phase 10 - Marketing & public site

Old app had standalone marketing pages. Decide scope vs minimal landing.

**Design:** marketing uses the `landing` layout with ported `old_repo` wire styling (light paper theme, Mogilte display font) — not the authenticated app’s dark DaisyUI shell. CTAs point to free trial (`new_registration_path`).

- [x] Landing page (`home#index`, `landing` layout, sticky nav, hero, features, security, footer)
- [x] Pricing page (`pricing#index` — Starter £9.99 / Growth £29.99 from `Billing::Plans`)
- [x] Contact form (`contact#new/create/sent` — `ContactMailer` enquiry + confirmation)
- [x] Contact spam protection (`ContactSpamGuard` — honeypot fields, session form token, minimum submit delay; no third-party CAPTCHA)
- [x] Signup password requirements — live checklist on registration (`PasswordRequirements` + Stimulus)
- [ ] Blog (`BlogPost` model + admin CRUD) - optional
- [ ] Demo flow (`DemoController` interactive preview) - optional
- [ ] Legal pages on root domain (`/terms`, `/privacy-policy`, etc. — portal legal pages exist; top-level routes not wired)
- [ ] Sitemap, PWA manifest (routes exist commented-out in template)

---

## Phase 11 - Privacy, audit & compliance

- [ ] Privacy consent persistence/tracking (online portal consent gate exists from Phase 6; verify audit trail if needed)
- [x] Customer erasure service (`CustomerPiiLookup`, `CustomerPiiRedaction`, admin erasure UI)
- [x] SAR export service (`SubjectAccessRequestExport`, admin SAR UI)
- [x] `AuditLog` event types for erasure and SAR export (queue, appointments, devices covered in Phases 3–5)
- [x] Shared audit logging concern — auto-injects `organization_id` via `AuditLogging` (`Current.organization` / `@organization`)
- [x] Org-scoped audit log viewer (`app.audit_logs.view`, limited to current organization)
- [x] Data retention — hardcoded 90-day job in Phase 8 (config deferred)

---

## Phase 12 - Billing & plan limits (deferred)

Do **after** core product is working. Skip during initial rewrite.

- [ ] Map product capabilities to Free / Starter / Growth tiers
- [ ] Re-enable or add plan checks (`Organization#current_plan`, member limits, custom domain, etc.)
- [ ] Gate UI and controller actions by plan where needed
- [ ] Update pricing page and billing docs to match final tier matrix
- [ ] Integration tests for plan enforcement

**For now:** leave existing billing infrastructure in place but do not block product features by plan.

---

## Phase 13 - Invitations & multi-org workflow

- [ ] Invite flow assigns `admin` or `user` role (existing invite = `user`; extend if needed)
- [ ] Co-owner promotion flow (existing `promote_to_owner` - verify for multi-location owners)
- [ ] Org switcher works across all member orgs (existing - verify with product routes)
- [ ] Document: former head-office staff workflow = invited as admin to each location

---

## Phase 14 - Testing

- [ ] Model tests for all new domain models
- [ ] Service tests: `SlotAvailabilityService`, `UpsellEngine`, `JwtService`
- [ ] Integration tests per permission (owner/admin/user denied/allowed)
- [ ] Queue live sync / Turbo Stream tests
- [ ] Kiosk auth + device API tests (slug + device_id + api_key)
- [ ] Public portal flow tests (walk-in, booking, check-in)
- [ ] Encryption: deterministic lookup still works (email, DOB search)
- [x] Marketing pages integration tests (`marketing_pages_test` — pricing, contact form, spam guard)
- [x] Contact spam guard unit tests (`contact_spam_guard_test`)
- [ ] Load tests directory (`load_tests/`) - port or rewrite if still wanted

---

## Phase 15 - Production readiness

- [ ] PG connection pooling / `DATABASE_URL` in Kamal
- [ ] SQLite files on persistent Docker volumes (cache, queue, cable)
- [ ] SMTP / email delivery configured
- [ ] Sentry DSN configured
- [ ] SSL: app host + custom domains (Caddy on-demand TLS - existing)
- [ ] Rack::Attack rules for login, public portal, device auth
- [ ] Health check `/up` (existing)
- [ ] First deploy checklist: migrations, `rbac:grant_system_admin`, Stripe, encryption keys
- [ ] Remove or update `old_repo` reference when no longer needed

---

## Phase 16 - Documentation

- [ ] Update README (run instructions, DB setup dev vs prod)
- [x] Product permissions section in `docs/rbac.md`
- [ ] Keep `docs/design.md` updated when UI conventions change during the rewrite
- [x] Encryption setup in docs (`docs/encryption.md`)
- [ ] Kiosk device provisioning guide (slug + device ID + API key)
- [ ] Org slug editing rules (uniqueness, reserved words)
- [ ] Public portal / feature flags guide
- [ ] Mark completed sections in this file as the source of truth for progress

---

## Suggested build order

Work top-to-bottom within phases, but this sequence reduces blocked dependencies:

1. Phase 0 (DB, encryption, gems)
2. Phase 1 (RBAC permissions)
3. Phase 2: Services → ServiceRequest (queue) → Calendar/Appointment → Upsells → Devices
4. Phase 4 (real-time) alongside Phase 3 queue UI
5. Phase 3 staff UI (queue first, then appointments, then config)
6. Phase 5 (kiosk)
7. Phase 6 (public portal)
8. Phase 7-11 in parallel as needed
9. Phase 14-16 before launch
10. Phase 12 (billing tier limits) after product MVP

---

## Progress summary

| Phase | Status |
|-------|--------|
| Design & UI (cross-cutting) | Complete (org + admin audited; marketing uses separate landing layout) |
| 0 - Platform foundation | Complete |
| 1 - RBAC | Complete (integration tests deferred) |
| 2 - Domain models | Complete |
| 3 - Staff UI | Complete |
| 4 - Real-time | Complete |
| 5 - Kiosk | Complete |
| 6 - Public portal | Complete |
| 7 - Admin extensions | Complete |
| 8 - Background jobs | Complete |
| 9 - Mailers | Complete |
| 10 - Marketing site | Partial (landing, pricing, contact, signup password UI done; root legal, blog, demo pending) |
| 11 - Privacy & audit | Partial (erasure + SAR + org audit logs + org-scoped metadata; privacy consent audit deferred) |
| 12 - Billing & plan limits (deferred) | Deferred |
| 13 - Multi-org workflow | Not started |
| 14 - Testing | Partial (GDPR + core product + marketing tests exist) |
| 15 - Production readiness | Not started |
| 16 - Documentation | Partial (`rbac.md`, `encryption.md` done) |

*Last updated: 2026-07-18 (Phase 9 mailers + Phase 10 marketing pages complete)*
