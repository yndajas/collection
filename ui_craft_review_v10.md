# UI-craft review — v10

**Lens:** UI craft (usability — Krug, Nielsen, Norman; accessibility — WCAG 2.2,
GOV.UK Design System). **Scope:** every view/partial under `app/views`, the
layout, `app/assets/stylesheets/application.css`, and the content assembled in
controllers/config that a screen announces. **Depth:** exhaustive.
**Execution:** two independent inline passes (fresh reviewers, no shared context)
plus an adjudication read, diffed and synthesised. **Out of scope:** automated
tests (prototype branch). **Date:** 2026-08-12.

## Coverage caveat

A review samples a larger space; gaps are likely, including task-blocking ones.
This is the reconciled union of two independent passes and a third adjudication
read — broader than any single pass, but not complete. Where the passes disagreed
on severity (focus indicator, heading skip, link colour), the resolution is
recorded inline and was checked against the code/CSS. Contrast was spot-checked on
the tightest pairs, not computed for all seven themes; the blanket "All pairs
WCAG-AA verified" comment in the stylesheet (`application.css:430`) is a claim,
not a proof, and warrants a real audit. A further fresh pass is the most reliable
way to close what all three missed. Severity is kept separate from the
leverage-ordered fix list.

The two walks: once as a first-time sighted mouse user, once as an
assistive-technology (keyboard + screen-reader) user.

---

## Findings

### High

**UC1. No skip link, and `<main>` is not a focus target (WCAG 2.4.1 Bypass
Blocks).** `app/views/layouts/application.html.erb:41`. The header repeats the
full primary nav on every page, but there is no "skip to main content" link and
`<main class="site-main">` has no `id`. Keyboard and screen-reader users must tab
through the whole nav on every page load. *Fix:* add a visually-hidden-until-
focused skip link as the first focusable element, targeting
`<main id="main-content" tabindex="-1">`.

### Medium

**UC2. No custom focus style; the app relies entirely on the browser default
(WCAG 2.4.7 / 2.4.11).** `app/assets/stylesheets/application.css` defines no
`:focus`/`:focus-visible` rule anywhere. *Adjudication:* there is also **no
`outline: none` reset**, so the browser's default focus ring does survive on
links, buttons, inputs and selects — keyboard focus is *not* invisible (this
corrects one pass's "keyboard users cannot see focus" to the accurate picture).
The real issue is that the default ring is never tuned: on filled controls
(`.button`, `.button--danger`, `.view-toggle a.active`) whose background is
`--brand`/`--danger`, and across the seven themes, the thin UA ring can fall below
the 3:1 non-text contrast the focus appearance needs. *Fix:* add one explicit,
high-contrast `:focus-visible` outline (with offset) on interactive elements and
verify it against each theme's `--bg` and the filled-button backgrounds.

**UC3. Current location is shown to sighted users but not announced.** The
active nav/section is conveyed by colour/weight (a CSS class) with no
`aria-current`:
- `app/views/layouts/application.html.erb:26` — site-nav gives *no* current cue
  at all (no active class, no `aria-current`).
- `app/views/settings/_nav.html.erb` — `.subnav a.active` (weight/colour only).
- `app/views/profiles/show.html.erb:31` — the view-toggle marks the active view
  with `.active` (a brand fill) and no `aria-current`/`aria-pressed`; in the
  monochrome themes the fill is the *only* cue.

Pagination does this correctly (`aria-current="page"`,
`application/_pagination.html.erb:8`) — its siblings don't (name/role/value
parity gap, "state shown but not announced"). *Fix:* add `aria-current="page"` to
the active nav/subnav link and `aria-current="true"` (or `aria-pressed`) to the
active view-toggle control.

**UC4. Multiple `<nav>` landmarks lack distinct accessible names.** `site-nav`
(`application.html.erb:26`), the settings `subnav` (`settings/_nav.html.erb:1`),
and the breadcrumb (`collectibles/show.html.erb:4`) are bare `<nav>`s; only
pagination is labelled. A screen-reader landmark list shows several
indistinguishable "navigation" regions. *Fix:* `aria-label` each ("Primary",
"Settings", "Breadcrumb").

**UC5. Heading level skips from `<h1>` to `<h3>` on the collection page.**
`app/views/collectibles/_collectible.html.erb:6` emits `<h3>` for the card title.
On `profiles/show.html.erb` the structure goes `<h1>` (collection name) → search
form → cards at `<h3>`, with **no `<h2>` between** (WCAG 1.3.1). The same shared
partial renders correctly under the homepage's `<h2>` sections, which is exactly
why the skip hides. *Fix:* make the card-title level a partial local, use `<h2>`
on the collection page, or wrap the grid in a titled `<h2>` section.
*(Severity split: pass A rated High, pass B rated Low; reconciled to Medium — a
real structural gap for heading-navigation users, but not task-blocking.)*

**UC6. In-body links rely on colour alone, and vanish in the monochrome themes
(WCAG 1.4.1).** `application.css:98` sets `a { color: var(--brand); }` with an
underline only on `:hover`. Links embedded in running text — the breadcrumb
(`collectibles/show.html.erb:5`), the "Manage labels" hint (`_form.html.erb:77`),
the CSV/JSON export links (`profiles/show.html.erb:47`), "Clear" / "Manage sorts"
(`_search_form.html.erb`), and the `<summary>` of the search help — are
distinguished from body text by colour only. In `monochrome_light` /
`monochrome_dark`, `--brand` equals `--text` (`application.css:478,518`), so these
in-text links are *visually indistinguishable* from surrounding prose until
hovered. *Fix:* underline links that sit within text (leave nav/button/tag links,
which have their own affordance, exempt) and ensure the cue holds in every theme.
*(Nav links and genuine buttons are fine; this is scoped to in-prose links and
the bare `<summary>`.)*

**UC7. Flash messages are not in a live region.**
`app/views/layouts/application.html.erb:42`. Notices and alerts render as a plain
`<p class="flash">`. Most flows redirect-then-flash, so on a fresh page load a
screen reader reaches the message in document order (moderate severity) — but the
in-place re-renders (`import_review`, failed `create`/`update`) never announce it.
*Fix:* wrap in `role="status"` (notice) / `role="alert"` (alert).

**UC8. Forms have no error summary and no per-field error association (WCAG 3.3.1
/ 3.3.3).** `app/views/collectibles/_form.html.erb:9`,
`settings/labels/index.html.erb:14`, `settings/custom_sorts/_form.html.erb`,
`settings/show.html.erb:7`. Errors render as a top-of-form `<div class="errors">`
list or a sentence, but: focus isn't moved to it on failed submit, the summary
items don't link to their fields, and the individual inputs get no
`aria-invalid` / `aria-describedby` tying the message to the field. Keyboard and
screen-reader users can't jump to the offending input. *Fix:* adopt the
error-summary pattern (a focusable summary linking to each field) and mark invalid
inputs (`aria-invalid="true"` + `aria-describedby`).

**UC9. Destructive-action confirmation is inconsistent (Nielsen 5, error
prevention).** Collectible delete and label delete route through a dedicated
`confirm_delete` page (good — `collectibles/confirm_delete.html.erb`,
`settings/labels/confirm_delete.html.erb`). But share-link **Revoke**
(`settings/visibility/show.html.erb:84`), person-access **Remove** (`:47`), and
custom-sort **Delete** (`settings/sorting/show.html.erb`) are one-click `button_to`
deletes with no confirmation step and no `data-turbo-confirm`. *Fix:* make it
consistent — either a confirm step / `data-turbo-confirm` on the one-click
deletes, or a deliberate, documented decision that these are low-stakes.

### Low

**UC10. Search DSL discoverability rests on a collapsed `<details>`.** The search
placeholder shows GitHub-style syntax (`is:completed system:switch zelda`,
`_search_form.html.erb:10`); a first-time user must open "Search syntax" to learn
it (Krug: don't make me think; Nielsen 6, recognition over recall). The help
(`_search_help.html.erb`) is thorough but hidden by default, and the "OR binds
looser than AND" precedence rule asks the user to hold a grammar in their head.
Reasonable for a power-user prototype; consider a worked example beside the box.

**UC11. Search-help table header cells lack `scope="col"`.**
`collectibles/_search_help.html.erb:12`, `collections/_search_help.html.erb:12`
(`<th>Filter</th>…` in a `<thead>` row). The custom-sort composer already uses
`scope="row"`; add `scope="col"` here for robust header/data association.

**UC12. The 2FA code field uses jargon and no numeric input mode.**
`two_factor_authentication/setup/show.html.erb:13` and `sessions/show.html.erb:7`
label the field "OTP" (jargon) rather than "One-time code" / "6-digit code"
(plain language, content). `autocomplete="one-time-code"` is set (good) but
`inputmode="numeric"` is missing, so mobile users don't get the numeric keypad.
These two views also sit outside the app's styled `.stack`/`.section` layout
(bare `<div>`s), a minor visual-consistency gap. *Fix:* friendlier label +
`inputmode="numeric"`.

---

## Theme aggregation (across-screens, same problem)

1. **State/location shown to sighted users but not announced to assistive tech**
   (UC3, UC5, UC7) — current nav item, heading level, flash — the app *looks*
   right but omits the announced/robust equivalent. Pagination is the one control
   that gets it right; its siblings should copy it.
2. **Perceivable by colour alone** (UC6, and the focus story UC2) — in-text links
   and the untuned focus ring both lean on colour/theme luck rather than a
   guaranteed non-colour cue.
3. **Keyboard operability of the shell** (UC1, UC2) — no bypass block, no tuned
   focus indicator: the "operate it without a mouse" family.
4. **Robust, associated form errors** (UC8) — no summary, no field association,
   no focus move, across all four main forms.
5. **Consistency of destructive actions and content wording** (UC9, UC12) — mixed
   confirm/one-click deletes; "OTP" jargon.

## Subject × dimension grid (within-file, different problems)

| Subject | Distinct dimensions | Severity |
|---|---|---|
| `app/views/layouts/application.html.erb` | skip link (UC1), nav current (UC3), nav label (UC4), flash live region (UC7) — **4** | **High** (single shared file behind 4 UI failures) |
| `app/assets/stylesheets/application.css` | focus untuned (UC2), in-text link colour-only (UC6), unverified contrast claim — **3** | **High** (the one stylesheet behind app-wide a11y risk) |
| `app/views/profiles/show.html.erb` | heading order (UC5), view-toggle state (UC3) — **2** | Medium |
| `app/views/collectibles/_collectible.html.erb` | heading skip source (UC5) — **1** (plus code N+1) | Medium |
| `settings/visibility/show.html.erb` | destructive confirmation (UC9) ×2 sites | Medium |
| the two `_search_help.html.erb` | table headers (UC11), discoverability (UC10) — **2** | Low |

**Convergence interpretation.** The **layout** (`application.html.erb`) crosses
the 3-dimension floor with four separate failures and gets its own High: it is the
single shared file every screen inherits, so the skip link, nav-current,
nav-label, and flash-region fixes all land in one place — fixing it once fixes
every screen. The **stylesheet** likewise carries three app-wide dimensions
(focus, link colour, the blanket contrast claim) and gets a High for the same
"one file, whole-app blast radius" reason. Both escalations rest on enumerated
failures with `file:line`, not a cohesion impression.

## Leverage-ordered fix list (by findings dissolved, not by cost)

1. **The layout accessibility bundle** (UC1, UC3, UC4, UC7) — skip link,
   `<main id>`, `aria-current`, nav labels, live-region flashes: several findings,
   one file, low cost. Highest leverage.
2. **One tuned `:focus-visible` style** (UC2) — small CSS, fixes keyboard
   visibility app-wide across every theme.
3. **Underline in-text links** (UC6) — one CSS rule scoped to prose links; fixes
   the monochrome-theme disappearance.
4. **Error-summary + field association on the four forms** (UC8) — medium cost,
   high value for keyboard/SR users.
5. **Heading-level local on the card partial** (UC5) — small.
6. **Consistent destructive confirmation** (UC9), **friendlier 2FA label +
   `inputmode`** (UC12), **`scope="col"`** (UC11), **worked search example**
   (UC10) — small each.

## Credits (falsified before writing)

- **Pagination is the accessibility exemplar.** `_pagination.html.erb:8` uses
  `aria-current="page"` and a labelled `<nav aria-label="Pagination">`; the fix
  for UC3/UC4 is to make the other controls match it, not to invent a pattern.
- **The view-toggle wrapper is a labelled group.** `profiles/show.html.erb:32`
  uses `role="group" aria-label="View"` — correct; only the *active* child's
  `aria-current` is missing (UC3), so the container is credited, the item is not.
- **Form inputs are labelled.** Every input checked has an associated `<label>`
  (`form.label`, `label_tag` with matching `id`, or a visually-hidden label on
  the search/toolbar fields); the search box uses `class: "visually-hidden"`
  rather than a missing label. Falsified across the collectible form, both search
  forms, the visibility forms, and the import fields — no unlabelled input found.
  The gap is error *association* (UC8), not labelling.
- **`<pre>`/code blocks reflow safely.** The search-help and import-help code
  blocks are `overflow-x: auto` (checked in the stylesheet), so no horizontal
  page scroll — verified, not assumed.
