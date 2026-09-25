# UI-craft review

A review through the ui-craft lens (Krug and Nielsen on usability, Norman on
affordances, WCAG 2.2 AA and GOV.UK/dxw practice on accessibility). The visual
system is thoughtful: a single tokenised type scale, every colour a themed
variable with AA pairings called out, `--field-border` chosen for the 3:1
non-text-contrast rule (WCAG 1.4.11), a real confirm-delete page rather than a JS
`confirm`, and semantic `<article>`/`<ul>`/`<main>` markup. Findings are ranked
by impact, accessibility blockers first.

## 1. No visible focus indicator styling (WCAG 2.4.7 Focus Visible)

**Where:** `app/assets/stylesheets/application.css` — there is no `:focus` or
`:focus-visible` rule anywhere, yet many interactive elements are custom-styled:
`.button` (links dressed as buttons), `.view-toggle a`, `.tag--link`,
`.button-as-link`, and `<select>` with `appearance: none`.

**Why it matters:** Keyboard and switch users rely on a visible focus ring to
know where they are (Nielsen: visibility of system status; WCAG 2.4.7, and 2.4.13
Focus Appearance in 2.2). Relying on the browser default is fragile here: the
default outline is often low-contrast against custom fills — notably the active
view-toggle tab (`--brand` background, `application.css:314`) and the brand
`.button`. `appearance: none` on selects can also suppress the native ring in
some engines.

**Fix:** Add an explicit, high-contrast `:focus-visible` style (e.g.
`outline: 2px solid var(--text); outline-offset: 2px;`) applied to links,
buttons, `.button`, `.view-toggle a`, and form controls. One rule set, themed via
the existing variables.

## 2. Flash messages aren't announced to assistive tech (WCAG 4.1.3)

**Where:** `app/views/layouts/application.html.erb:42–43` — flashes render as
plain `<p class="flash">`.

**Why it matters:** After an action ("Label created.", "Removed from your
collection.") a screen-reader user gets no notification, because the message
appears with no `role`/`aria-live`. This is a Status Messages failure (WCAG
4.1.3) and a Nielsen visibility-of-system-status gap.

**Fix:** Give the notice `role="status"` (polite) and the alert `role="alert"`
(assertive). No visual change; the region is then announced on navigation.

## 3. Heading levels skip from `h1` to `h3` on collection views (WCAG 1.3.1)

**Where:** `app/views/collectibles/_collectible.html.erb:6` uses
`<h3 class="card__title">`, rendered directly under the page `<h1>` on
`profiles/show.html.erb` and `root/index.html.erb` with no intervening `h2`.

**Why it matters:** Screen-reader users navigate by heading level; a jump from
h1 straight to h3 signals a missing section and makes the outline confusing
(WCAG 1.3.1 Info and Relationships; GOV.UK heading guidance). On the collectible
*show* page the hierarchy is correct (h1 → h2 "Notes"/"Look it up"), so this is
specifically the card grids.

**Fix:** Make card titles `<h2>` (they are the top-level items beneath the page
heading), or introduce a real `<h2>` section heading above the grid and keep the
cards at `h3`. Adjust `.card__title` sizing via the existing tokens if needed —
level and visual size are independent.

## 4. Multiple unlabelled `nav` landmarks and no skip link (WCAG 2.4.1)

**Where:** `layouts/application.html.erb:26` (`<nav class="site-nav">`, no label)
and `collectibles/show.html.erb:4` (`<nav class="breadcrumb">`, no label). The
pagination nav is correctly labelled (`_pagination.html.erb:3`). There is no
skip link to `<main>`.

**Why it matters:** Two unnamed `navigation` landmarks are ambiguous when a
screen-reader user lists landmarks (WCAG 1.3.1 / ARIA practice), and with no
"skip to content" link keyboard users tab through the header on every page (WCAG
2.4.1 Bypass Blocks).

**Fix:** Add `aria-label` to each nav (e.g. "Primary" and "Breadcrumb"), and add
a visually-hidden skip link as the first focusable element targeting
`<main id="main">`. The `.visually-hidden` utility already exists
(`application.css:78`); pair it with a `:focus` reveal.

## 5. The search DSL is the primary way to filter, and asks users to learn syntax

**Where:** `collectibles/_search_form.html.erb:9` (placeholder
`is:completed system:switch zelda`) and `collections/_search_form.html.erb`; the
full grammar lives in the `search-help` `<details>`
(`collectibles/_search_help.html.erb`).

**Why it matters:** Krug's "Don't Make Me Think": the main filtering affordance
is a query language a casual user has to study. The collapsible help panel is a
good mitigation (and genuinely well written), but everyday filters — type,
completed, has-labels — require recalling `type:`, `is:completed`, `label:`
syntax rather than clicking. It's a power-user-first default.

**Fix (progressive):** Keep the DSL for power users, but add a few
one-click/faceted controls for the highest-traffic filters (type, completed) that
simply compose the same query string behind the scenes. Even a row of toggle
links that append `is:completed` etc. would remove most of the "what do I type?"
friction without new backend work.

## 6. Search syntax is conveyed only by placeholder text (WCAG 1.4.3 / forms)

**Where:** `collectibles/_search_form.html.erb:8–11` — the visible label is
`visually-hidden` and the example syntax lives in the `placeholder`.

**Why it matters:** Placeholder text disappears on input, commonly fails contrast
(WCAG 1.4.3), and shouldn't carry instructions (a well-established forms
anti-pattern; GOV.UK avoids placeholders). Here the only always-visible guidance
is the collapsed help panel.

**Fix:** Show a visible label or a short persistent hint under the field (e.g.
"Search titles, or use filters like `type:book`"), and keep the placeholder as a
light example only. Associate any hint with the input via `aria-describedby`.

## 7. External links open in a new tab with no warning (WCAG 3.2.5)

**Where:** `collectibles/_collectible.html.erb:32` and
`collectibles/show.html.erb:53` — the "Look it up" links use `target="_blank"`
(with `rel="noopener"`, which is correct).

**Why it matters:** An unexpected new window/tab disorients users, especially
screen-reader and cognitively-impaired users (WCAG 3.2.5 Change on Request;
Nielsen: user control and freedom).

**Fix:** Signal it — append a visually-hidden "(opens in new tab)" to the
accessible name, or a small icon with equivalent text. One change in the shared
partial covers both places.

## 8. Error summary isn't linked to the fields it describes (GOV.UK error summary)

**Where:** `collectibles/_form.html.erb:9–18` lists `full_messages` in a
`.errors` block; individual fields have no inline error or `aria-describedby`.
Import errors are similar (`_import_fields.html.erb:9–11`).

**Why it matters:** WCAG 3.3.1 (errors identified in text) is met, but the
GOV.UK error-summary pattern — a summary whose entries link to each offending
field, plus an inline message per field — is the accessible best practice and
markedly faster for everyone (Nielsen: help users recognise and recover from
errors). With long forms the current block makes the user hunt for the field.

**Fix:** Turn the summary into a list of in-page anchor links to each field, and
render the field-level message next to its input with `aria-describedby`
wiring.

## 9. Contrast is asserted but not verified

**Where:** `application.css:34` and the theme blocks claim "all pairs WCAG-AA
verified." The palettes are clearly designed with care (the monochrome themes
collapse `--muted` to full ink; `--field-border` targets 3:1).

**Why it matters:** The claim is only as good as the last manual check, and there
are many themed pairs (seven themes × muted/brand/label combinations). Pastel
themes with coloured brand links on tinted surfaces (e.g. `pastel_parlour`
`--brand: #1a5f40` on `--surface: #fce7f0`, `application.css:591`) are the ones
most worth confirming.

**Fix:** Add an automated contrast check (a small script or CI step over the
token pairs) so the "AA verified" comment stays true as themes evolve. Not a
current failure I can see — a guardrail against future drift.

## 10. Minor polish

- **Curly-vs-straight quotes are inconsistent** in empty/no-match copy:
  `collections/index.html.erb:16` uses `“ ”` while
  `profiles/show.html.erb:75` uses straight `" "`. Pick one for a consistent
  voice (curly reads better in rendered HTML).
- **`autofocus` on the title field** (`_form.html.erb:22`) can drop
  screen-reader users past page context on load; consider removing it or
  confirming it's wanted.
- **Pagination links** are bare numbers (`_pagination.html.erb:10`); acceptable
  inside the labelled nav, but an `aria-label="Go to page N"` would remove any
  ambiguity.

---

**Working well (don't regress these):** the tokenised type scale and
theme-variable discipline, the 3:1 `--field-border` choice, the real
confirm-delete page, semantic landmarks and list/article markup, the
`aria-hidden` breadcrumb separator, and the genuinely clear search-help content.
