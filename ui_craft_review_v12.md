# UI-craft review — Collection (v12)

**Lens** UI craft (usability + accessibility). **Scope** `app/views/**`,
`app/helpers/**`, `app/assets/stylesheets/application.css`, `config/locales/**`,
the PWA manifest, and user-facing strings assembled in controllers. **Excluded**
code quality (see `code_craft_review_v12.md`), tests (prototype branch), Devise
gem-default views (not in repo — flagged as a gap). **Depth** Exhaustive.
**Execution** Inline, 2 independent passes (my inline sweep + one fresh critic
agent, diffed and reconciled). **Date** 2026-08-14. **Commit** `0a2078c`.

## Coverage caveat

A review samples a larger space; gaps remain, including possibly high-severity
ones. Two independent passes were run and reconciled. Live screen-reader/keyboard
behaviour and render-time target sizes were inferred from markup + CSS, not
exercised in a browser, and per-theme contrast was spot-checked rather than fully
recomputed. Scaffolding is in `ui_craft_review_v12.coverage.md`.

## Findings index

| ID | Severity | Effort | Dimension | Location(s) | Title | Status |
|----|----------|--------|-----------|-------------|-------|--------|
| UI-02 | High | Medium | WCAG 1.1.1 Non-text Content | 2fa/setup/show.html.erb | 2FA QR has no text alternative / manual key | open |
| UI-01 | Medium | Small | WCAG 2.4.7 Focus Visible | application.css | No custom focus indicator | open |
| UI-03 | Medium | Small | WCAG 4.1.3 Status Messages | layouts/application.html.erb:42 | Flash messages not announced | open |
| UI-04 | Medium | Small | WCAG 1.3.1 / 4.1.2 | settings/_nav.html.erb | Active nav item lacks `aria-current` | open |
| UI-05 | Medium | Small | WCAG 1.4.1 / 4.1.2 | profiles/show.html.erb:31 | View-toggle active state colour-only | open |
| UI-06 | Medium | Medium | WCAG 3.3.1 Error Identification | 5 forms | Error summaries not focus-managed or field-linked | open |
| UI-07 | Low | Small | WCAG 2.4.2 Page Titled | 2fa views | 2FA screens fall back to generic title | open |
| UI-08 | Low | Medium | WCAG 1.3.1 Info & Relationships | _collectible.html.erb:6 | Card `<h3>` skips h2 on profile grid | open |
| UI-09 | Low | Small | WCAG 1.3.1 / grouping | _import_fields.html.erb:74 | Import label group lacks fieldset/legend | open |
| UI-10 | Low | Small | Usability / mobile input | 2fa views | OTP field missing `inputmode="numeric"` | open |
| UI-11 | Low | Small | Nielsen: match / consistency | _search_form.html.erb | Two submit buttons (Search / Apply) ambiguous | open |
| UI-12 | Low | Small | WCAG 2.3.3 (baseline) | application.css | `prefers-reduced-motion` not honoured | open |
| UI-13 | Low | Small | Content / PWA polish | pwa/manifest.json.erb:19 | Placeholder description; `theme_color: "red"` | open |
| UI-14 | Low | Small | Screen-reader noise | application_helper.rb:44 | "★ Following" star announced as glyph | open |

## Findings

#### UI-02 · 2FA setup QR code has no accessible alternative or manual-entry key
**Severity** High · **Effort** Medium · **Confidence** High
**Dimension** WCAG 2.2 SC 1.1.1 Non-text Content; Nielsen "user control". Subject-convergence anchor for the 2FA flow (3+ dimensions: also UI-07, UI-10).
**Locations**
- app/views/two_factor_authentication/setup/show.html.erb:5-7 (`<%= @qrcode %>`)
- app/controllers/two_factor_authentication/setup_controller.rb:27 (`as_svg(...).html_safe`)
**Problem** The QR code is a raw inline `<svg>` with no `role`, `<title>`/
`aria-label`, or text alternative, and there is no visible secret/setup key to
type into an authenticator manually. A screen-reader user, or anyone without a
second device to scan with, cannot enable 2FA at all — and 2FA is required by
default (`otp_required_for_login` defaults true), so this can hard-block account
setup.
**Fix** Display the Base32 secret as selectable text ("or enter this key
manually: …") alongside the QR, and give the SVG a `role="img"` with an
`aria-label`/`<title>`. The manual key is the real fix; the label is the backstop.
**Verify** Keyboard/AT user can complete 2FA setup without scanning; the secret
is present as text and copyable.
**Related** Theme U-T3; subject 2FA flow (with UI-07, UI-10). #5 on the fix list.
**Status** open

#### UI-01 · No custom focus indicator
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 SC 2.4.7 Focus Visible (and 2.4.11 Focus Appearance)
**Locations**
- app/assets/stylesheets/application.css (no `:focus`/`:focus-visible` rule anywhere)
**Problem** The stylesheet defines no focus styling. It does *not* remove the
native outline (no `outline: none`), so the browser default ring survives — but on
custom brand-filled buttons and the low-contrast themed surfaces (`pastel_parlour`
pink, the two monochrome themes where `--text` and `--muted` are the same ink) the
UA default can be hard to see, and `select { appearance: none }` (CSS:218) strips
the native control affordance. Keyboard users can lose track of focus on some
themes/controls. (Reconciled down from a first-pass "no focus indicator at all":
the default ring does render.)
**Fix** Add one app-wide `:focus-visible { outline: 2px solid var(--text);
outline-offset: 2px; }` (or a `--focus` token) so every control has a
theme-consistent, high-contrast ring.
**Verify** Tabbing through each theme shows a clear ring on links, buttons,
toggles, and selects.
**Related** Theme U-T2. #1 on the fix list.
**Status** open

#### UI-03 · Flash messages are not announced to screen readers
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 SC 4.1.3 Status Messages; Nielsen "Visibility of system status"
**Locations**
- app/views/layouts/application.html.erb:42-43 (`<p class="flash">`)
**Problem** After nearly every action the app redirects with a flash ("Label
created.", "You can't follow that collection", ~25 messages across controllers),
rendered as a plain `<p>` with no `role="status"`/`role="alert"` or `aria-live`.
Positioned above the `<h1>`, it is easy for an AT user to miss; error alerts
(follows, profile_accesses) are the costliest to lose.
**Fix** Wrap the notice in `role="status"` and the alert in `role="alert"` (or an
`aria-live` region) in the layout partial.
**Verify** A screen reader announces the flash on page load after an action.
**Related** Theme U-T1. #2 on the fix list.
**Status** open

#### UI-04 · Active settings-nav item lacks `aria-current`
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 SC 1.3.1 / 4.1.2; colour-and-weight-only state cue
**Locations**
- app/views/settings/_nav.html.erb:2-5 (`class: ("active" if …)`)
**Problem** The current tab is conveyed only by `.subnav a.active { color:
var(--text); font-weight: 700 }` (CSS:363). No `aria-current` announcement, and on
the monochrome themes `--text` and `--muted` are the same ink, so the active tab
is distinguished by font-weight alone. Pagination gets this right (`aria-current
="page"`); its sibling nav does not.
**Fix** Add `aria-current="page"` to the active link.
**Verify** Screen reader announces "current page" on the active tab; DOM shows
`aria-current="page"`.
**Related** Theme U-T1. #3 on the fix list.
**Status** open

#### UI-05 · View-toggle active state is colour-only, not announced
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 SC 1.4.1 Use of Colour; SC 4.1.2 Name/Role/Value
**Locations**
- app/views/profiles/show.html.erb:2-6, 31-36 (`class: ("active" if @view == view)`)
- app/assets/stylesheets/application.css:314-315 (`.view-toggle a.active`)
**Problem** The selected view (Cards/List) is signalled purely by brand-fill
background, with no text/icon marker and no `aria-current`/`aria-pressed`, inside a
`role="group"` labelled "View" whose members carry no selected-state semantics. A
colour-blind or screen-reader user cannot tell which view is active. Same `active`
class, same omission as UI-04.
**Fix** Add `aria-current="true"` (or model as a tablist with `aria-selected`) and
a non-colour marker (e.g. a check or bolder border) on the active segment.
**Verify** Active view is announced and distinguishable without colour.
**Related** Theme U-T1. #3 on the fix list.
**Status** open

#### UI-06 · Error summaries not focus-managed, not linked to fields
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** WCAG 2.2 SC 3.3.1 Error Identification (GOV.UK error-summary pattern)
**Locations**
- app/views/collectibles/_form.html.erb:9-18
- app/views/settings/show.html.erb:7-9
- app/views/settings/labels/index.html.erb:14 and labels/edit.html.erb:6-8
- app/views/settings/custom_sorts/_form.html.erb:4-9
**Problem** Every form renders errors as a static block at the top. On a
full-page-reload Rails form the page reloads at the top with focus on `<body>`;
nothing moves focus to the summary, no message links to its field, and inputs get
no `aria-invalid`/`aria-describedby`. A keyboard/AT user submitting an invalid form
is left to hunt for what failed.
**Fix** A shared error-summary partial: a focusable summary (`tabindex="-1"`,
focused on render) listing errors as in-page links to each field, with
`aria-invalid="true"` + `aria-describedby` on the offending inputs.
**Verify** On failed submit, focus lands on the summary; each error links to its
field; inputs expose `aria-invalid`.
**Related** Theme U-T4. #4 on the fix list.
**Status** open

#### UI-07 · 2FA screens fall back to the generic title "Collection"
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 SC 2.4.2 Page Titled
**Locations**
- app/views/two_factor_authentication/setup/show.html.erb (no `content_for :title`)
- app/views/two_factor_authentication/sessions/show.html.erb (same)
**Problem** Both distinct auth steps resolve to the layout default `<title>
Collection`, unlike every other non-partial view. Poor tab/history
disambiguation on the auth flow.
**Fix** Add `content_for :title, "Set up two-factor authentication"` and
`"Verify two-factor authentication"`.
**Verify** Each 2FA screen has a distinct `<title>`.
**Related** Theme U-T3; subject 2FA flow. #5 on the fix list.
**Status** open

#### UI-08 · Card `<h3>` skips h2 in the profile-grid context
**Severity** Low · **Effort** Medium · **Confidence** High
**Dimension** WCAG 2.2 SC 1.3.1 Info & Relationships (shared-partial heading level)
**Locations**
- app/views/collectibles/_collectible.html.erb:6 (hardcoded `<h3>`)
- rendered under app/views/profiles/show.html.erb:62-68 (h1 → grid, no h2)
**Problem** The shared card partial always emits `<h3>`. On the homepage an `<h2>`
precedes it (correct); on the profile grid it sits directly under the page `<h1>`,
so the heading order jumps h1 → h3.
**Fix** Pass the heading level into the partial (a `heading:` local), or wrap the
profile grid in an appropriate `<h2>` section heading.
**Verify** Heading outline on the profile page has no skipped level.
**Related** —
**Status** open

#### UI-09 · Import-review label group lacks a fieldset/legend
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 SC 1.3.1 / grouped-controls consistency
**Locations**
- app/views/collectibles/_import_fields.html.erb:74-84 (label checkboxes under a `<span>`)
**Problem** The per-item label checkbox group uses `<span
class="import-item__label">Labels</span>` rather than the `<fieldset><legend>`
used for the same group in `_form.html.erb:68`. The group's name isn't associated
with its checkboxes for AT.
**Fix** Use `<fieldset><legend>Labels</legend>` to match `_form`.
**Verify** The checkbox group exposes "Labels" as its group name.
**Related** Theme U-T4.
**Status** open

#### UI-10 · OTP field missing `inputmode="numeric"`
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Usability — mobile input affordance
**Locations**
- app/views/two_factor_authentication/setup/show.html.erb:14
- app/views/two_factor_authentication/sessions/show.html.erb:8
**Problem** The 6-digit code field is `type="text"` with (correctly)
`autocomplete="one-time-code"` but no `inputmode="numeric"`, so mobile users get
the alphabetic keyboard.
**Fix** Add `inputmode="numeric"` (and optionally `pattern="[0-9]*"`).
**Verify** Numeric keypad appears on mobile for the OTP field.
**Related** Theme U-T3; subject 2FA flow.
**Status** open

#### UI-11 · Two submit buttons in one search form are ambiguous
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Nielsen: match between system and real world / consistency
**Locations**
- app/views/collectibles/_search_form.html.erb:12,23 ("Search" and "Apply")
- app/views/collections/_search_form.html.erb:8,20
**Problem** Each search form has two submit buttons that submit the same GET form
identically, but the labels imply "Apply" acts only on the sort. A first-time user
pauses to work out the difference.
**Fix** Use a single submit, or make the split behaviour real (e.g. auto-submit
sort on change, one "Search" button).
**Verify** One unambiguous submit path per form.
**Related** —
**Status** open

#### UI-12 · `prefers-reduced-motion` not honoured
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** WCAG 2.2 SC 2.3.3 Animation from Interactions (house baseline)
**Locations**
- app/assets/stylesheets/application.css (no reduced-motion block)
**Problem** No `@media (prefers-reduced-motion)` guard. The animation surface is
small today, but any transition added (buttons, toggles are candidates) will
ignore the preference.
**Fix** Add a `@media (prefers-reduced-motion: reduce)` block neutralising
transitions/animations.
**Verify** With reduced-motion set, no non-essential animation plays.
**Related** —
**Status** open

#### UI-13 · PWA manifest placeholder description and off-theme colour
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Content / PWA polish
**Locations**
- app/views/pwa/manifest.json.erb:19-21 (`"description": "Collection."`, `theme_color`/`background_color: "red"`)
**Problem** The description is a placeholder single word, and the splash/theme
colour is a hard `"red"` matching none of the seven in-app themes — jarring on
install.
**Fix** Write a real description; set `theme_color`/`background_color` to the
default theme's surface/brand.
**Verify** Install preview shows a sensible description and on-brand colours.
**Related** —
**Status** open

#### UI-14 · "★ Following" star adds screen-reader glyph noise
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Screen-reader content noise
**Locations**
- app/helpers/application_helper.rb:44 (`tags << "★ Following"`)
**Problem** The literal `★` is announced by some screen readers as "black star"
before "Following". The word carries the meaning; the glyph is decoration. (Not a
colour-only cue — text is present — so it passes 1.4.1.)
**Fix** Render the star as an `aria-hidden` decorative element separate from the
"Following" text, or drop it.
**Verify** Screen reader announces "Following", not "black star Following".
**Related** —
**Status** open

## Themes

### U-T1 · State shown but not announced
**Members** UI-03, UI-04, UI-05. **Root** current/active/status is conveyed
visually (colour, weight, fill) with no ARIA equivalent.
**Leverage** `aria-current` on the subnav + view-toggle and a live-region wrapper
on the flash partial dissolve three findings.

### U-T2 · Custom-styled controls without keyboard/AT affordances
**Members** UI-01. **Root** the app restyles links/buttons/selects but never
re-supplies a focus ring. **Leverage** one `:focus-visible` block fixes every
control app-wide. (Single-member theme — a prompt to re-sweep for other
stripped-affordance cases; none else found.)

### U-T3 · Auth/2FA is the weakest surface
**Members** UI-02, UI-07, UI-10. **Root** the 2FA flow was built for the sighted
scanning path only; plus the entire Devise view set is unreviewed (gap).
**Leverage** One focused fix to the two 2FA views (manual key + SVG label +
titles + numeric inputmode) dissolves three; reviewing the Devise views closes the
gap.

### U-T4 · Forms lack shared error-summary discipline
**Members** UI-06, UI-09. **Root** each form hand-rolls its error/group markup
without a shared accessible pattern.
**Leverage** A shared error-summary + fieldset partial fixes every form at once.

## Subject grid

| Subject | Dimensions (finding IDs) | # | Severity | Interpretation |
|---------|--------------------------|---|----------|----------------|
| 2FA flow (setup + verify views) | UI-02, UI-07, UI-10 | 3 | High | Non-text content + page title + input affordance all fail on the flow that gates account setup — anchored at UI-02 |
| layout (application.html.erb + css) | UI-01, UI-03 | 2 | Medium | Global focus + status-message gaps affecting every screen |
| forms (5 templates) | UI-06, UI-09 | 2 | Medium | Error identification + group semantics, same fix |
| profiles/show + _collectible | UI-05, UI-08 | 2 | Medium | View-toggle state + shared-partial heading level |

Convergence rule: a subject at 3+ distinct dimensions gets its own finding at High
or higher. The **2FA flow** reaches it (non-text content, page title, input
affordance) → anchored at UI-02 (High); no subject downgraded by a cohesion
impression.

## Leverage-ordered fix list

1. Add an app-wide `:focus-visible` outline (a `--focus` token) → dissolves UI-01
   across every screen. Effort Small.
2. Add `role="status"`/`role="alert"` (+ `aria-live`) to the flash partial →
   dissolves UI-03. Effort Small.
3. Add `aria-current` to the subnav active link + view-toggle active segment, with
   a non-colour marker → dissolves UI-04, UI-05 (2). Effort Small.
4. Shared error-summary + fieldset partial (focus-moving, field-linked,
   `aria-invalid`) across the forms → dissolves UI-06, UI-09 (2). Effort Medium.
5. 2FA fixes: manual setup key + SVG `role`/label, `content_for :title` on both
   views, `inputmode="numeric"` → dissolves UI-02, UI-07, UI-10 (3). Effort Medium.
6. Polish sweep: heading-level local on the card partial, reduced-motion block,
   manifest description/colours, decorative star → dissolves UI-08, UI-11, UI-12,
   UI-13, UI-14 (5). Effort Small–Medium.

## Credits (each falsified before writing)

- **Form label association is thorough.** Checked every input across all forms
  (coverage census): each has an associated `label`/`label_tag`, visually-hidden
  where hidden by design (`.visually-hidden` is a correct clip pattern,
  CSS:78-88). No unlabelled control found.
- **Grouped inputs use `<fieldset><legend>`** everywhere except the import-review
  label group (UI-09): Status/Multiplayer/Labels in `_form`, Format/Default type in
  `import`, Profile visibility, External links, `_type_checkboxes`. Verified each.
- **Pagination name/role/value is correct** — `_pagination.html.erb:3,8`: `<nav
  aria-label="Pagination">`, `aria-current="page"` on a non-link `<span>`, and its
  non-colour cue (border + weight, CSS:684) isn't brand-fill. Verified this is the
  *only* current-item control done right; its siblings (UI-04, UI-05) are not.
- **Destructive actions have interstitial confirm pages** — delete collectible and
  delete label both route through a dedicated "Delete this X?" page with "This
  can't be undone" and a Cancel link before the `button_to … :delete`. Share-link
  revoke and access-remove use inline `button_to` without a confirm page —
  acceptable (reversible, lower stakes). Falsified: confirmation is *not* uniform,
  but the gap is on the low-stakes actions, so it is a deliberate line, not a miss.
- **`lang="en"`, one `<main>`, one `<h1>` per page** — layout:2, :41; heading
  census confirms exactly one h1 per non-partial view (the only level-skip is
  UI-08).
- **Content is plain and active-voice** — empty states and flashes read well
  ("Your collection is empty. Add your first title above."); the dense search
  syntax is correctly progressive-disclosed behind `<details>`. Checked all empty
  states and controller notices.
- **Themes claim WCAG-AA** (CSS:34, 430) — spot-checked `--muted` on `--bg` and
  `--on-brand` on `--brand` (pass); **not** exhaustively recomputed across all 7
  themes, so this is recorded as an unverified caveat, not a passed credit.

## Coverage gaps (disclosed)

- **Devise views** (sign in, sign up, password reset, confirmations) are gem
  defaults, not in the repo, so their labels, autocomplete, error summaries, and
  titles are unreviewed — high-stakes auth screens. Recommend generating and
  reviewing them.
- **Contrast** not exhaustively computed across the 7 themes × colour pairs; the
  `--muted`-on-surface and label-text-on-fill pairs are the ones to actually check.
- **Live AT/keyboard behaviour** and render-time target sizes inferred from
  markup + CSS, not exercised in a browser.

---

A second fresh pass focused on the auth surface (including the Devise views) and
per-theme contrast is the highest-leverage way to close the remaining gaps.
