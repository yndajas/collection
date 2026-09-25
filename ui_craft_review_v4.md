# UI craft review (v4)

A whole-interface review through the ui-craft lens: usability (Krug, Nielsen,
Norman) and accessibility (WCAG 2.2 AA, GOV.UK Design System, dxw accessibility
manual). Walked twice — once as a first-time sighted mouse user, once as an
assistive-technology user.

This is a **prototype** branch. Findings are ranked by impact with accessibility
blockers first; cosmetic nits are called out as such.

## Scope

Every view, partial, layout and the stylesheet under `app/`:

- **Layout:** `layouts/application.html.erb`.
- **Root:** `root/index`, `root/_collection_list`.
- **Collections:** `collections/index`, `collections/_search_form`,
  `collections/_search_help`.
- **Profiles:** `profiles/show`, `profiles/_profile_row`,
  `profiles/_follow_button`, `profiles/private_profile`.
- **Collectibles:** `_collectible`, `show`, `_form`, `_search_form`,
  `_search_help`, `new`, `edit`, `confirm_delete`, `import`, `_import_fields`,
  `_import_help`, `review`.
- **Settings:** `settings/show`, `settings/_nav`, `settings/visibility/show`,
  `settings/sorting/show`, `settings/labels/{index, edit, confirm_delete,
  _type_checkboxes}`, `settings/custom_sorts/{new, edit, _form}`.
- **2FA:** `two_factor_authentication/{sessions, setup}/show`.
- **Shared:** `application/_pagination`.
- **Stylesheet:** `assets/stylesheets/application.css` (incl. all seven themes).

Not reviewed: Devise's own auth views (not overridden in this tree), the PWA
manifest/service-worker, and mailer templates. There is **no JavaScript** in the
app, so no client-side/dynamic-content behaviour was in scope — which also means
the live-region and focus-management concerns that usually dominate are mostly
not applicable here (a point in the app's favour).

## What already works — credit where due

- **State-changing actions use `button_to`, navigation uses `link_to`.** Sign
  out, Follow/Unfollow, Remove access, Revoke link, and the destroy actions are
  all POST/DELETE buttons, not links (`layouts/application.html.erb:31`,
  `_follow_button.html.erb`, `settings/visibility/show.html.erb:47,84`). This is
  the correct semantics and it is applied consistently.
- **Confirm-then-delete** for collectibles and labels: a GET confirmation page
  then a POST — good error prevention (Nielsen 5), and the confirm copy is clear
  ("This can't be undone").
- **Progressive disclosure for search help.** The Gmail-like syntax lives in a
  `<details>` (`_search_help.html.erb`), so the toolbar stays uncluttered and
  help is there on demand — Krug's "omit needless words" and Hick's law both.
- **Real, associated labels everywhere**, including visually-hidden ones for the
  search inputs and the custom-sort composer selects
  (`_search_form.html.erb:8`, `custom_sorts/_form.html.erb:31,37`). The
  `.visually-hidden` utility is correct.
- **Relative units and responsive layout.** A rem-based type scale
  (`application.css:22`), `minmax()` auto-fill grid, `max-width` containers and a
  breakpoint mean the app reflows for zoom/small viewports (WCAG 1.4.10) without
  fixed-pixel text.
- **Design-token colour system** with a documented ≥3:1 `--field-border` for
  control edges (WCAG 1.4.11) and per-theme label palettes, all asserted
  AA-verified in comments.
- **`aria-current="page"` on the current pagination item** and `role="group"` +
  `aria-label="View"` on the view toggle (`_pagination.html.erb:8`,
  `profiles/show.html.erb:32`) — where ARIA is used, it is used correctly.
- **Errors are not colour-only:** the import review marks a bad item with a red
  border *and* the error text inside it (`_import_fields.html.erb:5,10`).
- `lang="en"` on `<html>`, a clickable brand-logo home link, and the breadcrumb
  separator hidden with `aria-hidden` — all small correct touches.

## Findings, ranked

### 1. [High] In the monochrome themes, text links are indistinguishable from body text — WCAG 1.4.1

Links are styled by colour only: `a { color: var(--brand); }`
(`application.css:98`) with no underline, and body links get no underline on
default state anywhere. In the colour themes that is already a mild "use of
colour" concern for links sitting inside a paragraph (e.g. the "Sign in" link in
`private_profile.html.erb:11`, the "Your public profile:" link in
`settings/visibility/show.html.erb:29`, links inside `_import.html.erb` hints).
But in **`monochrome_light` and `monochrome_dark`**, `--brand` is set to the
*same value as `--text`* (`#1a1a1a` / `#ededed`, `application.css:475,514`), so
an inline link is rendered in exactly the body-text colour with no underline —
**no visual distinction at all**. A user cannot tell what is a link. That is a
straight WCAG 1.4.1 (Use of Colour) failure, and the theme makes it total rather
than marginal.

**Fix:** underline in-content links (at least on the non-nav links that sit
within text). An underline is a non-colour cue that fixes both the general case
and the monochrome case at once, and is the conventional signifier for a link
(Krug/Norman: make clickable things look clickable).

### 2. [Medium] No skip link, and `<main>` is not targetable — WCAG 2.4.1

The header repeats the full navigation on every page
(`layouts/application.html.erb:22-39`), but there is no skip-to-main-content
link and `<main class="site-main">` has no `id` to target
(`:41`). Keyboard and screen-reader users must tab through the whole nav on
every page to reach content. The reference calls for a skip link precisely when
the header repeats nav.

**Fix:** add a visually-hidden-until-focused skip link as the first focusable
element, and give `<main id="main-content">` a target.

### 3. [Medium] Landmark naming is inconsistent across the navigation regions

There are several landmark-level `nav`s, but only some are named:

- `nav.pagination` — `aria-label="Pagination"` ✅ (`_pagination.html.erb:3`)
- view toggle — `role="group" aria-label="View"` ✅ (`profiles/show.html.erb:32`)
- **site header `nav.site-nav`** — no accessible name
  (`layouts/application.html.erb:26`)
- **settings `nav.subnav`** — no accessible name (`settings/_nav.html.erb:1`)
- **`nav.breadcrumb`** — no accessible name (`collectibles/show.html.erb:4`)

When more than one landmark of the same type exists, each needs a distinct
label, or a screen-reader user hears "navigation… navigation… navigation" with
no way to tell them apart. This is the classic "one component does it right, its
siblings don't" shape: pagination and the view toggle are labelled, the other
three are anonymous.

**Fix:** `aria-label` the site nav ("Primary"), the settings subnav
("Settings"), and the breadcrumb ("Breadcrumb").

### 4. [Medium] Current-location state is shown visually but not announced — WCAG 4.1.2 / Nielsen 1

`aria-current` is used on pagination but not on the other "current item"
controls:

- The **settings subnav** marks the active tab with a class → colour + weight
  only (`settings/_nav.html.erb`, `.subnav a.active` in `application.css:363`),
  no `aria-current`.
- The **view toggle** marks the active view the same way
  (`profiles/show.html.erb:5`, `.view-toggle a.active` in `application.css:314`),
  no `aria-current`.
- The **top site nav** gives no current-section indication at all — a signed-in
  user on "Settings" or "All collections" sees no active state.

So sighted users get the cue (colour/weight) and screen-reader users do not, and
the top nav gives nobody a "where am I" answer (Krug's first navigation
question). This clusters with finding 3 under one theme: **state shown but not
announced.**

**Fix:** add `aria-current="page"` to the active subnav and view-toggle items
(mirroring pagination), and give the top nav an active state for the current
section.

### 5. [Medium] The shared `_collectible` partial hardcodes `<h3>`, skipping a heading level — WCAG 1.3.1

`_collectible.html.erb:6` renders the card title as `<h3>`. On the homepage that
is correct — it sits under an `<h2>` section heading ("From your collection",
`root/index.html.erb:20`). But on the collection page the card grid follows the
page `<h1>` with **no `<h2>` in between** (`profiles/show.html.erb:10` then the
grid at `:63`), so the first heading a screen-reader user meets after the `h1`
is an `h3` — a skipped level. Same partial, correct in one context, wrong in the
other.

**Fix:** either introduce an `<h2>` on the collection page above the results, or
make the card heading level a partial local so each caller passes the right
level.

### 6. [Medium] Form error handling is not accessible — WCAG 3.3.1 / 3.3.3

Forms surface validation errors as a plain `.errors` box listing
`full_messages` at the top of the form (`_form.html.erb:9-18`,
`settings/labels/index.html.erb:14`, `custom_sorts/_form.html.erb:4-9`). Missing,
relative to the reference pattern:

- the summary items are **not links to their fields**, and focus is **not moved**
  to the summary on failed submit (this is what keyboard/SR users rely on to
  find errors);
- invalid fields carry **no `aria-invalid`** and **no `aria-describedby`** to the
  message, so there is no per-field association;
- there are **no inline, per-field messages** — only the top-of-form list.

For a prototype this is understandable, but it is the difference between "an
error happened somewhere above" and "here is the field and here is how to fix
it".

**Fix:** adopt the error-summary pattern (linked items + focus move) and
associate each message with its field (`aria-describedby` + `aria-invalid`).

### 7. [Medium] 2FA setup offers a QR code with no text alternative and no manual-entry key

`two_factor_authentication/setup/show.html.erb:5-7` injects the QR SVG via
`html_safe` with no accessible name, and there is **no manual secret/otpauth
key** shown as a fallback. A user who cannot scan a code — screen-reader users,
anyone without a second camera device — cannot complete setup, which is a
hard task-blocker on a mandatory step (2FA is enforced by
`ApplicationController#ensure_2fa_setup`).

**Fix:** show the secret (or the `otpauth://` URI) as selectable text alongside
the QR, and give the QR an appropriate name or mark it decorative if the text
key is the real path.

### 8. [Medium] Destructive actions are confirmed inconsistently — Nielsen 5

- **Labels** and **collectibles** get a dedicated confirmation page before
  deletion (good).
- **Custom sorts**, **share links** and **profile accesses** are deleted
  immediately by a `button_to` with no confirmation
  (`sorting/show.html.erb:42`, `visibility/show.html.erb:47,84`).

Deleting a custom sort you spent time composing, with a single click and no
undo, is the sharpest case. The inconsistency also makes the interface less
predictable (Nielsen 4).

**Fix:** at minimum add a native confirm or a confirm step to the custom-sort
delete; ideally make the pattern uniform across all destructive actions.

### 9. [Low] Focus is left entirely to the browser default

There are no `:focus`/`:focus-visible` styles in the stylesheet at all. Per the
reference this is *acceptable* — the app never removes the outline, so keyboard
focus is always visible, and that is the important thing (credit for not
stripping it). The gap is only that the default ring may be low-contrast against
some theme fills (the monochrome and pastel surfaces especially), and there is
no consistent, designed indicator.

**Fix (enhancement, not a defect):** add an explicit high-contrast
`:focus-visible` outline so focus is reliably visible across all seven themes.

### 10. [Low] Small, crowded tap targets — WCAG 2.5.8

The external-search link tags (`.tag--link`, `application.css:336`, padding
`0.15rem 0.6rem`, `gap: 0.4rem` on `.tags`) and the pagination number links
(`application.css:674`, padding `0.35rem 0.65rem`) are likely under the 24×24
CSS-px target guidance and sit close together — awkward for motor-impaired users
(Fitts's law). Roomier padding / spacing would help.

### 11. [Low] Every settings subpage shares the `<h1>` "Settings"

`settings/show`, `visibility/show`, `sorting/show` and `labels/index` all render
`<h1>Settings</h1>` (the section heading is an `<h2>` below). The `<title>`
differs correctly, but the reference asks that the `h1` differ between pages
too, so a screen-reader user navigating by heading can tell them apart. Minor;
the subnav active state (finding 4) partly compensates for sighted users.

### 12. [Low] Content-polish inconsistencies

- Mixed straight vs curly quotation marks across views — e.g. the "nothing
  matches" empty state uses straight quotes in `profiles/show.html.erb:75` and
  curly ones in `collections/index.html.erb:23`.
- The search-help tables have no `<caption>`, and the type-group rows use
  `<th colspan="3">` without `scope` (`_search_help.html.erb`); the composer
  table does better with `<th scope="row">`. A caption and consistent scopes
  would round these out (WCAG 1.3.1).
- The OTP inputs are plain `text_field`s; `autocomplete="one-time-code"` is set
  (good), but adding `inputmode="numeric"` would give mobile users the right
  keypad (`sessions/show.html.erb:8`, `setup/show.html.erb:13`).

## Recurring themes

Two ideas tie several findings together:

- **State shown but not announced** (findings 3 and 4, and the SR half of 1):
  current-item and landmark information that a mouse user reads from
  colour/weight/position but a screen-reader user is never given. `aria-current`
  and landmark labels are the cure, applied consistently.
- **Colour carrying meaning alone** (finding 1, and the error-cue check that
  *passed* in the import review): links distinguished only by hue, taken to its
  worst in the monochrome themes. Underlines are the systemic fix.

## Colour-contrast note (honest limitation)

The stylesheet asserts every pair is AA-verified, and the ones I could reason
about (body text on surface/bg in the light and dark themes, `--brand` links,
the documented `--field-border`) look sound. I did **not** independently run a
contrast checker over all seven themes, so I am not asserting any pass/fail
beyond finding 1 (which is a use-of-colour issue, not a ratio issue). The pairs
I would re-check with a tool first are `--muted` on the coloured backgrounds of
the pastel themes (e.g. `--muted #5f4a54` on `pastel_parlour --bg #f7cede`),
where muted secondary text on a saturated ground is the most likely to be
borderline.

## Coverage note

Every view, partial, layout and the full stylesheet (all seven themes) were read
and swept per WCAG criterion and per Nielsen heuristic across the whole scope,
and walked as both a sighted mouse user and an assistive-technology user.
Assertions I could not verify by inspection alone — exact contrast ratios, and
real screen-reader/keyboard behaviour — are flagged as such rather than claimed.
Dynamic-content accessibility (live regions, focus management) was checked and
found largely not applicable: the app ships no JavaScript, so state changes
happen via full page loads.
