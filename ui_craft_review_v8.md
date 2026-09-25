# UI-craft review (v8)

**Lens:** ui-craft - usability (Krug, Nielsen, Norman) and accessibility
(WCAG 2.2 AA, GOV.UK, dxw).
**Scope:** every view, partial and layout under `app/views/`, the single
stylesheet `app/assets/stylesheets/application.css`, and the user-facing content
and accessible names assembled in helpers/controllers (labels, error text, flash
messages, alt text) - scoped by lens, not file type.
**Excluded:** tests, by request; code-quality concerns (see the code-craft
report); back-end correctness of search/query behaviour.
**Depth:** exhaustive - the low-severity tail is reported.
**Execution:** inline single pass, walked twice (once as a first-time sighted
mouse user, once as an assistive-technology user), with the status-parity,
landmark and per-theme sweeps applied across the whole scope.

Coverage: 40 view/partial/layout files, the stylesheet (7 themes) and the
shared helpers - all swept per WCAG criterion and per Nielsen heuristic across
the whole scope, not screen by screen. No screens were sampled silently.

The baseline is strong and clearly accessibility-aware: every control is
labelled, grouped inputs use `fieldset`/`legend`, pagination is a model
`aria-current` implementation, the type scale is in `rem`, and colour is never
the *sole* carrier of label meaning (see Credits). The findings concentrate in
the shared chrome (layout, settings nav) and the 2FA flow, plus one systematic
gap - a designed focus indicator - that touches every screen and theme.

---

## Findings by severity

### High

#### H1. The 2FA QR code has no text alternative, on a path every new user hits

`app/views/two_factor_authentication/setup/show.html.erb:5-7` renders only the
QR SVG (`@qrcode`, built in `setup_controller.rb:27`). There is **no manual
setup key** and **no accessible name on the SVG** - a screen-reader user, or
anyone who cannot scan a code with a second device, has no way to enrol.

This is **WCAG 1.1.1 Non-text Content (A)** - information conveyed as an image
with no text equivalent. It is High rather than Medium because
`users.otp_required_for_login` defaults to `true` (`db/schema.rb:111`) and
`ApplicationController#ensure_2fa_setup` force-redirects un-enrolled users here
(`application_controller.rb:27-34`): the inaccessible step is **mandatory
onboarding for every account**, not an optional corner.

**Fix:** also render the shared secret / provisioning URI as selectable text
("Can't scan? Enter this key manually: `XXXX XXXX ...`"), and give the SVG a
`role="img"` with an `aria-label` (or a visually-hidden explanation). The secret
is already in hand as `current_user.otp_secret`.

#### H2. No skip link, and `main` is not targetable (Bypass Blocks)

The layout (`app/views/layouts/application.html.erb`) has a header + nav on every
page but no "skip to content" link, and `<main class="site-main">` (line 41) has
no `id` to target. Keyboard and screen-reader users must tab through the whole
masthead nav on every page load. This is **WCAG 2.4.1 Bypass Blocks (A)**.

Pivoting the layout as a subject, it is the single point behind three separate
accessibility gaps (this one plus H3 and L2 below), which is why it warrants its
own escalated finding.

**Fix:** add `<a href="#main" class="skip-link">Skip to content</a>` as the
first focusable element and `id="main"` on `<main>`; style `.skip-link` to be
visually-hidden until focused (the `.visually-hidden` pattern already in the CSS
is the basis).

### Medium

#### M1. No designed focus indicator, across seven themes

Searched the whole stylesheet (`grep -n 'focus\|outline' application.css`):
**zero** `:focus`, `:focus-visible` or `outline` rules. The app never sets
`outline: none` (good - so the browser default ring survives, and **2.4.7 Focus
Visible (AA)** is technically met), but it never *designs* one either. Two
consequences:

- On brand-filled controls (`.button`, `.view-toggle a.active`) and on the
  darker themes (`monochrome_dark` bg `#161618`, `dark` bg `#15171c`) the UA
  default outline can fall below the contrast/area expectations of **WCAG 2.4.11
  Focus Appearance (AA, new in 2.2)**.
- The app is otherwise meticulous about theming every colour; leaving focus to
  the UA default is the one interactive state not brought into that system.

This is the textbook "focus indicator across all themes" whole-scope finding:
it is asserted once in the stylesheet and affects every screen and theme.

**Fix:** one rule - `:focus-visible { outline: 2px solid var(--brand); outline-
offset: 2px; }` (plus a check that `--brand` clears 3:1 against `--surface`/
`--bg` in each theme; on the two-tone monochrome themes `--brand` is the ink
colour, which is fine).

#### M2. Active-state parity: `aria-current` on pagination but not its siblings

Pagination sets `aria-current="page"` on the current page
(`_pagination.html.erb:8`) - the model to copy. Its siblings that show a
"current/active" state do **not**, and convey it by colour/weight alone:

- **View toggle** (`profiles/show.html.erb:2-6`): the active view gets
  `class: "active"` only. `.view-toggle a.active` (CSS 314) is a brand fill -
  a colour-only cue, unannounced. (**WCAG 1.4.1 Use of Colour**, **4.1.2
  Name/Role/Value**.)
- **Settings sub-nav** (`settings/_nav.html.erb:2-5`): active link is
  `class: "active"` → `.subnav a.active` colour + `font-weight: 700` (CSS 363),
  no `aria-current`.

**Census** of every "current/active" cue (`grep -rn 'aria-current\|\.active\|current_page?' app/views app/assets`): pagination (correct), view-toggle (missing),
settings sub-nav (missing). Two of three siblings miss it.

**Fix:** add `aria-current="page"` to the active view-toggle link and the active
sub-nav link. On the view toggle, since font-weight isn't changed, the active
state is *purely* colour today - `aria-current` plus a non-colour cue (weight or
an inset marker) fixes both criteria.

#### M3. All four settings pages present the same visible `<h1>Settings</h1>`

`settings/show`, `settings/visibility/show`, `settings/labels/index` and
`settings/sorting/show` all render `<h1>Settings</h1>` (e.g.
`settings/show.html.erb:3`, `visibility/show.html.erb:3`). A screen-reader user
navigating by heading, or reading the page title region, cannot tell the four
sub-pages apart - the only differentiator is the sub-nav's active item, which
per M2 is colour-only and unannounced. (**WCAG 2.4.6 Headings and Labels**;
Nielsen: visibility of system status - "where am I?".)

Note the `content_for :title` values *are* distinct ("Settings",
"Visibility", "Labels", "Collectible sorting"), so only the visible `<h1>` is
wrong. **Fix:** make each `<h1>` name its own page ("Visibility settings", etc.),
or keep "Settings" as an eyebrow and promote the section name to `<h1>`.

#### M4. Destructive actions are inconsistent and under-signalled

Two different treatments for "delete", with no clear rule:

- **Confirmation page:** collectibles (`confirm_delete.html.erb`) and labels
  (`labels/confirm_delete.html.erb`) route through a dedicated confirm screen
  with a danger button.
- **Instant delete, styled as a text link:** custom sorts
  (`sorting/show.html.erb:42`), share links (`visibility/show.html.erb:84`),
  profile accesses (`visibility/show.html.erb:47`) and unfollow
  (`_follow_button.html.erb:3`) all use `button_to ... class: "button-as-link"`
  - a state-changing POST/DELETE that **looks like an inline link** and fires on
  first click with no confirmation.

Two issues: **error prevention** (Nielsen #5 / WCAG 3.3.4 for the data-losing
ones - deleting a custom sort or revoking a share link is not trivially
reversible), and **affordance** (Krug/Norman - a destructive action dressed as a
plain text link doesn't signal its weight). Revoking a share link in particular
is irreversible and one mis-click away.

**Fix:** decide a rule - e.g. anything that destroys user-created data
(custom sort, share link, access grant) gets either a confirm step or at least a
visually distinct control, while a reversible toggle (unfollow) can stay
lightweight.

#### M5. Form errors aren't associated with their fields or focused

Every form renders errors as a summary block only - `@collectible.errors.
full_messages` in a `.errors` div (`collectibles/_form.html.erb:9-18`), and the
one-line `to_sentence` variant in settings/labels/custom-sorts. None of them:
link each message to the offending field, move focus to the summary on
re-render, or set `aria-invalid`/`aria-describedby` on the inputs. A
screen-reader user is told "1 error stopped this" but not which field, and isn't
taken there. (**WCAG 3.3.1 Error Identification**; GOV.UK error-summary
pattern.)

This is one shared pattern across ~6 forms, so it is a single fix with wide
reach. **Fix:** adopt the GOV.UK-style error summary (focusable `role="alert"`
container with in-page links to each field) and mark invalid inputs. Reasonable
to stage after the higher items on a prototype, but it's the same code in every
form.

#### M6. External "look it up" links don't look clickable at rest

The per-collectible search links render as `.tag--link` pills
(`collectibles/_collectible.html.erb:31-33`, `show.html.erb:52-54`).
`.tag--link` (CSS 336-341) gives them a surface background and a border but
**no brand colour and no underline** until `:hover`; the resting state is
visually identical to the static `.tag` traits/labels beside them. Krug's "make
the clickable things obviously clickable" - a sighted user can't tell the
actionable pills from the decorative ones without hovering. **Fix:** give
`.tag--link` a resting affordance (brand text colour or an underline), so it
reads as a link, not a chip.

### Low

#### L1. Multiple `nav` landmarks, only one named

`grep -rn '<nav' app/views` finds four: `.site-nav` (layout, unnamed),
`.subnav` (settings, unnamed), `.breadcrumb` (`collectibles/show.html.erb:4`,
unnamed) and `.pagination` (`aria-label="Pagination"`, named). On the settings
pages two unnamed `nav`s coexist (site + sub). Assistive tech announces
"navigation, navigation" with no way to tell them apart. **WCAG 1.3.1 / landmark
naming.** **Fix:** `aria-label` each (`"Primary"`, `"Settings"`, `"Breadcrumb"`).

#### L2. Flash messages aren't announced as status

`layouts/application.html.erb:42-43` renders notice/alert as plain `<p
class="flash">`. On a full page navigation they're in reading order (so not a
hard failure), but confirmations after an action would be more robust as a live
region. **Fix:** `role="status"` on the notice and `role="alert"` on the alert.
Low, given every flash today arrives on a fresh page load.

#### L3. "OTP" jargon in the 2FA labels

Both 2FA forms label the field `"OTP"`
(`two_factor_authentication/sessions/show.html.erb:8`, `setup/show.html.erb:13`)
while the surrounding prose correctly says "the 6-digit code". "OTP" is jargon
(Nielsen: match between system and the real world; plain-language guidance).
**Fix:** label it "6-digit code" (and add `inputmode="numeric"`
`autocomplete="one-time-code"` is already present - good).

#### L4. The 2FA screens are visually unstyled relative to the rest of the app

The two 2FA templates use bare `<div>` wrappers with no `.stack`/`.field`/
`.actions` classes (`setup/show.html.erb:11-20`), so they render as unstyled
stacked inputs unlike every other form. Consistency/polish (Nielsen:
consistency and standards). Cosmetic, but it's the first screen a new user sees.

#### L5. Straight vs curly quotation marks in "no results" copy

`profiles/show.html.erb:75` uses straight quotes around the query
(`matches "..."`), while `collections/index.html.erb:23` uses curly quotes
(`matches "..."`). Same message, two styles. Pick one (curly reads better in
rendered HTML). Trivial content consistency.

#### L6. `autofocus` on the collectible title field

`collectibles/_form.html.erb:22` sets `autofocus: true`. Auto-moving focus on
load can disorient screen-reader and screen-magnifier users (it skips the page
heading/context). Low; consider dropping it or keeping it only where the form is
the entire page purpose.

#### L7. Required field not programmatically marked

`title` is required (validated, and `NOT NULL`) but the input carries no
`required`/`aria-required` and the label doesn't mark it
(`collectibles/_form.html.erb:20-23`). Users only learn it's required by
submitting. **Fix:** mark it required in the label and on the input.

#### L8. `labels/index` list section has no heading

`settings/labels/index.html.erb:32` opens a `<section class="section">` holding
the existing-labels list with no heading, sandwiched between "Add a label"
(`h3`) and nothing. A screen-reader user landing there has no signpost. Minor;
add an `<h3>Your labels</h3>`.

#### L9. Heading level jump on the visibility page

`settings/visibility/show.html.erb` goes `h1` → `h2` (Visibility) →
`h3` (People with access, line 35) → `h3` (Share links, line 57), but the two
`h3` sections are *siblings* of the Visibility section, not children of it - so
they read as sub-parts of "Visibility" when they're peers. Compare
`settings/show.html.erb`, which correctly uses sibling `h2`s. Low; make the
three sections consistent siblings.

#### L10. Active view-toggle link points to the current view

`profiles/show.html.erb:2-6` renders the active view as a live link to the page
you're already on - clicking it is a no-op reload. Minor; either render the
active item as a non-link `<span>` (matching how pagination renders its current
page) or leave it, but pair with M2's `aria-current`.

---

## Themes (across-files, same problem)

- **State shown but not announced / colour-only (M2, L10).** The active view and
  active sub-nav item are conveyed by colour (and sometimes weight) without
  `aria-current`. Pagination already does this right - the fix is to make the
  siblings match it.
- **Landmark naming and bypass (H2, L1).** No skip link, and three of four `nav`
  landmarks are unnamed. Both are whole-scope consistency issues in the shared
  chrome.
- **Accessible names/text assembled outside the markup, left incomplete (H1,
  M5, L3).** The QR's missing alternative, the un-linked error messages and the
  "OTP" label are all cases where the text a screen-reader user needs lives in a
  helper/controller/label and wasn't finished.
- **Destructive-action treatment (M4).** Two inconsistent patterns for delete.

## Subjects (within-one-file, different problems) - the hotspot grid

| Subject | Dimensions it collects | Verdict |
|---|---|---|
| `layouts/application.html.erb` | no skip link (2.4.1) · unnamed nav (1.3.1) · flash not announced (4.1.3) | **Escalated (H2)** - 3 dimensions, shared by every page |
| 2FA views (`setup/show`, `sessions/show`) | QR no text alt (1.1.1) · jargon label (3.3.2/plain language) · unstyled/inconsistent | **High (H1)** - the 1.1.1 failure alone escalates, on a mandatory path |
| `settings/_nav` + the 4 settings pages | no `aria-current` (M2) · duplicate `<h1>` (M3) | Medium - two dimensions on the settings subsystem |
| `application.css` | no focus indicator across 7 themes (M1) | Medium, broad reach |
| `profiles/show.html.erb` | view-toggle colour-only (M2) · no-op active link (L10) | Low/Medium, folded into M2 |

## Per-theme sweep (the whole-scope colour check)

`grep`-swept every `[data-theme=...]` block. The stylesheet's "all pairs
WCAG-AA verified" comment is a *colour* claim; I spot-checked the tightest pairs
rather than all 7 × N:

- Computed the most suspicious - `retro` link/brand `#b5451b` on bg `#f3e9d2` -
  at **4.54:1**, which clears 4.5:1 AA for normal text (just). `--muted`
  `#585f6d` on light bg `#f6f7fb` ≈ **6:1**. The `--field-border` tokens are
  explicitly chosen ≥3:1 for **1.4.11 Non-text Contrast** (comment at CSS 39),
  and `#7f8593` on white ≈ 3.6:1 holds.
- **The claim covers colour pairs but not focus** - which is exactly the gap M1
  names. So the credit stands *scoped*: text/background contrast verified on a
  sample including the tightest pair; focus-state contrast is unaddressed.

---

## Fix list, ordered by leverage (findings dissolved), not by effort

1. **Add the manual 2FA key + label the QR** (H1). *Small.* Unblocks mandatory
   onboarding for AT users - highest impact despite low effort.
2. **Skip link + `id="main"`** (H2). *Small.* One layout change, every page
   benefits.
3. **One `:focus-visible` rule** (M1). *Small.* Covers every control on every
   theme.
4. **`aria-current` on view-toggle + sub-nav, with a non-colour cue** (M2, part
   of L10). *Small.* Brings two controls up to pagination's standard.
5. **Distinct `<h1>` per settings page** (M3) and **`aria-label` per nav** (L1).
   *Small.* Fixes "where am I?" for AT users, compounding with M2.
6. **GOV.UK-style error summary + `aria-invalid`** (M5). *Medium.* One pattern,
   ~6 forms.
7. **Decide a destructive-action rule** (M4). *Medium.*
8. **`.tag--link` resting affordance** (M6). *Small.*
9. Content/consistency tail: L2, L3, L4, L5, L6, L7, L8, L9.

---

## Credits (each falsified before writing)

- **Every form control has a programmatic label.** *Falsify:* checked each input
  - visible `form.label`s on the collectible/label/settings forms; visually-
  hidden `label_tag` on the search `q`, the visibility `identifier`/
  `description`/`expires_in`, and each `select` in the custom-sort composer
  (`custom_sorts/_form.html.erb:31-40`), each with a matching `id`. No unlabelled
  control found, including the dynamically-named import fields
  (`_import_fields.html.erb`, `id`/`for` paired via the `id` lambda).
- **Pagination is a correct `aria-current` implementation** - `nav aria-label=
  "Pagination"`, current page a non-link `<span aria-current="page">`, gaps as
  `…` (`_pagination.html.erb`). This is the pattern the other controls should
  copy (M2).
- **Grouped inputs use `fieldset`/`legend`.** *Falsify:* every checkbox/radio
  group - Status, Multiplayer, Labels (`_form.html.erb`), Format + Default type
  (`import.html.erb`), Profile visibility (`visibility/show.html.erb`), Applies-to
  (`_type_checkboxes.html.erb`) - is wrapped correctly. None left as bare
  checkboxes.
- **Colour is never the sole carrier of meaning.** *Falsify:* user labels show
  their **name as text** inside the colour chip (`collectibles_helper.rb:18-21`),
  and traits render as text tags. The one place colour *was* alone - the active
  view toggle - is caught in M2. Holds otherwise.
- **The type scale is in `rem`, honouring zoom** (CSS 6-30), with a documented
  no-`px`-for-text policy; themes re-skin colour only, never size. Verified: no
  `font-size` in `px` anywhere in the stylesheet.
- **GET search forms preserve state across paging/sort.** `page_url` merges
  existing query params (`application_helper.rb:50-52`) and the search form
  carries `view`/`token` as hidden fields (`_search_form.html.erb:5-6`), so
  paging keeps the filter/sort/view. Confirmed by tracing the params through.
- **Buttons vs links are used semantically.** State-changing actions (follow,
  sign out, delete, revoke) are `button_to`; navigation is `link_to`. *Falsify:*
  looked for a `link_to` performing a destructive action - none; the delete
  entry points are either `button_to` or a GET to a confirm page.
- **Search help uses a native `<details>`/`<summary>` disclosure** rather than a
  custom JS widget - accessible by default.
- **Responsive without horizontal scroll:** `auto-fill` card grid, `min-width:0`
  on the search input so it shrinks instead of overflowing (CSS 257), list rows
  stack under 40rem (CSS 687-695).

Scoped credit (see per-theme sweep): the "all pairs WCAG-AA verified" comment
holds for the text/background pairs I sampled, including the tightest; it does
not - and does not claim to - cover the missing focus indicator (M1).

---

## Self-grill (what the final pass surfaced)

- *Every screen swept, none sampled silently?* Yes - all 40 view files plus the
  stylesheet. The thin/near-empty ones (`private_profile`, `new`/`edit`
  wrappers, `_collection_list`) were read and are clean.
- *Status-parity census actually run, not exemplified?* Yes - grep for
  `aria-current`/`.active`/`current_page?` across views and CSS; 3 sites, 1
  correct, 2 flagged (M2).
- *Landmark census?* Yes - `grep '<nav'`, 4 landmarks, 3 unnamed (L1/H2).
- *High-stakes flows walked as an AT user?* Auth/2FA - H1 (blocking), L3, L4.
  Destructive actions - M4 (enumerated all 6 delete/revoke/unfollow sites).
  Forms/errors - M5 (all forms share the gap).
- *Per-theme claim challenged with a computed value, not waved through?* Yes -
  retro brand-on-bg computed at 4.54:1; the credit is scoped to what was checked
  and explicitly excludes focus.
- *Any 3+-dimension subject without an escalated finding?* No - the layout (H2)
  and the 2FA views (H1) both cross it and both have High findings.
