# UI-craft review (v9)

**Lens:** UI craft - usability (Krug, Nielsen, Norman) and accessibility (WCAG
2.2 AA, GOV.UK / dxw conventions). **Scope:** every view, partial, layout and the
single stylesheet, plus the content and accessible names assembled in
controllers, helpers and models. **Depth:** exhaustive (the low-severity tail is
reported). **Execution:** inline single pass, with the rigour apparatus in
`ui_craft_review_v9.coverage.md` (per-screen matrix, per-dimension search
commands, computed contrast ratios, credits ledger, self-grill). Walked twice:
as a first-time sighted mouse user and as an assistive-technology user.

This interface is, for a prototype, unusually careful about accessibility: real
labels everywhere, semantic `fieldset`/`legend`, a fully tokenised colour system
that genuinely meets AA across all seven themes (I recomputed every tight pair -
see the credits), destructive actions behind confirm pages, and a pagination
component that does `aria-current` correctly. The findings cluster into a handful
of themes, and the top three are the ones worth doing first.

---

## Themes (by symptom, swept across the whole interface)

### T1. State is shown but not announced (name/role/value parity)

The recurring accessibility theme. One component gets a status cue right and its
siblings convey the same state visually only. The tell is that **pagination**
already sets `aria-current="page"` (`application/_pagination.html.erb:8`) - so
the pattern is known - yet:

- **Settings sub-nav** (`settings/_nav.html.erb:2-5`): the current section is
  marked with `class="active"` -> styled as colour + bold weight
  (`application.css:363`), but no `aria-current`. A screen-reader user is not
  told which settings page they are on. WCAG 1.3.1 / 4.1.2. Add
  `aria-current="page"` to the active link.
- **View toggle** (`profiles/show.html.erb:31-36`): Cards/List inside
  `role="group" aria-label="View"`; the active one is `class="active"` (a brand
  fill) with no `aria-current`/`aria-pressed`. The selected view is not
  announced. Add `aria-current="true"` (or model as toggle buttons with
  `aria-pressed`).

Fixing the two brings them to parity with pagination.

### T2. Repeated landmarks are not distinctly named, and there is no bypass

`accessible-code.md`: multiple same-type landmarks each need a distinct
accessible name, and a header that repeats navigation needs a skip link to a
targetable `main`.

- **No skip link.** `layouts/application.html.erb` renders the site nav on every
  page and a `<main class="site-main">` with **no `id`** (`:41`). Keyboard and
  screen-reader users must tab through the whole header nav on every page. WCAG
  2.4.1 Bypass Blocks (A). Add a skip link as the first focusable element and
  `id="main-content"` on `<main>`.
- **Unlabelled `nav`s.** `site-nav` (`layout:26`), the settings `subnav`
  (`_nav.html.erb:1`) and the breadcrumb (`collectibles/show.html.erb:4`) are all
  `<nav>` with no `aria-label`. On the settings pages there are then two
  unlabelled "navigation" landmarks (site + subnav); on a collectible page,
  three (site + breadcrumb + pagination - only the last is named). Give each a
  distinct `aria-label` ("Primary", "Settings", "Breadcrumb").

### T3. Forms lack an error summary, field-level association, and focus management

`forms.md` / WCAG 3.3.1, 3.3.3, and the GOV.UK error-summary pattern. Every form
that can fail shares the same gaps - this is a cross-screen theme, not one form:

- On failed submit the collectible form lists errors in a plain
  `<div class="errors"><ul>` at the top (`_form.html.erb:9-18`); settings, labels,
  visibility and custom-sort forms show `errors.full_messages.to_sentence` in a
  bare div. **None** link each error to its field, set `aria-invalid`/
  `aria-describedby` on the offending input, or move focus to the summary. So a
  screen-reader user who submits an invalid form is left where they were, with no
  announced, navigable list of what to fix.
- The bulk-import review page marks failed items with a red border
  (`import-item--error`, `_import_fields.html.erb:5`) and prints the item's
  messages inline (`:9-11`), but again nothing is linked or focused, and the red
  border is a colour cue paired only with the (present) text - acceptable, but
  the summary/focus gap remains.
- Adopt the GOV.UK **error summary** shape: a titled list at the top, each entry
  a link to `#field_id`, focus moved to the summary on render, `aria-invalid` +
  `aria-describedby` on each bad field. One shared partial fixes every form.

### T4. Required fields are unmarked

`forms.md`: mark required vs optional unambiguously. Two optional fields say
"(optional)" (`custom_sorts/_form.html.erb:12`, `visibility/show.html.erb:61`),
but required fields (collectible **Title**, label **Name**, the OTP code) carry
no marker, so a first-time user only discovers the requirement by failing to
submit (Nielsen 5, error prevention). Mark required fields (or, GOV.UK style,
mark the optional ones and treat the rest as required consistently).

### T5. The 2FA screens are the weak spot (per-screen basics + image alt)

Both two-factor screens skip conventions the rest of the app follows:

- **No `<title>`.** `two_factor_authentication/setup/show.html.erb` and
  `sessions/show.html.erb` set no `content_for :title`, so both fall back to the
  generic "Collection" (`layout:4`). Every other screen has a distinct title.
  WCAG 2.4.2 - technically titled, but not descriptive/unique. Add titles.
- **QR code has no text alternative.** `setup/show.html.erb:5-7` renders the
  provisioning QR as an inline SVG (`@qrcode`) with no accessible name and, more
  importantly, **no manual entry key** as a fallback. A user who cannot scan (a
  screen-reader user, or anyone whose authenticator is on the same device) cannot
  complete setup. Offer the `otp_secret` as selectable text alongside the QR
  (standard 2FA-setup practice) and give the SVG an appropriate label or
  `aria-hidden` if the text key is the real path.
- The OTP inputs have a terse label ("OTP") and bare `<div>` wrappers rather than
  the `.field` structure used elsewhere; `inputmode="numeric"` would bring up the
  right keyboard. Minor, but they read as unfinished next to the other forms.

### T6. Small usability / visual notes

- The view-toggle and subnav active states lean on subtle cues (weight, or a fill
  that reads as a button); pair with T1's `aria-current` so the state is robust
  as well as visible.
- `.tag--link` (the external-search pills) have a near-invisible border in the
  light theme (~1.26:1). They are identifiable by their link text, so this is not
  a 1.4.11 failure, but the pill affordance is weaker than it looks. Low.

---

## Findings (ranked)

Accessibility failures that block or seriously impede a task outrank cosmetic
nits, per the lens.

### High

**UI-1. No skip link and an untargetable `<main>`.** Theme T2.
`layouts/application.html.erb:41`. Keyboard/AT users cannot bypass the repeated
header nav on any page. WCAG 2.4.1 (A). Add a visually-hidden-until-focused skip
link and `id="main-content"`.

**UI-2. Forms give no accessible error recovery.** Theme T3. Across the
collectible, settings, label, visibility and custom-sort forms: no error summary,
no field association, no focus move on failure. This is the difference between a
sighted user (who sees the red block) and a screen-reader user (who is told
nothing) being able to fix a form. WCAG 3.3.1 / 3.3.3.

**UI-3. 2FA setup can't be completed without scanning the QR.** Theme T5.
`two_factor_authentication/setup/show.html.erb`. No text/manual-key alternative to
the QR image. For a security-critical, mandatory flow (2FA is required by
default - `users.otp_required_for_login` defaults true), this can hard-block
setup for some users. WCAG 1.1.1. Provide the secret as text.

### Medium

**UI-4. Current state not announced (aria-current parity).** Theme T1. Settings
subnav (`_nav.html.erb:2-5`) and the view toggle (`profiles/show.html.erb:31-36`)
show the active item visually but not to assistive tech, while pagination does it
right. WCAG 1.3.1 / 4.1.2.

**UI-5. Repeated `nav` landmarks are unlabelled.** Theme T2. site-nav, settings
subnav and breadcrumb lack `aria-label`, so a screen-reader user hears several
undifferentiated "navigation" regions. WCAG 1.3.1 (and the AA landmark
conventions).

**UI-6. No visible-focus style is defined; the app relies on the UA default.**
`application.css` has no `:focus`/`:focus-visible` rule anywhere (grep in the
sidecar). Nothing removes the outline either, so focus **is** visible (the
default ring) and AA 2.4.7 is met - but the app tokenises and AA-verifies every
other colour pair while leaving the one interactive-contrast case it cannot
control unstyled and unchecked across the 7 themes (the default ring can be low
contrast on, e.g., the dark or pastel-parlour backgrounds). Add a
`:focus-visible` outline built from theme tokens so focus is consistent and
guaranteed. Medium (defensive; not a current failure).

**UI-7. Required fields unmarked.** Theme T4. WCAG best practice / Nielsen 5.

### Low

**UI-8. 2FA screens lack distinct titles.** Theme T5. Both fall back to
"Collection". WCAG 2.4.2.

**UI-9. OTP fields: terse label, no `inputmode`, ad-hoc markup.** Theme T5.
Add `inputmode="numeric"`, a clearer label ("6-digit code"), and the standard
`.field` wrapper.

**UI-10. `.tag--link` border barely visible in the light theme.** Theme T6 (~1.26:1).
Identifiable by text, so not a failure; nudge the border to the field-border
token for a clearer pill.

**UI-11. Flash messages aren't a live region.** `layouts/application.html.erb:42-43`
render notice/alert as plain `<p>`. Because they appear after full-page redirects
(not async), a live region isn't required and focus lands at the top of `main`
anyway - noting only so it's a deliberate choice, not a gap to "fix" with an
unnecessary `role="status"`.

---

## Subject grid (by hotspot - one file, several criteria)

| Subject | Criteria (distinct) | Verdict |
|---|---|---|
| `layouts/application.html.erb` | bypass/skip link (2.4.1), landmark naming (1.3.1), focus style (2.4.7 defensive) | **3 -> High** - the shell is the single highest-leverage subject (UI-1, UI-5, UI-6); one file, three independent fixes, every screen benefits |
| `settings/_nav.html.erb` | aria-current (UI-4), landmark label (UI-5) | 2 -> Medium |
| `two_factor_authentication/setup/show` | image alt/text key (UI-3), page title (UI-8), field markup (UI-9) | **3 -> High** - already captured as UI-3 High |
| shared form pattern (`_form` + settings/label/sort forms) | error summary (UI-2), field association (UI-2), required marking (UI-7) | clustered under UI-2/UI-7 |
| `profiles/show` view toggle | aria-current (UI-4), affordance (T6) | 2 -> Medium |

The layout is the standout hotspot: three unrelated accessibility criteria all
resolve in one file, and because it wraps every screen the fixes are global.

---

## Leverage-ordered fix list (by findings dissolved, not by cost)

1. **Fix the layout shell** (small): add the skip link + `id="main-content"`
   (UI-1), `aria-label` the site nav (part of UI-5), and add a token-based
   `:focus-visible` style (UI-6). One file, three findings, every screen.
2. **Build one shared error-summary partial** (moderate): summary list linked to
   `#field_id`, focus moved on render, `aria-invalid`/`aria-describedby` on bad
   fields. Dissolves UI-2 across every form at once; add required-field marking
   (UI-7) in the same pass.
3. **Complete the 2FA setup screen** (small): expose the secret as selectable
   text (UI-3), add titles to both 2FA screens (UI-8), and tidy the OTP field
   markup + `inputmode` (UI-9). Clears the whole T5 cluster.
4. **Add `aria-current` to subnav and view toggle, and label the remaining navs**
   (tiny): UI-4 + the rest of UI-5. Brings the siblings to pagination's standard.
5. **Nudge the `.tag--link` border** (trivial): UI-10.

---

## What already works (credits, falsified - see the ledger)

- **Colour contrast genuinely meets AA across all seven themes.** I did not trust
  the "all pairs WCAG-AA verified" comment - I recomputed the tight pairs
  (sidecar): muted text 5.5-17.4:1, brand links min 4.54:1, the small bold
  `.card__type` eyebrow min 5.0:1, all 63 label-colour/label-text pairs >= 4.5:1,
  and every form-control border >= 3:1 (WCAG 1.4.11). The claim holds. The
  tokenised type scale (rem-only, no hard-coded px) also protects text zoom.
- **Real, associated labels everywhere**, including visually-hidden labels on the
  search inputs and the sort/direction selects, and semantic `fieldset`/`legend`
  for grouped controls. No placeholder-as-label anti-pattern.
- **Pagination is a model component**: `aria-label="Pagination"` on the nav and
  `aria-current="page"` on the current page. (It's also what exposes the T1
  parity gap in its siblings.)
- **Destructive actions are confirmed**: both collectible and label deletion go
  through a dedicated `confirm_delete` page with an explicit `button_to` (Nielsen
  5 / error prevention), and the label-delete page even lists what will be
  affected.
- **`<html lang="en">` is set** (`layout:2`); `prefers-color-scheme` is respected
  implicitly via the user's chosen theme; the layout is responsive with a sensible
  small-screen breakpoint. Navigation answers "where am I / where can I go /
  where's home" well: persistent nav, a home-linking brand, breadcrumb on leaf
  pages, and a genuinely strong, well-documented search with a syntax help
  `<details>`.
