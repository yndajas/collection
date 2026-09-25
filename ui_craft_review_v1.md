# UI Review: Collection

Usability and accessibility review of the app's views, layout and stylesheet
through the combined `ui-craft` lens: Krug / Nielsen / Norman for usability and
WCAG 2.2 AA plus GOV.UK / dxw guidance for accessibility. Each finding cites the
principle and, for accessibility, the WCAG success criterion (with its level).
Tests are out of scope (prototype branch).

**12 findings — 2 High, 6 Medium, 4 Low.**

---

## Verdict

This is an accessibility-aware front end, not a retrofit. The markup reaches for
the right semantic element first, controls are labelled, and the stylesheet is
built around a rem-based type scale with contrast pairs that are annotated and
claim AA. A reviewer's usual top-of-list findings (unlabelled inputs, div-soup,
colour-only state, px font sizes, missing page titles) are already handled.

What remains is a consistent, fixable pattern: **state and status that is
visible but not programmatic.** The current page, the active view, form errors
and flash messages all read correctly to a sighted mouse user and are invisible
or unannounced to an assistive-technology user. Pagination already shows the
right way to do it (`aria-current="page"`); the fix is to apply that same habit
everywhere else. Two structural gaps (a skip link, and error-summary wiring)
outrank the rest because they block a task rather than merely add friction.

---

## What's already working (credit first)

- **Landmarks and semantics** - `<header>`, `<nav>`, `<main>`, `<article>`,
  `<section>`, `<ul>/<li>` are used for their meaning, not as generic boxes.
  `lang="en"` is set (WCAG 3.1.1 A) and every page sets a distinct `<title>` via
  `content_for :title` (2.4.2 A).
- **Forms** - inputs are labelled (`form.label`, or a `visually-hidden` label on
  the search box), related controls are grouped in `<fieldset>` with a
  `<legend>`, and checkboxes wrap their text in `<label>`. This is the GOV.UK
  form pattern done by hand.
- **Pagination** is the model citizen: `<nav aria-label="Pagination">` with
  `aria-current="page"` on the current page. Every other current-state indicator
  in the app should copy it.
- **Destructive actions** use a confirmation interstitial (`confirm_delete`) with
  an explicit "This can't be undone" and a Cancel route (Nielsen #5 error
  prevention; WCAG 3.3.4 Error Prevention AA).
- **Visual layer** - one rem-based type scale (honours user zoom; 1.4.4 AA), a
  dedicated `--field-border` token documented as meeting 1.4.11 (>=3:1 for
  control boundaries), per-theme contrast pairs annotated "WCAG-AA verified", and
  no `outline: none` anywhere, so the browser's default focus ring survives.

---

## The recurring theme

**Status and current-state are shown, not announced.** Nine of the twelve
findings are one idea: information conveyed only by pixels. Nielsen's "visibility
of system status" and WCAG's "programmatically determinable" (1.3.1 A) are the
same requirement seen from two sides. Pagination already solves it; the work is
to make the nav, the view toggle, the settings subnav, the flash messages and
the form errors expose their state the way pagination exposes the current page.

---

## Findings

Format: **[Severity] Title** - `file:line` - *principle / WCAG SC (level)* -
description **→ fix**.

### High

- **[High] No skip link; `<main>` isn't targetable** -
  `app/views/layouts/application.html.erb:22,41` -
  *WCAG 2.4.1 Bypass Blocks (A) / Krug "don't make me work"* - Every page forces
  keyboard and screen-reader users through the header and nav before reaching
  content, on every navigation. The nav is short, so the burden is modest, but
  this is an A-level requirement and the fix is trivial.
  **→ Add a visually-hidden-until-focused "Skip to content" link as the first
  element in `<body>`, and give `<main id="main-content">` the target.**

- **[High] Form errors are shown but not wired to the fields** -
  `app/views/collectibles/_form.html.erb:9` -
  *WCAG 3.3.1 Error Identification (A), 3.3.3 Error Suggestion (AA) /
  Nielsen #9 help users recover* - The `.errors` summary is a plain `<div>`:
  it takes no focus on submit, has no `role`, and its messages aren't linked to
  the fields they concern. The offending inputs get no `aria-invalid` and no
  `aria-describedby`. A screen-reader user who submits an invalid form hears
  nothing change and can't find which field failed. (Same pattern in the Devise
  and settings forms.)
  **→ Follow the GOV.UK error-summary pattern: a focusable
  `role="alert"` summary at the top whose entries link to each field by `id`,
  plus `aria-invalid="true"` and `aria-describedby` tying each field to its
  message.**

### Medium

- **[Medium] No custom focus-visible style** -
  `app/assets/stylesheets/application.css` (no `:focus`/`:focus-visible` rule) -
  *WCAG 2.4.7 Focus Visible (AA), 2.4.11 Focus Appearance (2.2 AA)* - Nothing
  removes the UA outline (good), but nothing enhances it either, so the focus
  indicator is whatever each browser draws over seven themes and coloured
  surfaces - and on the brand-filled `.view-toggle a.active` or a dark theme it
  can fall below the 2.4.11 contrast/size bar. Hover states are defined
  throughout; focus states are not, so keyboard users get weaker affordance than
  mouse users. **→ Add one explicit `:focus-visible` ring (a token-coloured
  outline with offset) so focus is consistent and high-contrast across themes.**

- **[Medium] Flash messages aren't announced** -
  `app/views/layouts/application.html.erb:42` -
  *WCAG 4.1.3 Status Messages (AA) / Nielsen #1 visibility of system status* -
  "Added to your collection", "Removed…", and error alerts render as a plain
  `<p>`. After a redirect, focus is at the document top and a screen-reader user
  may never learn the action succeeded. **→ `role="status"` on the notice and
  `role="alert"` on the alert (an `aria-live` region).**

- **[Medium] Current item is visual-only across nav, subnav and view toggle** -
  `app/views/settings/_nav.html.erb:2`,
  `app/views/profiles/show.html.erb:31`, `app/views/layouts/application.html.erb:26` -
  *WCAG 1.3.1 Info and Relationships (A), 4.1.2 Name, Role, Value (A)* - The
  active settings tab and the active Cards/List view are distinguished only by an
  `.active` class (colour + weight, or a brand fill). Pagination sets
  `aria-current="page"`; these don't. A screen-reader user tabbing "Cards, List"
  can't tell which is active. **→ Add `aria-current="page"` (nav/subnav) and
  `aria-current="true"` (view toggle) to the active link, mirroring pagination.**

- **[Medium] Multiple nav landmarks share no distinct names** -
  `app/views/layouts/application.html.erb:26`, `app/views/settings/_nav.html.erb:1` -
  *WCAG 1.3.1 (A) / GOV.UK landmark guidance* - The primary nav and the settings
  subnav are both bare `<nav>`. A screen reader lists two "navigation" landmarks
  with no way to tell them apart. (Pagination already names itself.)
  **→ Give each a distinct `aria-label`, e.g. "Primary" and "Settings".**

- **[Medium] Heading level jumps h1 -> h3 on the collection grid** -
  `app/views/collectibles/_collectible.html.erb:6`, `app/views/profiles/show.html.erb:10` -
  *WCAG 1.3.1 (A), 2.4.10 Section Headings (AAA)* - The card partial hardcodes
  `<h3>` so it nests correctly under the homepage's `<h2>` sections, but on the
  collection page the cards sit directly under the `<h1>` with no `<h2>` between,
  so the outline skips a level. **→ Make the card heading level a local
  (`heading_level:` defaulting to 3), or add the missing `<h2>` on the collection
  page.**

- **[Medium] External search links open in a new tab with no warning** -
  `app/views/collectibles/_collectible.html.erb:32` -
  *WCAG 3.2.5 Change on Request (AAA) / Nielsen #3 user control* - The PSNProfiles
  / Steam / Goodreads tags use `target="_blank"` with no visible or aural cue
  that they leave the page in a new window - unexpected for screen-reader and
  magnifier users. `rel="noopener"` is present (good). **→ Signal "opens in a new
  tab" (visible text or a visually-hidden suffix); consider `rel="noopener
  noreferrer"`.**

### Low

- **[Low] Placeholder does double duty and may be low-contrast** -
  `app/views/collectibles/_search_form.html.erb:9` (no `::placeholder` rule in CSS) -
  *WCAG 1.4.3 Contrast (AA) / Nielsen: placeholders aren't labels* - The search
  placeholder carries the query-syntax example ("is:completed system:switch
  zelda"); default UA placeholder colour often misses 4.5:1, and it vanishes on
  focus. The field is properly labelled and the `search_help` disclosure repeats
  the syntax, so this is minor. **→ Set an explicit `::placeholder` colour that
  meets 4.5:1; keep the example in the help, not only the placeholder.**

- **[Low] "Following" toggle doesn't name its action** -
  `app/views/profiles/_follow_button.html.erb:3` -
  *WCAG 4.1.2 (A) / Norman: signifiers* - The accessible name is "Following"; the
  intent (that pressing it unfollows) lives only in `title`, which screen readers
  read inconsistently. **→ Add `aria-label="Unfollow this collection"` (or make
  the visible text state the action).**

- **[Low] Export link text is ambiguous out of context** -
  `app/views/profiles/show.html.erb:47` -
  *WCAG 2.4.4 Link Purpose in Context (A) / GOV.UK link-text guidance* - "CSV"
  and "JSON", read in a links list, don't say what they do. The preceding
  "Export" word helps sighted users but isn't part of either link.
  **→ `aria-label="Export as CSV"` / `"Export as JSON"`, or fold "Export" into
  the link text.**

- **[Low] Contrast is asserted, not continuously verified** -
  `app/assets/stylesheets/application.css` (7 themes) -
  *WCAG 1.4.3 (AA), 1.4.11 Non-text Contrast (AA)* - The comments claim every
  pair is AA and my spot-checks (light `--muted` on `--bg`, dark `--brand` links
  on `--surface`) pass, but seven themes multiplied by tag / button / label /
  disabled states is a lot of surface to hold by hand, and the inline per-label
  background colours are the easiest to drift. **→ Run an automated audit across
  all themes x states so the assertion is checked, not just stated.**

---

## If you do four things (ROI order)

1. **`aria-current` + `role="status"`/`"alert"` + nav `aria-label`s** - three tiny
   edits that clear four findings (current-state and status announcement), and
   pagination already shows the pattern. Highest ROI.
2. **Add the skip link and `main#main-content`** - one A-level failure, one small
   partial, every page fixed.
3. **Wire up the form error summary** - the one place a user is actively stuck;
   adopt the GOV.UK error-summary pattern for `_form` and reuse it in the Devise
   and settings forms.
4. **Add a `:focus-visible` ring token** - restores keyboard/mouse affordance
   parity and de-risks 2.4.11 across the themes; do it once, centrally.
