# Design System

Living reference for how this app looks and feels. Keep this in sync with reality - if you change a
convention in code, update it here in the same PR.

## Stack

- **CSS framework:** Tailwind CSS (via `tailwindcss-rails`, config at `config/tailwind.config.js`)
- **Component library:** [DaisyUI](https://daisyui.com)
- **Icons:** Material Symbols (Outlined) - `<span class="material-symbols-outlined">icon_name</span>`
- **Typography:** Roboto (default sans-serif via Google Fonts)
- **Other UI libs:** Shoelace (`<sl-*>` web components), Tom Select (multi-selects),
  Photoswipe (image lightboxes)
- **Rendering:** Server-rendered ERB + Turbo/Stimulus, no SPA framework

## Theming

- **Staff app:** DaisyUI `dark` (default) and `light`, toggled via `theme_controller.js` and persisted in `localStorage.theme`. Applied before paint in `application.html.erb`, `auth.html.erb`, etc.
- **Kiosk:** Separate per-organization presets via `organizations.kiosk_theme` on `data-theme` in `kiosk.html.erb`. Does **not** read `localStorage.theme`. See [kiosk-theming.md](kiosk-theming.md).
- Theme toggle button pattern: `data-theme-target="icon"` swaps the `light_mode` / `dark_mode` material symbol (staff app only).

### Color palette

<!-- TODO: fill in. If using stock DaisyUI dark theme, list which semantic tokens we actually use.
     If custom, give hex values per token. -->

| Token             | Usage                                  | Value |
| ------------------ | --------------------------------------- | ----- |
| `base-100`         | Page/card background                    |       |
| `base-200`         | Sunken surfaces (sidebars, subtle panels) |     |
| `base-300`         | Borders, dividers                       |       |
| `base-content`     | Default text color                      |       |
| `primary`          | Primary actions, links, brand accent    |       |
| `secondary`        | -                                       |       |
| `accent`           | -                                       |       |
| `neutral`          | -                                       |       |
| `success` / `error` / `warning` / `info` | Status states     |       |

## Layouts

Each layout wraps a distinct part of the app in `app/views/layouts/`:

| Layout | File | Used for |
| --- | --- | --- |
| Application | `application.html.erb` | Main authenticated app shell - sidebar + navbar + content |
| Auth | `auth.html.erb` | Sign in / sign up / password reset |
| Onboarding | `onboarding.html.erb` | Post-signup onboarding flow |
| Landing | `landing.html.erb` | Public marketing/landing pages |
| Kiosk | `kiosk.html.erb` | Customer-facing kiosk (device JWT auth, touch-optimised). |
| Waiting display | `waiting_display.html.erb` | Full-screen queue display for waiting area TVs |
| Public portal | `public.html.erb` | Customer-facing booking portal (`/:slug`, custom domains) |

<!-- TODO: fill in - any layout-specific rules (max-width, when to use which layout, etc.) -->

### App shell structure (`application.html.erb`)

- `drawer lg:drawer-open` (DaisyUI drawer) - collapsible sidebar on mobile, always-open on `lg+`
- Sticky, blurred header: `sticky top-0 z-50 border-b border-base-300 bg-base-100/95 backdrop-blur`
- Content column: `main` capped at `max-w-7xl`, padding `px-4 py-8 lg:px-8`
- Toasts + flash messages render at the top of `main` on every page (`shared/toast_container`,
  `shared/flash`)

## Layout & spacing conventions

<!-- TODO: fill in - standard page padding, section spacing, grid/breakpoint conventions,
     container widths for non-app pages (e.g. auth, landing). -->

## Typography

<!-- TODO: fill in - font family (currently system default, no custom font loaded), heading
     scale/weights, body text size, any prose/markdown styling conventions. -->

## Components

Prefer existing DaisyUI component classes over custom CSS. Document conventions here as they solidify
(e.g. "always use `btn-sm` in tables", "destructive actions are always `btn-error` + confirm modal").

### Buttons

Observed usage across the app today:

- `btn btn-primary` - primary/default action
- `btn btn-ghost` - low-emphasis / toolbar actions
- `btn btn-outline` - secondary action (uncolored - see below, this is the "Secondary" button)
- `btn btn-error` - destructive action
- `btn-sm` / `btn-xs` / `btn-lg` - size variants (`btn-sm` most common)
- `btn-square` / `btn-circle` - icon-only buttons

**Rule:** Main function buttons (e.g. "New role", "New permission"), "Back" buttons, and other
navigation buttons all use `btn-sm`. Full-size (`btn` with no size modifier) is not used for these.
Table row actions go smaller still, `btn-xs` (see Tables below).

**Rule:** "Back" buttons (and similar return-navigation links) are text-only - `btn btn-outline btn-sm`
with a plain label like `Back`, no leading icon.

**Rule:** Buttons keep DaisyUI's semantic classes (`btn`, `btn-primary`, `btn-secondary`, `btn-error`,
`btn-ghost`, `btn-outline`, ...) in views - never hand-roll button styling in a template. The visual
language is re-skinned once, globally, in `app/assets/tailwind/application.css`:

- Solid semantic buttons (`btn-primary`, `btn-error`, etc.) get a subtle same-color tinted border
  (`color-mix(... 40%, transparent)`) instead of DaisyUI's flat solid-color edge - a soft rim rather
  than a hard line.
- The uncolored `btn-outline` (no `btn-primary`/`btn-error`/etc. alongside it) is the app's "Secondary"
  button: a soft translucent `base-100` fill with a faint border, brightening to a solid border +
  `base-content` text on hover. It is not a transparent outline in this app.
- `btn-ghost` is `shadow-none`; fills with a light translucent tint of its color (or `base-content` if
  uncolored) on hover.
- `--radius-field` is `0.5rem` (`rounded-lg`) app-wide, up from DaisyUI's default `0.25rem` - buttons
  and any remaining native DaisyUI field elements pick this up automatically.
- **Press animation:** buttons scale to `96%` instantly on `:active` (`transform: scale(0.96)`), with
  no transition on the transform - it snaps rather than eases. DaisyUI's own `.btn` includes `transform`
  in its default `transition-property`; our override redeclares `transition-property` without
  `transform` (keeping `background-color, border-color, color, box-shadow, opacity` smooth at `100ms`)
  specifically so the press-down doesn't animate.
- `cursor: pointer` is applied globally to any non-disabled `<button>` / `[role="button"]`, not just
  `.btn` - DaisyUI's own `.btn` already sets this, this backstops plain buttons/toggles that skip it.

### Confirmations

**Always use the shared confirm dialog — never the browser's native `confirm()`.**

Destructive or irreversible actions (delete, revoke, cancel, deactivate, etc.) must show the app's
shared `#confirm-modal` dialog (`app/views/shared/_confirm_modal.html.erb`), rendered once in each
layout that needs it (`application.html.erb`, `onboarding.html.erb`, ...).

Wire confirmations with the `confirm-modal` Stimulus controller on the **submit button** (for
`button_to` / `submit_tag`), not Turbo's built-in confirm:

```erb
<%= button_to path, method: :delete,
      class: "btn btn-error btn-sm",
      data: {
        controller: "confirm-modal",
        action: "click->confirm-modal#confirm",
        confirm_modal_message_value: "Delete this item? This cannot be undone."
      } do %>
  Delete
<% end %>
```

**Do not use:**
- `data: { turbo_confirm: "..." }` / `data-turbo-confirm` on forms or buttons
- `window.confirm(...)` in JavaScript
- Rails UJS `data-confirm`

The confirm button inside the dialog automatically picks `btn-error` when the triggering button has
`btn-error` or `text-error`; otherwise it uses `btn-primary`. Pair with `loading-button` when the
action is slow (billing, migrations).

Reference: `app/javascript/controllers/confirm_modal_controller.js`

**Legacy note:** `app/javascript/confirm.js` still routes Turbo's global `confirmMethod` to the same
dialog, so stray `data-turbo-confirm` would not fall back to the browser — but do not add new Turbo
confirm attributes; use `confirm-modal` explicitly.

### Forms & inputs

**Rule:** All text inputs, selects, textareas, and checkboxes use the app's own flat/ringed field
classes - **not** DaisyUI's `input` / `select` / `textarea` / `checkbox` classes. These are defined
in `app/assets/tailwind/application.css` on top of DaisyUI's semantic color tokens (`base-100`,
`base-content`, `base-300`, `primary`, `error`), so they stay correct in both the `dark` and `light`
themes without any hardcoded colors.

| Element | Class |
| --- | --- |
| `<input>` (text/email/password/etc.) | `input-field` |
| `<select>` (single) | `select-field` |
| `<select multiple>` | `select-field` (auto-detected via `:not([multiple])` / `[multiple]` in CSS) |
| `<textarea>` | `textarea-field` |
| `<input type="checkbox">` | `checkbox-field` |
| `<input type="radio">` | `radio-field` |

```erb
<div class="form-control">
  <label class="label"><span class="label-text">Email</span></label>
  <%= f.email_field :email, class: "input-field w-full" %>
</div>
```

- The `form-control` div and `label` / `label-text` classes are still DaisyUI's - only the field
  element itself (`<input>`/`<select>`/`<textarea>`/checkbox) uses the custom classes above.
- No size modifiers (`input-sm`, `select-sm`, etc.) - the field classes are a single fixed size (compact,
  `text-sm`, `px-3 py-2`). Don't reintroduce DaisyUI size classes on top of them.
- **Error state:** append a plain `error` class (not DaisyUI's `input-error`). The `error_class_for(object,
  field, base_class)` helper (`app/helpers/application_helper.rb`) does this automatically - pass it
  the field's base class (e.g. `error_class_for(@user, :email, "input-field w-full")`) and it appends
  `" error"` when the object has errors on that field. Pair with the `field_errors(object, field)`
  helper to render the message below the field.
- Disabled state is handled automatically (`opacity-75`, `cursor-not-allowed`, `bg-base-200`) - just
  set the `disabled` attribute, no extra class needed.
- **No placeholders.** Do not set `placeholder` on inputs, textareas, or search fields. Leave fields blank until the user types. Add placeholders only when explicitly requested.
- **Labels only - no field hints.** Each field gets a `label-text` label (and `*` when required). No helper lines under labels, no `label-text-alt` hints (`optional`, format reminders, etc.), and no muted copy explaining what a field is for. `field_errors` output is the exception when validation fails.
- **Checkbox/radio labels:** one line of label text beside the control - no secondary description under the label.
- **Form section headings (`h2` in a card):** title only - no intro paragraph under the section heading.
- **Optional help via tooltips:** when a form field needs guidance, add it intentionally with the info-icon tooltip pattern (`shared/_form_field_tooltip` + `form_label_text` / `form_option_label` helpers) on the field label in the shared `_form` partial. New and edit use the same partial - do not gate tooltips per page. Do not revert to inline helper text or placeholders unless explicitly requested.
- File inputs aren't used anywhere in the app yet; if one is added, follow `checkbox-field`/`radio-field`'s
  pattern (same tokens, adapt the shape) rather than reaching for DaisyUI's classes.
- **Radio group spanning multiple endpoints:** when each radio option needs to submit to a *different*
  URL (e.g. org settings' role radios - "User" posts to the demote endpoint, "Admin" to the promote
  endpoint), don't split them into separate forms - that breaks native radio mutual-exclusivity (radios
  only group within one `<form>`). Instead use one `form_with` (any option's URL as the default `action`)
  wrapping both radios, with `data-controller="auto-submit"` on the form and, on each radio,
  `data-action="change->auto-submit#submit"` + `data-auto-submit-url-param="<the other endpoints>"`. The
  `auto-submit` Stimulus controller (`app/javascript/controllers/auto_submit_controller.js`) repoints
  `form.action` to the selected radio's URL before calling `requestSubmit()` - one real radio group, no
  visible submit button, backend routes untouched. Reference: `app/views/org/settings/index.html.erb`
  (Edit member modal).

### Material icon picker

Reusable picker for choosing a Material Symbols (Outlined) icon name stored in a hidden input.
Reference: `app/views/shared/_material_icon_picker.html.erb` + `material_icon_picker_controller.js`.

- Trigger: `btn btn-outline btn-sm` showing the current icon (`material-symbols-outlined`) and label.
- Popover: `card border border-base-300` panel with `input-field` search and a scrollable grid of
  `btn btn-square btn-sm` icon buttons (`btn-primary` when selected, `btn-outline` otherwise).
- Icon catalog: `ApplicationHelper::MATERIAL_ICON_GROUPS` via `material_icon_groups` (grouped curated list, searchable client-side).
- Never use Lucide or other icon libraries in forms - Material Symbols only.

### Badges

**Rule:** Badges keep DaisyUI's semantic classes (`badge`, `badge-primary`, `badge-success`,
`badge-error`, `badge-warning`, `badge-neutral`, `badge-outline`, `badge-ghost`, ...) in views. Like
buttons, the visual language is re-skinned once, globally, in `app/assets/tailwind/application.css` -
never hand-roll badge colors in a template.

- Colored badges (`badge-primary`, `badge-success`, `badge-error`, `badge-warning`, `badge-neutral`,
  `badge-secondary`, `badge-accent`, `badge-info`) are soft pills: a light tinted background
  (`color-mix(... 15%, transparent)`), text in the badge's own color (not white/content-color), and a
  matching tinted border (`color-mix(... 25%, transparent)`) - not DaisyUI's default solid fill.
- `badge-outline` (used for neutral tags like a role's scope) is a soft neutral pill: faint
  `base-content`-tinted background, `base-300` border, `base-content` text.
- `badge-ghost` (used for low-emphasis states like "Off"/"permanent") is left as DaisyUI's default -
  already a muted `base-200` fill, which fits the soft-pill family as-is.
- Already fully rounded (`rounded-full`-equivalent) via the theme's `--radius-selector: 2rem` - no
  extra class needed.
- `badge-sm` / `badge-xs` for size - same sizing rules as elsewhere (small in tables, `xs` for inline
  indicators like the unread-notification count).

### Cards & surfaces

**Rule:** All cards use `card border border-base-300` - no shadow classes (`shadow`, `shadow-*`).

```erb
<div class="card border border-base-300">
  <div class="card-body">
    ...
  </div>
</div>
```

- `card` - DaisyUI base (border-radius, overflow: hidden)
- `border border-base-300` - explicit hard border, always present
- No `shadow` / `shadow-sm` / `shadow-lg` - ever
- `card-body` default padding applies unless the card wraps a flush element (e.g. table → `card-body p-0`)

### Navigation (navbar & sidebar)

- Navbar: `app/views/shared/_navbar.html.erb`
- Sidebar: `app/views/shared/_sidebar.html.erb`

<!-- TODO: fill in - active-state styling, icon usage, collapsed/mobile behavior beyond the
     DaisyUI drawer defaults. -->

### Notifications (toasts & flash)

- `shared/_toast_container.html.erb` and `shared/_flash.html.erb` rendered once in the app layout.

<!-- TODO: fill in - toast variants/colors per flash type, auto-dismiss timing, position. -->

### Modals & dialogs

<!-- TODO: fill in - DaisyUI modal vs Shoelace dialog usage, when each is used. -->

### Tables

Standard table pattern. Reference: `app/views/org/settings/index.html.erb` (Members table).

**Structure:**
```erb
<%# Section title only - no intro line under h2 %>
<div class="mt-10">
  <h2 class="text-lg font-semibold">Section title</h2>

  <div class="card mt-4 border border-base-300">
    <div class="card-body p-0">
      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead class="text-sm font-semibold text-base-content">
            <tr class="border-b border-base-300">
              <th>Primary column</th>
              <th>Secondary column</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <% collection.each do |item| %>
              <tr class="hover:bg-base-200">
                <td class="font-medium"><%= item.primary_field %></td>
                <td class="text-base-content/60"><%= item.secondary_field %></td>
                <td>
                  <div class="flex justify-end gap-1">
                    <%= button_to path, method: :delete,
                          class: "btn btn-ghost btn-xs btn-square text-error",
                          title: "Remove",
                          data: { controller: "confirm-modal", action: "click->confirm-modal#confirm",
                                  confirm_modal_message_value: "Remove this item?" } do %>
                      <span class="material-symbols-outlined" style="font-size:18px">delete</span>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>
```

**Rules:**

**Wrapper:**
- Use `card border border-base-300` - `card` provides border-radius and `overflow: hidden` natively, solving the corner-clipping problem without hacks
- `card-body p-0` removes card padding so the table sits flush to the edges
- `overflow-x-auto` goes inside `card-body`, wrapping `<table>` directly

**Why `card` and not a plain `div` with `rounded-* overflow-hidden`:**
DaisyUI tables use `border-collapse: collapse`, which causes `overflow: hidden` on plain divs to not clip cell backgrounds at the corners in Chrome/WebKit. `card` handles this correctly. Also avoid `rounded-box` - dark theme sets `--radius-box: 0.25rem` (invisible).

**Header row:**
- `bg-base-200` on `<thead>` + `text-sm font-semibold text-base-content` + `border-b border-base-300` on
  the `<tr>`. (Header text style previously `text-base-content/60 text-xs uppercase tracking-wide` -
  replaced to match the flatter, sentence-case style used by buttons/badges/forms.)
- **Corner-bleed guard:** a filled `<thead>` combined with `border-collapse` can leave a hairline square
  corner poking past the card's `border-radius` in Chrome/WebKit, even inside the `card` wrapper's
  `overflow: hidden`. Handled once, globally, in `app/assets/tailwind/application.css`:
  `.table thead tr:first-child th:first-child` / `th:last-child` get `border-top-left/right-radius:
  var(--radius-box)` directly, so the header row's own corners match the card and there's nothing left
  for the parent clip to miss. No per-view markup needed - just use `bg-base-200` on `<thead>` as normal.

**Rows & cells:**
- No zebra striping - tried `table-zebra` (DaisyUI's built-in even-row striping), reverted per
  preference. Rows are otherwise flush against the card background.
- `hover:bg-base-200` on each `<tr>` - **not** a bare `class="hover"`. `hover` alone is not a real
  Tailwind/DaisyUI class (there's no utility named exactly `hover` - it's a variant prefix, e.g.
  `hover:bg-base-200`), so it compiles to nothing and silently did nothing everywhere it was used.
- Primary identifier: `font-medium`
- Secondary/muted data: `text-base-content/60`
- Never put `flex` directly on `<td>` - wrap contents in `<div>`
- Actions column: header `text-right`, cell content `<div class="flex justify-end gap-1">`

**Action buttons:**
- Icon-only: `btn btn-ghost btn-xs btn-square` + `title` attr for tooltip
- Destructive actions: add `text-error`
- Confirmation: use `confirm-modal` Stimulus controller (see **Confirmations** above)
- Icons: `person_remove` (remove), `logout` (leave), `cancel` (revoke), `delete` (generic)

**"Edit" modal instead of separate row actions:** when a row has more than one mutating action on the
same record (e.g. change role + remove), collapse them into a single `btn-ghost btn-xs btn-square` edit
button that opens a `data-controller="modal"` dialog, rather than several small buttons/dropdowns
crowded into the row. Reference: `app/views/org/settings/index.html.erb` (Members table) - role is
shown read-only in the table as a `badge badge-outline rounded-none badge-sm` (square, not pill - matches
the table's flat look rather than the rounded badges used for status elsewhere), and the row's only
action is one "Edit member" icon button. Inside that modal:
- Role change: a `radio-field` group (not a dropdown, not separate buttons) auto-submitting on change -
  see the "Radio group spanning multiple endpoints" note under Forms & inputs above, since role posts to
  two different endpoints (promote/demote) from what's otherwise one radio group.
- Destructive action (remove): its own `btn-error btn-outline btn-sm w-full` button at the bottom, still
  wired to `confirm-modal`. The shared `#confirm-modal` dialog (`app/views/shared/_confirm_modal.html.erb`)
  is a single global `<dialog>`, so it layers on top of an already-open edit modal without any special
  handling - no need to build a bespoke nested-modal mechanism.
- A user's own row keeps its distinct "Leave organization" icon button (unchanged) rather than going
  through the edit modal - you can't self-edit a role, only leave.

**Sortable headers:** use the `sort_link` helper - `sort_link "Label", "column", current_sort: @sort, current_dir: @direction`

**Inline role/status:** DaisyUI `dropdown` - current value as clickable text + `unfold_more` chevron; each option is a `button_to` form

**Empty state:** render `<p class="mt-4 text-sm text-base-content/60">No items.</p>` in place of the table. If the page header already has a create button, do not add another in the empty state (see **Empty states** above).

### Calendar views

Reference: `app/views/org/appointments/index.html.erb` + `_day_view`, `_week_view`, `_month_view`,
`_calendar_entry` partials.

- **View switcher:** a DaisyUI `join` of `join-item btn btn-outline btn-sm` links (Day / Week / Month);
  the current view gets `btn-active` and `aria-current="page"`. State lives in the URL (`view`, `date`,
  `calendar_id`), not localStorage, so every view is linkable.
- **Period nav:** prev/next `btn-ghost btn-sm btn-square` chevrons step by the current view's unit, plus a
  `Today` `btn-ghost btn-sm`. Week/month show the period label (e.g. `1 - 7 Mar 2027`, `March 2027`) as
  plain `font-semibold` text beside the nav.
- **Filter selects** that should apply immediately use `select-field` inside their own GET form with the
  `auto-submit` controller - no Go button.
- **Week:** `card border border-base-300` wrapping `grid grid-cols-7 divide-x divide-base-300` inside
  `overflow-x-auto` with a `min-w-[56rem]` floor. Column header is `bg-base-200` and links to that
  day's Day view. Entries are compact `text-xs rounded-lg` links with a status-colored dot.
- **Month:** same card, `bg-base-200` weekday header row, `grid grid-cols-7` cells (`min-h-24`, internal
  `border-l`/`border-t` in `border-base-300`) that each link to the Day view. Days outside the month use
  `opacity-50`.
- **Today** is marked with `text-primary font-semibold` on the day label.
- **Cancelled / no-show** stay visible but muted (`opacity-50`, name `line-through`).
- **Closed days** (blocked dates) use a `bg-base-200/50` fill and a muted `Closed: <reason>` line.

### Layout - centering

`<main>` in `application.html.erb` uses `mx-auto` to center content within the flex column. Each page's top-level wrapper controls its own max-width (e.g. `max-w-4xl` for settings pages).

### Page headers

Index and show pages use a single top row: `<h1>` on the left, primary action button(s) on the right.

**Rules:**

- **No subheading under `<h1>`.** Do not add a muted paragraph below the page title - no explanatory copy ("Kiosk provisioning and API keys"), no org name + counts (`Admin - 0 rules`, `3 services · 2 active`), no totals under the title. The nav label + title are enough; add a dedicated number display only when explicitly requested.
- **Breadcrumbs** (`text-sm font-medium text-base-content/60` above the title) are fine on nested pages (show/edit/new) - they are navigation, not a page description.
- **Form pages** (`new`/`edit`): title only (plus breadcrumb if nested). On `edit`, the record name may appear in the breadcrumb trail, not as a second line under `<h1>`.
- **Page context belongs in the body.** Date pickers, filters, and other controls that set what the page shows live below the header row, not under the title.

```erb
<%# Index header - title + action only %>
<div class="flex flex-wrap items-start justify-between gap-4">
  <h1 class="text-2xl font-semibold">Devices</h1>
  <%= link_to new_org_device_path, class: "btn btn-primary btn-sm gap-1" do %>
    <span class="material-symbols-outlined !text-[18px]">add</span>
    New device
  <% end %>
</div>
```

### Empty states

When a list index has no rows yet (or a filter returns nothing), show a short muted message only - **do not duplicate the primary create action**.

**Rules:**

- The **New …** button in the page header (top right) is always present on index pages that support create. That is the single entry point for adding the first item.
- Empty state copy: one line, e.g. `<p class="mt-6 text-sm text-base-content/60">No devices yet.</p>` - no second `btn btn-primary` below it.
- Filtered-empty copy may mention the filter (e.g. "No devices found.") but still no extra button.
- Section-level empty states inside a page (e.g. a table subsection on settings) follow the same rule unless that section has its own header action and no page-level create button.

```erb
<% if @devices.any? %>
  <%# table ... %>
<% else %>
  <p class="mt-6 text-sm text-base-content/60">No devices yet.</p>
<% end %>
```

<!-- Removed obsolete empty-state TODO. -->

## Interactivity: Turbo Frames & Streams

The app uses Hotwire (`turbo-rails` + `stimulus-rails` + `importmap-rails`) for all no-page-reload
interactions - **not** htmx, and no SPA framework. Every mutating controller action should keep a
`format.html` fallback that reproduces its old full-page `redirect_to`/`render` behavior (for direct
links, no-JS clients, and so existing request tests keep passing unchanged) and add a
`format.turbo_stream` branch for the in-place update. Don't add a Turbo conversion to an action that
doesn't need one - a rarely-used, low-traffic form (e.g. one-off admin CRUD pages) is fine as a plain
full-page redirect.

**Choosing Frame vs Stream vs plain redirect:**
- **Plain `redirect_to`** - whole-page navigation (e.g. login -> dashboard), or a full-page CRUD form
  that's simple/infrequent enough that a reload is a non-issue.
- **Turbo Frame** (`turbo_frame_tag`) - a self-contained region that re-fetches itself on
  navigation/filter/sort inside it (e.g. a table with a filter form and sortable columns). No
  controller changes needed - Turbo just extracts the matching `<turbo-frame id="...">` from the
  otherwise-normal HTML response. Reference: the members table frame in
  `app/views/org/settings/index.html.erb` and the filter+table frames in `app/views/admin/*/index.html.erb`.
- **Turbo Stream** - a mutation (create/update/destroy) that should patch one or more specific spots
  (a row, a badge, a flash message) without reloading the rest of the page. Reference:
  `Org::OrganizationsController#update`, `Org::MembersController#promote/#demote/#destroy`.

**`dom_id` everywhere:** `ApplicationController` includes `ActionView::RecordIdentifier`, so `dom_id`
is available in every controller (not just views) for building Turbo Stream targets -
`turbo_stream.replace(dom_id(@user, :editor), ...)`. Use the two-arg form (`dom_id(record, :suffix)`)
whenever a record has more than one independently-targetable region (e.g. a user has both an
`:editor` dialog and a `:status_badge`).

**Conventions (established across `org`, `admin`, and `profile`; follow these for new work):**

1. **Flash/toast container.** The layout wraps `shared/_flash` in `<div id="flash_messages">`
   (`app/views/layouts/application.html.erb`). Any stream response that should show a toast does
   `flash.now[:toast] = { message: "...", type: "success" }` then
   `turbo_stream.replace("flash_messages", partial: "shared/flash")`. `flash_controller.js` needs no
   changes - a full node replace re-triggers its `messageValueChanged` connect callback.
2. **Inline-edit-via-modal.** For "a small dialog that edits one record and lives on the page it's
   submitted from" (org name, profile name, admin user info, admin feature flags, org member
   promote/demote): **never target the `<dialog>` element itself with `turbo_stream.replace`** - only
   `turbo_stream.update` its content, or replace pieces *inside* it. Concretely: give the `<dialog>` a
   stable id (`dom_id(record, :dialog)`) that's never re-issued once rendered; split its markup into a
   `_dialog_content` partial that `update` replaces on both success and validation failure; give the
   record's read-only display (e.g. an `<h1>` or `<dd>`) its own id and `replace` that separately on
   success. Close the modal by adding `data: { action: "turbo:submit-end->modal#closeOnSuccess" }` to
   the form (`modal_controller.js#closeOnSuccess` checks `event.detail.success` before calling
   `dialogTarget.close()`) - **not** by replacing the dialog wrapper with a fresh unopened one.
   Reference: `app/views/org/settings/_name_editor.html.erb` +
   `app/views/org/settings/_name_dialog_content.html.erb` + `Org::OrganizationsController#update`.

   This matters beyond style: `app/javascript/controllers/toast_controller.js` physically reparents
   the global toast host into whichever `<dialog>` is currently open (so a toast stacks above it in the
   browser's top layer). If a Turbo Stream `replace` destroys that `<dialog>` - which is what
   "replace the whole wrapper to close the modal for free" does - it destroys the toast host along
   with it, permanently breaking `window.toast` for the rest of the page's lifetime with no visible
   error. This was hard to diagnose because the stream update itself still succeeds and renders
   correctly; only the toast silently never appears. Keeping the `<dialog>` node itself stable across
   every render sidesteps the whole failure class.

   Also keep genuinely-destructive actions (remove/delete a row) out of the *same* dialog as an edit
   action - e.g. org members' row menu is a dropdown with two separate items, "Edit role" (opens the
   stable edit dialog above) and "Remove" (a plain `button_to` wired straight to `confirm-modal`, not
   nested inside any per-row dialog). If a destructive action's own confirm step were nested inside an
   editable-record's dialog, removing the row would need to destroy that dialog too - re-triggering the
   exact toast-host-destruction problem this convention exists to avoid, since there'd be no way to
   "keep the dialog stable" for a row that's being deleted. Reference:
   `app/views/org/members/_membership_row.html.erb`.
3. **`dom_id`-keyed row partials.** For any list where a single record's row must be patched/removed
   (org members, org invitations, admin notifications, admin features, notification recipients):
   extract the `<tr>`/`<li>` into its own partial, id'd `dom_id(record)`, rendered by both the index
   loop (`render partial: "...", collection: ..., as: :record`) and by the controller's
   `turbo_stream.replace`/`turbo_stream.remove` calls.
4. **List container with empty-state.** Where a section toggles between a populated `<table>`/`<ul>`
   and a "No X" message (org pending invitations, notification inbox), wrap the *whole* toggling
   region in one container id (e.g. `#pending_invitations_section`, `#notifications_inbox`) and always
   replace that whole container on create/destroy, rather than conditionally branching between
   `append`/`remove` and a full replace depending on whether the action crosses the 0-item boundary.
   The extra query cost is trivial for these list sizes and it keeps the controller action simple.
5. **Cross-page elements (layout chrome).** A stream response can update DOM anywhere in the current
   page, not just where the triggering element was - but only if that element was given a stable id in
   the first place. This is easy to forget for anything rendered once in the layout: it's plain
   server-rendered markup from page-load time, so unless a stream response explicitly targets it by id,
   it silently goes stale until the next full page render - there's no error, the rest of the update
   just quietly doesn't include it. Two examples already fixed this way:
   - `notification_recipients` actions replace the navbar's `#notification_unread_badge`
     (`shared/_notification_badge` partial) since that badge is present in the layout on every
     authenticated page.
   - `Org::OrganizationsController#update` replaces the navbar org-switcher's label
     (`shared/_org_nav_label`, id `dom_id(organization, :nav_label)`) and its entry in the switcher's
     dropdown list (`shared/_org_nav_item_label`), so renaming the current org updates the switcher
     immediately instead of only after the next navigation. When adding a stream response for
     anything editable that also has a "second, glanceable copy" of its name/state elsewhere in the
     layout (nav, sidebar, breadcrumb), give that copy an id too and update it in the same response -
     don't assume it'll refresh on its own.
6. **Lazy-loaded frame inside a repeated-row modal.** When an edit form is too complex to duplicate
   inline per-row (admin features), give each row's modal a nested
   `turbo_frame_tag dom_id(record, :edit_frame), src: edit_path(record)` with a "Loading..." placeholder;
   the `edit` action renders *only* a partial wrapping the same frame id (`layout` is skipped
   automatically since it's a partial render, not a full template render) - mirrors the existing
   `email_changes` frame precedent (`app/views/email_changes/_frame.html.erb`). The frame lives
   *inside* the row's `<dialog>` (per convention #2, given its own stable id and never replaced) - only
   the frame's content gets `replace`d on success/failure, and the row's read-only cells (each with
   their own id) are updated separately; the modal closes via `modal#closeOnSuccess`, same as #2.
7. **Stimulus compatibility.** `confirm_modal_controller.js` and `auto_submit_controller.js` need no
   changes for any of the above - both just call `form.requestSubmit()`, and Turbo's format
   negotiation happens transparently regardless of what triggered the submit.

Prefer building a `turbo_stream: [...]` array directly in the controller action (as in the examples
above) over a separate `*.turbo_stream.erb` view file, unless the stream response is only ever
rendered by implicit template lookup with no branching - keeping the stream actions next to the logic
that produced them is easier to follow than hopping to another file for a one-off response.

## Third-party component usage

- **Shoelace** (`<sl-*>`): <!-- TODO: which components, and why Shoelace instead of DaisyUI here
  (e.g. color-picker) -->
- **Tom Select**: <!-- TODO: which fields/forms use it -->
- **Photoswipe**: <!-- TODO: where image galleries/lightboxes appear -->

## Responsive & accessibility rules

<!-- TODO: fill in - breakpoint strategy (mobile-first?), min touch target sizes, contrast
     requirements, focus-visible conventions, keyboard nav expectations. -->

## Voice & content

<!-- TODO: fill in - tone (formal/casual), capitalization rules for buttons/headings (Title Case
     vs sentence case), terminology glossary (e.g. "Login" not "Sign in" - see terminology
     refactor commit 4289b7b). -->

**Rule: never use an em dash.** Not in UI copy, not in code comments, not anywhere in the codebase,
under no condition. Use a plain hyphen `-` instead. This applies everywhere without exception - user-facing
text, flash messages, Ruby/JS comments, and this design doc itself.

## Do / Don't

<!-- TODO: fill in as conventions get established. Examples of the format: -->

- ✅ Do use DaisyUI semantic color tokens (`bg-base-200`, `text-primary`) instead of raw Tailwind
  colors (`bg-gray-100`, `text-blue-500`), so theme changes propagate everywhere.
- ❌ Don't hardcode hex colors in views or component partials.
- ✅ Do use `card border border-base-300` for all card components.
- ❌ Don't add shadow classes (`shadow`, `shadow-sm`, `shadow-lg`, etc.) to cards.
- ✅ Do use a plain hyphen `-` wherever you'd reach for a dash - in UI text, comments, anywhere.
- ❌ Don't use an em dash, ever, in code, comments, or UI copy - no exceptions.
- ✅ Do put the primary create action once in the index page header (top right); empty states are text-only.
- ❌ Don't duplicate a "New …" / "Create first …" button in an empty state when the header already has one.
- ❌ Don't add any subheading under `<h1>` - no page descriptions, org names, or counts (e.g. `Admin - 0 rules`).
- ❌ Don't use `placeholder` on form fields, or helper/hint copy under labels and form section headings.
- ✅ Do use `!hidden` (not plain `hidden`) when conditionally hiding a `material-symbols-outlined`
  span - Google's icon stylesheet loads after the app CSS in every layout and its
  `display: inline-block` wins over an equal-specificity `hidden` utility.
