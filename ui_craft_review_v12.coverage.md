# ui_craft_review_v12 — coverage sidecar

Scaffolding for the exhaustive inline ui-craft pass. Not a deliverable. Commit
`0a2078c`.

## Scope roster (seeded from a pasted listing)

`find app/views app/helpers config/locales -type f` + `application.css` + the PWA
manifest + user-facing strings assembled in controllers. 40 view templates/
partials, 3 helpers, 2 locale files, 1 stylesheet, 1 manifest. Devise's own
sign-in/up/password views are **not in the repo** (gem defaults) → coverage gap.

## Per-dimension sweeps (whole-scope, pasted commands)

| Dimension | Command | Result → finding |
|---|---|---|
| Focus visibility | `grep -n 'outline\|:focus' application.css` | **0** focus rules; no `outline:none` either → UA default only → UI-01 |
| Page `<title>` | per-view check of `content_for :title` | all set except two 2FA views → UI-07 |
| Headings / levels | `grep -rn '<h[1-6]' app/views` | one h1/page; card `<h3>` skips h2 on profile grid → UI-08 |
| Landmarks / roles | `grep -rn '<nav\|<main\|<header\|role=' app/views` | one main, nav landmarks present; view-toggle `role=group` |
| State cues | `grep -rn 'active\|aria-current\|selected' app/views` | pagination has aria-current; subnav + view-toggle do not → UI-04, UI-05 |
| Status messages | flash partial in layout + `grep -rn 'notice:\|alert:' app/controllers` | ~25 flashes, no `role=status`/`aria-live` → UI-03 |
| Non-text content | `grep -rn 'image_tag\|<svg\|alt=\|@qrcode' app app/views` | QR SVG, no text alt/manual key → UI-02 |
| Form labels | per-form check of `label`/`label_tag`/`visually-hidden` | every control labelled (credit) |
| Grouped inputs | `grep -rn 'fieldset\|legend' app/views` | groups use fieldset/legend except import label group → UI-09 |
| Error handling | `grep -rn 'errors\|full_messages\|aria-invalid' app/views` | summaries present; no focus/field link/aria-invalid → UI-06 |
| Colour-only cues | read `application.css` state rules | active states colour(+weight) only for AT → UI-04/05 |
| Reduced motion | `grep -in 'prefers-reduced-motion\|transition' application.css` | none → UI-12 |
| Input affordance | `grep -rn 'inputmode\|autocomplete' app/views` | OTP has autocomplete, no inputmode → UI-10 |

## Heading census (level per non-partial view)

Every non-partial view has exactly one `<h1>`. h2/h3 nesting logical on
settings/visibility/sorting/labels. Exception: `_collectible.html.erb` emits a
hardcoded `<h3>`; under `profiles/show` (h1 then grid) that skips h2 → UI-08;
under `root/index` (h2 "From your collection" precedes) it is correct.

## State-cue census (active/current → announced equivalent?)

| Cue | Non-colour marker | Announced (aria)? |
|---|---|---|
| pagination current (`_pagination.html.erb:8`) | border + weight | yes (`aria-current="page"`) — credit |
| subnav active (`_nav.html.erb`) | font-weight (colour==muted on mono themes) | **no** → UI-04 |
| view-toggle active (`profiles/show`) | brand fill (colour only) | **no** → UI-05 |
| label tag colour | label **name text** always present | n/a (not colour-only) — credit |
| import error item (`.import-item--error`) | red border **plus** error text block | n/a — text present |

## Form-control label census

Every input across `_form`, `import`, `_import_fields`, `visibility/show`,
`custom_sorts/_form`, `settings/show`, `sorting/show`, `labels/*`, `_type_checkboxes`
carries an associated `label`/`label_tag` (visually-hidden where the design hides
it) — no unlabelled control found. Grouped checkbox/radio sets use
`<fieldset><legend>` except the import-review label group (span, UI-09).

## High-stakes flow census (UI criteria: every screen incl. non-template content)

| Flow | Swept | Verdict |
|---|---|---|
| Sign in / 2FA verify | title, label, autocomplete, error announce | title missing (UI-07), no live-region errors (UI-03), OTP inputmode (UI-10) |
| Enable 2FA (setup) | QR alt, manual key, title | no text alt / no manual key (UI-02, High), title missing (UI-07) |
| Delete collectible / label | confirm page, cancel, danger styling | interstitial confirm + "can't be undone" (credit) |
| Revoke share link / remove access | inline button_to | no confirm page (acceptable — reversible, lower stakes) |
| Devise sign-up / password reset | — | **not in repo (gem defaults) → unreviewed, gap** |

## Contrast note

Stylesheet asserts "all pairs WCAG-AA verified" (CSS lines 34, 430). Spot-checked
`--muted #585f6d` on `--bg #f6f7fb` (~5.5:1) and `--on-brand #fff` on `--brand`
(light) — pass. Did **not** recompute all 7 themes × pairs; recorded as an
unfalsified blanket claim → caveat, not a passed credit.

## Coverage matrix

All 40 views + 3 helpers + layout + manifest + stylesheet given a row and marked
swept across: semantics/landmarks, headings, labels, state cues, error handling,
content, colour/contrast, focus. No blank rows. Live AT/keyboard behaviour and
render-time target-size inferred from markup+CSS, not run in a browser (caveat).

## Self-grill notes

- Focus finding falsified against the CSS: no `:focus` rule *and* no `outline:none`
  → UA default ring survives, so severity is Medium (weak/low-contrast on themed
  filled controls), not "focus invisible". Reconciled down from the critic's High.
- Heading credit falsified by opening both render contexts of the shared card
  partial → UI-08 is a real Low, not a clean credit.
- 2FA flow crosses 3 distinct dimensions (non-text content, page title, input
  affordance) → convergence floor; anchored at UI-02 High.
