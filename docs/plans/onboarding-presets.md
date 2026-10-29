# Onboarding presets & trial-plan alignment

Business-type presets for onboarding, how they interact with `Billing::Plans` limits, and a
trial-default change this plan depends on. Nothing in this document is built yet.

## Contents

- [1. Overview](#1-overview)
- [2. Current state](#2-current-state)
- [3. Business-type presets](#3-business-type-presets)
- [4. Post-onboarding checklist](#4-post-onboarding-checklist)
- [5. "See it live" preview step](#5-see-it-live-preview-step)
- [6. Demo activity data](#6-demo-activity-data)
- [7. Trial-default change](#7-trial-default-change)
- [8. Starter/Business plan shape](#8-starterbusiness-plan-shape)
- [9. Phasing](#9-phasing)
- [10. Open questions](#10-open-questions)
- [11. Roadmap (not built yet)](#11-roadmap-not-built-yet)

---

## 1. Overview

New organizations finish `OnboardingController`'s 5-step flow (welcome → profile → organization →
time_zone → finish) to a completely empty dashboard: zero services, zero staff, zero upsell
rules. This plan adds a business-type selection step that seeds starter `Service`/`UpsellRule`
data, previews the org's live kiosk/portal before handoff, and gives the new org a persistent
checklist instead of dropping them cold onto an empty dashboard.

Doing this surfaced a separate, more consequential finding: every real signup currently trials on
**Starter** limits, not Business, so nobody sees the appointments/kiosk feature set that's supposed
to be the paid-tier differentiator until they manually find the plan-switch control. §7 and §8
cover that fix, which this plan's presets depend on to be worth building at all - a preset that
seeds an appointment-capable service is wasted if the org previewing it can't turn appointments on.

## 2. Current state

- `Onboarding::STEPS` (`app/models/onboarding.rb`) is a plain `Step` struct array; `OnboardingController`
  walks it linearly with no branching and no per-org data seeding beyond the fields the user types
  into the `organization`/`time_zone` steps.
- `Organization` has no business-type, industry, or vertical field of any kind (checked
  `db/schema.rb` - the closest existing columns are `category` on `email_campaigns`/`notifications`,
  unrelated).
- `Service` (`app/models/service.rb`) already carries everything a preset needs to prefill:
  `internal_name`, `display_name`, `icon`, `estimated_duration`, `price`, `allows_immediate`,
  `requires_appointment`, `eligibility_requirements`, `display_order`, `featured`.
- `UpsellRule`/`UpsellTemplate` already support the full data a demo rule needs (`trigger_service`,
  `suggested_service`, `frequency_type`, `cooldown_days`, `visit_type`, a nested template with
  `title`/`cta_text`).
- `Organization#bookable_times`/`operating_hours` are plain `json` columns with no default beyond
  `{}` - a new org's calendar is unset until someone fills it in manually.
- `Kiosk::PreviewMode` (`app/controllers/concerns/kiosk_preview_mode.rb`) already exists and is the
  mechanism §5 reuses rather than building new preview infrastructure.
- Plan limits live in `Billing::Plans::STARTER_LIMITS`/`BUSINESS_LIMITS`
  (`app/models/billing/plans.rb`) and are enforced via `PlanLimitEnforcement`
  (`app/controllers/concerns/plan_limit_enforcement.rb`). Starter: 1 user, 3 services, 1 upsell
  rule, 200 monthly requests, `appointments_enabled: false`, `kiosk_enabled: false`,
  `calendars_enabled: false`, `custom_domain: false`. Business: everything unlimited/enabled.
- `Organization#start_no_card_trial_for!` (`app/models/concerns/organization_trial.rb`) defaults
  `plan_key` to `OrganizationTrial::DEFAULT_TRIAL_PLAN_KEY`, which is `Billing::Plans::STARTER.key`.
  The only call site at real signup, `Organization.rb:123` (inside the personal-org creation path),
  calls it with no `plan_key` argument - so every real signup trials on Starter. The one place a
  Business trial is actually granted is `db/seeds.rb:71`, which sets it directly on seed/demo orgs
  only. This asymmetry appears unintentional rather than a deliberate choice.

## 3. Business-type presets

### 3.1 Data model

Add `organizations.business_type` (string, nullable, no default - `nil` means "General/Other" or
skipped). A new `Onboarding::BUSINESS_PRESETS` registry (plain Ruby data, not a DB table - these
are seed templates, not per-org configurable records) keyed by type:

```ruby
{
  clinic:        { label: "Medical/Clinic", ... },
  salon:         { label: "Salon & Barbershop", ... },
  retail_repair: { label: "Repair/Retail Walk-in", ... },
  public_office: { label: "Government/Public Office", ... },
  general:       { label: "General/Other", ... } # no seed data, current behavior
}
```

Each preset (other than `general`) carries:
- Up to **3** starter `Service` attribute hashes (see §3.3 on why 3, not more).
- One demo `UpsellRule` + nested `UpsellTemplate` wired to two of those services.
- A suggested `bookable_times`/`operating_hours` default (editable immediately after, not locked).
- Portal/kiosk terminology strings (e.g. "patients" vs "clients" vs "customers") - presentation
  only, no schema change beyond storing the chosen key; actual copy swap is a helper concern
  (`PortalPathsHelper`/`KioskHelper` already centralize copy strings, so this is a lookup table
  keyed by `business_type`, not scattered view changes).

### 3.2 New onboarding step

Insert `business_type` into `Onboarding::STEPS` between `organization` and `time_zone` ("What kind
of business is this?" - radio/card picker, `general`/skip always available). `OnboardingController#save_step`
gets a matching `when "business_type"` branch: assigns `organization.business_type`, and if a
non-`general` preset was chosen, calls a new `Onboarding::PresetApplier.new(organization).apply!`
service object (new file, `app/services/onboarding/preset_applier.rb`) that creates the `Service`
and `UpsellRule` records and sets `bookable_times` - kept out of the controller and out of
`Organization` itself, consistent with this app's existing service-object pattern
(`AppointmentCheckInService`, `SlotAvailabilityService`, etc.).

Changing `business_type` later (e.g. from org settings) does **not** re-run the applier - it only
fires once, at onboarding time, same as any other seed action. Re-running it is out of scope here
(see §11).

### 3.3 Plan-limit interaction (the core question this plan answers)

This is where presets meet `Billing::Plans::STARTER_LIMITS`, and per §7 below, Starter limits are
what every new org actually has active at the moment the preset runs:

- **Services (cap: 3).** Each preset ships with exactly 3 auto-created services - the highest-value
  3 for that vertical - not a longer "ideal" list trimmed down at seed time. A clinic preset leads
  with Consultation/Vaccination/Follow-up rather than a 6-service list that would immediately trip
  `Organization#at_service_limit?` for anyone who ends up on Starter after trial. If a preset's
  natural service count is genuinely larger, the extra services are surfaced in onboarding copy as
  "add these when you upgrade" rather than created - never silently created-then-blocked.
  `PresetApplier` must check `organization.at_service_limit?` before each create and stop early
  (defensive; shouldn't trigger given the 3-cap design, but presets are data that will be edited by
  people who aren't reading this doc).
- **Upsell rules (cap: 1).** One demo rule is a deliberate fit, not a compromise - it's enough to
  demonstrate the feature working without needing Business-tier unlimited rules. No truncation
  logic needed here.
- **Kiosk (`kiosk_enabled: false` on Starter).** A preset cannot meaningfully set kiosk-only
  fields (`kiosk_theme`, `kiosk_show_services`, etc.) as the org's primary "see it live" moment
  if kiosk is off for whoever's trialing. See §5 for how the preview step handles this.
- **Appointments (`appointments_enabled: false` on Starter).** Any preset service marked
  `requires_appointment: true` is still created (the *service* isn't gated, only the *booking
  channel* is), but the preset's copy should default new services to `allows_immediate: true`
  where the vertical allows it (e.g. salon walk-ins), so a Starter-limited org's seeded services
  are immediately usable via the queue, not stranded behind a disabled feature.
- **Monthly requests (cap: 200).** Seed data itself doesn't consume this (no `ServiceRequest`s are
  created by the preset, only `Service`/`UpsellRule` config) - only §6's demo activity touches this
  limit, and it's handled separately there.
- **`organization.business_type` itself** has no plan interaction - it's a plain attribute, free on
  every tier.

## 4. Post-onboarding checklist

Replace the current hard "finish" step's redirect-to-empty-dashboard with a dismissible checklist
component on `DashboardController#index` (not a new onboarding step - it should persist and be
re-visitable, unlike the linear onboarding flow it follows). Items, each deep-linking to the
relevant settings page and self-checking off:

1. Review your seeded services (skipped if `business_type` was `general`/skipped)
2. Set your operating hours
3. Invite a teammate (`Org::InvitationsController`) - hidden entirely if `at_member_limit?`, since
   Starter's 1-user cap makes this item actively misleading to show
4. Preview your kiosk/portal (§5)
5. Turn on your first upsell (pre-checked if a preset seeded one)

Storage: a `dashboard_checklist_dismissed_at` timestamp on `User` (mirrors the existing
`onboarding_completed_at` column pattern) - the whole card disappears once dismissed, individual
items don't need their own dismissal state since they're derived from existing org data (has a
service? has a second member? etc.), not separately tracked flags.

## 5. "See it live" preview step

Add a final onboarding step, before "finish," that routes into `Kiosk::PreviewMode` for the org's
own portal - reusing the existing preview mechanism rather than building a new one.

**Starter-trial orgs see the public portal/walk-in link preview, not the kiosk.** Since
`kiosk_enabled: false` on Starter (and, before §7 ships, every new org is Starter-trialed), a step
that always tries to preview kiosk mode is a dead end for most signups. The step must branch on
`organization.kiosk_enabled?`:
- If true (Business trial/plan): preview the actual kiosk check-in screen.
- If false (Starter): preview the public portal walk-in page instead, with an inline note that a
  physical in-store kiosk device is a Business-tier upgrade - turning what would otherwise be a
  dead end into an in-flow upgrade nudge, not a wall.

## 6. Demo activity data

Optional checkbox during onboarding ("Seed some example activity so you can see your dashboard in
action") creates a handful of fake `ServiceRequest`/`Appointment` records, visibly marked as demo
(a banner, plus a one-click "Clear demo data" action).

**Must not consume real plan quota.** Add a `demo: true` boolean column to `service_requests`
(mirrors the existing `Service`/`UpsellRule` pattern of a scope that excludes non-counting records,
e.g. `Service.plan_active`/`counting_toward_plan_limit`) and exclude `demo: true` rows from
whatever scope backs `Organization#at_monthly_request_limit?`. Without this, a brand-new signup on
Starter's 200/month cap burns real trial quota just watching a demo populate the queue - a
first-session bug that would actively undercut the trial rather than showcase the product.

Demo records should be excluded from `Org::AnalyticsController` too, or clearly filtered/labeled
there - real analytics mixed with fake seed data would misrepresent the org's actual first-week
numbers to themselves.

## 7. Trial-default change

Change the real-signup call site (`Organization.rb:123`, inside personal-org creation) from:

```ruby
organization.start_no_card_trial_for!(user) if user.trial_available?
```

to pass `plan_key: Billing::Plans::BUSINESS.key` explicitly, so every new organization's 30-day
no-card trial defaults to Business limits - matching what `db/seeds.rb` already does for internal
demo orgs, just applied to real signups too.

**Why this belongs in this plan and isn't a separate, unrelated change:** the presets in §3, the
checklist in §4, and the preview step in §5 are all significantly less useful if the org previewing
them can't actually turn on appointments or kiosk mode during the very trial period meant to show
off the product. Building richer onboarding on top of a Starter-limited trial means most of what
gets built here is invisible to most users until they separately discover the plan-switch control.

**Downgrade path at trial end already exists.** If an org doesn't convert to a paid Business
subscription, the existing "archive, don't delete" plan-reconciliation flow
(`app/models/concerns/organization_plan_reconciliation.rb`,
`app/controllers/org/organizations_controller.rb` reconciliation actions) already handles stepping
an over-limit org back down to Starter's caps - this plan does not need to add new downgrade
logic, only change which plan the trial itself grants.

## 8. Starter/Business plan shape

Two changes to `Billing::Plans::STARTER_LIMITS`, kept deliberately narrow:

- `max_users: 1` → `2`. A single-seat cap makes Starter unusable for even a two-person operation
  regardless of whether they need appointments/kiosk at all - this is friction unrelated to the
  Business-tier pitch, not a meaningful protection of it.
- `max_services: 3` → `5`. Same reasoning: a walk-in-only shop with 5 simple services shouldn't be
  forced to upgrade just to list what they actually offer, when the real differentiator (scheduled
  appointments, physical kiosk hardware, custom domain) is untouched by this change.

**Deliberately not changing:** `max_upsell_rules` (1), `max_monthly_requests` (200),
`appointments_enabled`/`kiosk_enabled`/`calendars_enabled`/`custom_domain` (all `false` on
Starter). These are the actual Business-tier differentiators and should stay a hard line - loosening
them would blur exactly the distinction this whole plan is trying to sharpen. Widening the request
cap in particular would remove Starter's natural "you're outgrowing this" signal, which is a feature
of the current limit, not a bug.

## 9. Phasing

Suggested build order - each phase is independently shippable and none blocks the others from
being useful, but §7 should land first since it changes what every later phase is actually
demonstrating:

1. **§7 trial-default change** - one-line call-site change, immediately makes every new trial show
   the real product.
2. **§8 Starter limit bump** - independent config change, no migration.
3. **§3 business-type step + presets** - the main body of work: migration, `PresetApplier` service,
   new onboarding step/view, preset registry data.
4. **§5 preview step** - depends on §3 existing (nothing meaningful to preview without seeded
   services) and should branch correctly regardless of whether §7 has shipped yet.
5. **§4 checklist** - can ship independently of §3/§5, degrades gracefully (fewer items relevant)
   if business_type was skipped.
6. **§6 demo data** - lowest priority; needs the `demo:` column/scope work done carefully so it
   can't be shipped as a quick add-on without that safeguard.

## 10. Open questions

- Exact preset content (which 3 services, which demo upsell rule, which copy) needs input from
  someone who knows the target verticals - this doc defines the mechanism, not the final seed data.
- Terminology-swap scope: is "patients/clients/customers" copy-only, or should it extend to
  generated notification/email copy too? Affects how large `Onboarding::BUSINESS_PRESETS` needs to
  be.
- Should `business_type` be changeable post-onboarding from org settings, and if so, does that
  re-offer the preset apply step? Out of scope for this plan (see §11) but worth deciding before
  the picker UI is built, since "one-time only" vs "revisitable" changes the UI copy.

## 11. Roadmap (not built yet)

- **Re-running/switching presets** after initial onboarding (e.g. org realizes they picked the
  wrong business type, or wants to re-seed after clearing test data).
- **CSV import as an alternative onboarding path** for businesses migrating existing
  services/staff lists from a spreadsheet or another tool - a second branch alongside "start from a
  preset," not built here.
- **Full terminology localization system** (a real key-based i18n layer driven by `business_type`)
  rather than the small copy lookup table this plan sketches in §3.1.
