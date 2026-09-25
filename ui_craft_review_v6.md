# UI craft review (v6)

A whole-interface review through the ui-craft lens — usability (Krug, Nielsen,
Norman) and accessibility (WCAG 2.2 AA, GOV.UK / dxw). Ranked by impact, with a
theme view, a subject/hotspot grid, and an impact-ordered fix list.

## Scope

In scope — every view, partial, layout and the stylesheet, plus the helpers and
controllers that generate user-facing text (per the protocol: the words and
accessible names are often assembled outside the template):

- Layout: `layouts/application.html.erb`.
- Shared partials: `application/_pagination`, `collectibles/_collectible`,
  `collectibles/_search_form`, `_search_help`, `collectibles/_import_fields`,
  `_import_help`, `profiles/_profile_row`, `profiles/_follow_button`,
  `root/_collection_list`, `settings/_nav`, `settings/labels/_type_checkboxes`,
  `settings/custom_sorts/_form`.
- Screens: collectibles (`show`, `new`, `edit`, `confirm_delete`, `import`,
  `review`); collections (`index`); profiles (`show`, `private_profile`); root
  (`index`); settings (`show`, `visibility/show`, `sorting/show`,
  `labels/index|edit|confirm_delete`, `custom_sorts/new|edit`);
  `two_factor_authentication/*` (2).
- `app/assets/stylesheets/application.css` (695 lines, 7 themes).
- Text-generating code: `application_helper` (tags, relationship labels),
  `collectibles_helper` (subtitle/traits/label tag), flash and validation
  messages set in controllers.

Out of scope: Devise-generated auth views (registration/password) — the app's
own views are covered; JS behaviour (negligible).

Passes run: two walk-throughs (first-time sighted mouse user; keyboard +
screen-reader user), then a per-criterion sweep across the whole scope for
landmarks/bypass, headings, name/role/value + status parity, forms, content,
colour/contrast, and target size. I independently recomputed the theme contrast
ratios rather than trusting the stylesheet's "AA verified" comment.

## Impact-ranked findings

Accessibility task-blockers first, then usability.

### High

**H1. No skip link, and `<main>` is not a focus target (WCAG 2.4.1 Bypass
Blocks).** `layouts/application.html.erb:41` — the header and primary nav repeat
on every page, but there is no "skip to main content" link and `<main>` has no
`id`. Keyboard and screen-reader users must tab through the whole nav on every
page to reach content. This is the one issue that adds friction to *every*
screen.
Cure: add a visually-hidden-until-focused skip link as the first focusable
element, pointing at `<main id="main-content" tabindex="-1">`.

**H2. Selected state is conveyed by colour/class only and not announced —
`aria-current` is set in exactly one place and missing on every sibling.**
This is the classic "got it right once, missed it everywhere" pattern. Pagination
does it correctly: `aria-current="page"` on the current page
(`application/_pagination.html.erb:8`) — the reference instance. Its siblings do
not follow:
- **View toggle** (`profiles/show.html.erb:31`): the active view is shown only by
  `class="active"` → a brand background fill (`application.css:314`). No
  `aria-current`/`aria-pressed`, and the *only* visible cue is colour (WCAG 1.4.1
  Use of Colour, plus 4.1.2 Name/Role/Value). A screen-reader or colour-blind
  user can't tell which view is active.
- **Settings subnav** (`settings/_nav.html.erb`): active item styled with
  weight + colour (`.subnav a.active`), but no `aria-current="page"`.
- **Primary nav** (`layouts/application.html.erb:26`): no current-page indication
  at all, visual or programmatic.

Cure: add `aria-current="page"` to the active subnav and primary-nav links, and
`aria-current="true"` (or make them buttons with `aria-pressed`) to the active
view-toggle control; ensure the active state also has a non-colour cue.

**H3. Forms have no error summary, no focus move, and errors aren't tied to
fields (WCAG 3.3.1 Error Identification; GOV.UK error-summary pattern).**
Every form hand-rolls the same `.errors` block — a `<div>` (or `<ul>`) of
`full_messages` at the top: `collectibles/_form.html.erb:9`,
`settings/labels/index.html.erb:14` & `edit.html.erb:6`,
`settings/custom_sorts/_form.html.erb:4`, `settings/show.html.erb:7`,
`collectibles/_import_fields.html.erb:9`. In none of them are the messages links
to the offending field, `aria-invalid`/`aria-describedby` set on the inputs, or
focus moved to the summary on failed submit. Screen-reader and keyboard users get
a list they must hunt through to find the field. Because it's the *same*
hand-rolled block everywhere, one shared error-summary component fixes all
screens at once.
Cure: build one error-summary partial (list of anchor links to field ids, focused
on render) and associate each message with its input via `aria-describedby` +
`aria-invalid`.

### Medium

**M1. Multiple `<nav>` landmarks are unlabeled (WCAG 1.3.1 / ARIA landmark
practice).** Pagination is labeled (`aria-label="Pagination"` —
`_pagination.html.erb:3`, credit), but its siblings aren't, so a screen-reader
landmark list shows several indistinct "navigation" entries:
- primary nav `layouts/application.html.erb:26` — no label,
- breadcrumb `collectibles/show.html.erb:4` — `<nav class="breadcrumb">`, no label,
- settings subnav `settings/_nav.html.erb:1` — no label.

Cure: `aria-label="Primary"`, `"Breadcrumb"`, `"Settings"` respectively.

**M2. Shared card partial hardcodes `<h3>`, causing a heading-level skip on the
collection page (WCAG 1.3.1).** `collectibles/_collectible.html.erb:6` always
renders the title as `<h3>`. On the homepage it sits under an `<h2>` section
heading — correct. On `profiles/show.html.erb` the page goes `<h1>` (collection
name) straight to the cards' `<h3>` with no `<h2>` between — a skipped level.
This is the "a partial that hardcodes a heading level is right in one context and
wrong in another" case; you only see it by checking every page the partial
renders in.
Cure: pass the heading level into the partial as a local, or add the missing
`<h2>` on the collection page.

**M3. Small touch/click targets for inline text-link actions (WCAG 2.2 AA 2.5.8
Target Size).** `.button-as-link` renders destructive and secondary actions as
zero-padding inline text (`application.css:184`, `padding: 0`): "Sign out",
"Remove" (a person's access), "Revoke" (a share link), "Delete" (a custom sort).
At body-text height these are under the 24×24 CSS-px target, and several are
*destructive*, so they're both hard to hit and easy to mis-hit. The inline
`list__actions` links ("Edit"/"Delete") are similarly tight and closely spaced
(Fitts's Law; dxw motor-difficulty guidance).
Cure: give these a minimum target size / padding, or space them per the 2.5.8
spacing exception; keep destructive actions especially generous.

**M4. External-link "tags" don't look clickable, and don't warn they open a new
tab (Krug/Norman affordance; WCAG 3.2.5).** In
`collectibles/_collectible.html.erb:31` and `show.html.erb:52`, the external
look-up links (Goodreads, Steam…) are styled as `.tag--link` pills — visually
almost identical to the *non-clickable* `.tag` trait pills ("Completed",
"Co-op") sitting right next to them. They're not brand-coloured and carry no
underline until hover, so at a glance a user can't tell which pills are links.
They also open in a new tab (`target="_blank"`) with no signifier that they will.
Cure: make the link tags visibly interactive (link colour and/or a persistent
underline or an external-link icon), and append visually-hidden "(opens in new
tab)".

### Low

**L1. Required fields aren't marked, and error prevention is thin (WCAG 3.3.2
Labels or Instructions).** The collectible `title` is required (model-validated)
but its label doesn't say so and the input has no `required`/`aria-required`
(`collectibles/_form.html.erb:21`). Adopting GOV.UK's low-noise convention —
mark the few optional fields "(optional)" rather than starring the many required
ones — would set expectations before submit. The custom-sort name already does
this well ("Name (optional)").

**L2. Flash messages aren't live regions.** `layouts/application.html.erb:42`
renders `notice`/`alert` as plain `<p>`. On a full page load they're read in
document order (so not a hard failure), but marking them `role="status"` (notice)
/ `role="alert"` (alert) would announce them reliably and future-proofs any move
to Turbo/async updates (Nielsen: visibility of system status).

**L3. Decorative star read aloud.** `application_helper.rb:44` builds
`"★ Following"` as tag text; a screen reader announces "black star Following".
Wrap the glyph in an `aria-hidden` span (or drop it from the accessible name).

**L4. No machine-readable time.** `_profile_row.html.erb:15` and
`visibility/show.html.erb` render `time_ago_in_words` as plain text with no
`<time datetime>` element. Minor; helps assistive tech and future i18n.

**L5. `placeholder` newlines don't render.** `collectibles/import.html.erb:44`
sets a textarea placeholder of `"Hades\nCeleste\nHollow Knight"`; browsers
collapse it to one line, so the intended "one per line" hint is lost. Put the
example in the visible hint text instead (there's already a `.hint` idiom).

## Theme view (symptom axis)

1. **State shown but not announced / colour-only** — H2 (view toggle, subnav,
   primary nav), and the pagination reference instance that gets it right. The
   single strongest theme: visibility-of-system-status (Nielsen 1) seen from the
   accessibility side (state must be programmatically determinable).
2. **Landmarks and bypass** — H1 (skip link + `main` target), M1 (unlabeled
   navs). Whole-scope by nature; both about letting AT users navigate structure.
3. **Hand-rolled forms without the safety net** — H3 (error summary/association)
   and L1 (required marking). Every form repeats the same partial pattern, so
   these are one shared-component fix, not six.
4. **Affordance — "is this clickable / where will it go?"** — M4 (link tags vs
   trait tags; new-tab).
5. **Motor / target size** — M3 (inline text-link actions).

## Subject / hotspot grid (subject × criterion)

| Subject | Bypass/landmark | Name/role/value + status | Headings | Forms | Colour/affordance | Target size | Distinct criteria |
|---|---|---|---|---|---|---|---|
| `layouts/application` | H1 (skip), M1 (nav label) | H2 (nav current) | — | — | — | M3 (sign out) | **4 → High** |
| `_collectible` partial | — | — | M2 (hardcoded h3) | — | M4 (link tags) | — | 2 → Medium |
| `profiles/show` (toolbar) | — | H2 (view toggle) | M2 (skip on page) | — | H2 (colour-only) | — | 2 → Medium |
| Shared `.errors` block (6 screens) | — | H3 (not associated) | — | H3 (no summary/focus) | — | — | **2 → High (multiplied across 6)** |
| `settings/_nav` | M1 (label) | H2 (aria-current) | — | — | — | — | 2 → Medium |
| list rows (`list__actions`, `button-as-link`) | — | — | — | — | — | M3 | 1 → Medium |

Reading the grid: the **layout** and the **shared `.errors` block** are the two
systemic subjects — each renders on many screens, so fixing them once clears the
finding everywhere. That's where the leverage is, and it's invisible from a
screen-by-screen read.

## Impact-ordered fix list

Ordered by how many findings/screens each clears, not by cost.

1. **Fix the layout: skip link + `main` target, label the primary nav, and add
   `aria-current` to the active nav item (H1, M1, part of H2).** *Cost: low.*
   One file, clears friction on every screen.
2. **One shared error-summary component (H3, L1).** *Cost: medium.* Replaces the
   six hand-rolled `.errors` blocks with a focused, field-linked summary; every
   form benefits at once.
3. **Announce selected state everywhere (H2 remainder).** *Cost: low.*
   `aria-current` on subnav; `aria-current`/`aria-pressed` + a non-colour cue on
   the view toggle.
4. **Make the card partial's heading level a local, and label the breadcrumb nav
   (M2, M1 remainder).** *Cost: low.*
5. **Target size + affordance for tags/actions (M3, M4).** *Cost: low-medium.*
   Padding on `.button-as-link` inline actions; visible link styling + new-tab
   hint on `.tag--link`.
6. **Polish: live-region flashes, aria-hidden star, `<time>`, placeholder hint
   (L2–L5).** *Cost: low each.*

## What already works (credit)

- **Contrast genuinely meets AA — independently verified.** I recomputed the
  ratios for text/muted/brand against bg and surface across all seven themes:
  every body-text pair clears 4.5:1 (lowest is retro brand-on-cream at 4.5) and
  every interactive `--field-border` clears the 3:1 UI-component bar. The
  stylesheet's distinction between decorative `--border` (exempt) and interactive
  `--field-border` (WCAG 1.4.11) is exactly right, and the "AA verified" comment
  held up.
- **Type is done well:** every size is a `rem` token, body ≥16px, line-height
  1.5, relative units throughout so browser zoom/reflow (1.4.10) works; a single
  clean breakpoint.
- **Focus is not sabotaged:** no `outline: none` anywhere, so the browser's
  default focus ring is preserved on every control (the reference's advice when a
  design system has no focus style). A `:focus-visible` style would be a nice
  enhancement, but nothing here *breaks* focus visibility.
- **Landmarks and the visually-hidden pattern are present:** proper
  `<header>`/`<nav>`/`<main>`, a correct `.visually-hidden` utility used to label
  search inputs and the custom-sort composer selects.
- **Pagination is the model to copy:** semantic `<nav aria-label>`, `aria-current`
  on the current page, current page rendered as non-link text.
- **Destructive actions are handled properly:** dedicated confirmation pages
  (`confirm_delete` for collectibles and labels) with plain-language "can't be
  undone" copy, and every mutation is a `button_to` (POST/DELETE), not a GET link
  (Nielsen 5, error prevention). The label delete page even lists what will be
  affected.
- **Progressive disclosure and empty states:** the search syntax lives in a
  `<details>` (Hick's Law — advanced power kept out of the way), and every list
  has a tailored empty state.
- **Content is plain and scannable:** descriptive link text ("Back to my
  collection"), the breadcrumb separator correctly `aria-hidden`, `simple_format`
  for notes, sensible plain-language flash messages.
- **Forms get the basics right:** real `<label>`s (visible or visually-hidden),
  `<fieldset>`/`<legend>` grouping for players/status/multiplayer/labels, and
  `autocomplete="one-time-code"` on the 2FA input.

## Coverage gaps / caveats

- I did not run axe/Lighthouse/a screen reader; findings are from reading markup,
  the accessibility tree implied by it, and computed contrast. Automated tools
  catch ~a third of issues, so a manual keyboard + screen-reader pass on the top
  fixes is still worth doing before shipping.
- I verified the seven themes' primary text/UI pairs, not every one of the nine
  label-colour swatches per theme; the pattern (theme-set text/border over an
  inline background) is sound but each swatch wasn't individually recomputed.
- Devise's own auth views were out of scope, so their labels/errors aren't
  assessed here.
