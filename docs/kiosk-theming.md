# Kiosk theming

How customer-facing kiosk colors are configured separately from the staff app light/dark theme.

## Overview

| Surface | Theme source | `data-theme` value |
| --- | --- | --- |
| Staff app (`application.html.erb`) | User toggle → `localStorage.theme` | `dark` or `light` |
| Kiosk (`kiosk.html.erb`) | Organization setting → `organizations.kiosk_theme` | Preset slug or `kiosk-custom` |

Kiosk never reads `localStorage.theme`. Staff preferences do not bleed into devices.

## Presets

Registered in `app/assets/tailwind/application.css` via `@plugin "./daisyui-theme.mjs"` blocks:

| Stored value | Resolved `data-theme` | Notes |
| --- | --- | --- |
| `kiosk-default` | `kiosk-default` | **Default** — classic blue/green/amber from legacy kiosk |
| `kiosk-violet` | `kiosk-violet` | Violet/indigo DaisyUI palette |
| `kiosk-pastel` | `kiosk-pastel` | Soft pastel tints |
| `kiosk-cmyk` | `kiosk-cmyk` | Print-inspired cyan/magenta/yellow |
| `kiosk-acid` | `kiosk-acid` | High-chroma neon accents |
| `kiosk-mac` | `kiosk-mac` | Apple-style blues and greens |
| `kiosk-radiant-orange` | `kiosk-radiant-orange` | Bold orange and amber |
| `custom` | `kiosk-custom` | Base theme + org overrides |

Legacy stored theme slugs (e.g. `kiosk-ocean`, `dark`, `kiosk-light`) are auto-mapped to the nearest new preset on save.

Constants and validation live in `Organization` (`KioskTheming` concern).

## Custom colors

When `kiosk_theme == "custom"`:

1. Layout sets `data-theme="kiosk-custom"` (fallback palette in CSS).
2. Inline `style` on `<html>` sets allowlisted `--color-*` variables from `organizations.kiosk_theme_custom` (json).

Allowlisted keys (grouped in settings UI):

| Group | Keys |
| --- | --- |
| Page | `base_100`, `base_200`, `base_content` |
| Featured service | `primary`, `primary_content` |
| Browse services | `success`, `success_content` |
| Check-in | `warning`, `warning_content` |
| Book appointment | `accent`, `accent_content` |
| Upsell screen | `upsell_bg`, `upsell_content` |

Preset themes use the featured-service `primary` color for the upsell background by default. Custom themes can override `upsell_bg` and `upsell_content` independently (falls back to `primary` / `primary_content` when unset).

**Browse services** (`success`) and **Check-in / appointment** (`warning`) custom colors affect the home screen and service flows only — not the queue confirmed or appointment booked success screens (those use a fixed palette below).

**Border radius** overrides (any theme): `radius_field`, `radius_box`, `radius_selector` — rem values applied as `--radius-*` inline variables.

## Staff UI

Org → Kiosk → **Appearance** (`app/views/org/kiosk/_appearance_form.html.erb`):

- Compact theme radio grid
- Grouped custom color pickers (shown when Custom is selected)
- Border radius selects (all themes)
- Scrollable **theme preview** panel with proportionally scaled kiosk screens (touch, home, services, choice, upsell, forms) reusing the same partials as the live kiosk
- Live updates via `kiosk-theme-preview` Stimulus controller

Full-screen preview (`preview_org_kiosk_path`) still simulates the real touch-start → home flow.

## Confirmed screens (locked)

Service request confirmed, upsell confirmed, and appointment booked screens use a **fixed palette** in `application.css` (`.kiosk-confirmed-*`, `.kiosk-appointment-confirmed-*`). They define their own `--kiosk-queue-*` and `--kiosk-appt-*` variables and do **not** read org `success`, `success_content`, `warning`, or `warning_content` theme settings:

| Screen | Background | Text / accents | Home button |
| --- | --- | --- | --- |
| Queue / walk-in confirmed | `#16a34a` green | `#ffffff` white | White button, green text |
| Appointment booked | `#f59e0b` amber-500 | `#ffffff` white | White button, amber text |

Org theme customization applies to home, services, forms, and flows — not these success endpoints.

## Related files

| File | Role |
| --- | --- |
| `app/models/concerns/kiosk_theming.rb` | Constants, validation, `resolved_kiosk_theme`, inline style |
| `app/views/layouts/kiosk.html.erb` | Applies theme on `<html>` |
| `app/helpers/kiosk_helper.rb` | `kiosk_theme_for`, options, preview helpers |
| `app/assets/tailwind/application.css` | DaisyUI theme `@plugin` blocks |
| `app/javascript/controllers/kiosk_theme_preview_controller.js` | Settings live preview |
