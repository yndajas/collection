# UI-craft v10 — coverage sidecar

Scaffolding for `ui_craft_review_v10.md`. Synthesised from two independent passes'
sidecars plus an adjudication read of the layout, stylesheet, and every view.

## Whole-scope dimension sweeps (searches / enumerations run)

- **`aria-current` / status parity (UC3):** grep `aria-current` → only
  `_pagination.html.erb:8`. Enumerated every current/active cue: site-nav (no
  cue), `settings/_nav` `.active` (class only), view-toggle `.active` (class
  only). None but pagination announced.
- **Landmark naming (UC4):** grep `<nav` → `site-nav` (unlabelled), `subnav`
  (unlabelled), breadcrumb (unlabelled), pagination (`aria-label="Pagination"`).
  Skip link / `<main id>` (UC1): grep `skip`/`id="main` → none; `<main>` has
  `class` only (`application.html.erb:41`).
- **Heading order across shared partials (UC5):** `_collectible` emits `<h3>`.
  Renders under homepage `<h2>` sections (ok) and directly under `profiles/show`
  `<h1>` with no `<h2>` (skip). `show.html.erb` uses `<h1>`→`<h2>` (ok).
  Every screen's h1 checked: all present and singular.
- **Focus + contrast across themes (UC2, UC6):** grep `focus|outline|:focus` →
  only a comment (`:53`); **no `outline:none` reset** → UA default ring survives
  (adjudication: not "invisible focus"). grep per-theme `--brand` vs `--text`:
  equal in `monochrome_light` (`#1a1a1a`) and `monochrome_dark` (`#ededed`) →
  in-text links colour-only disappear (UC6). Contrast spot-checked on label
  colours (e.g. `--label-yellow #7d6a00` on `--label-text #fff` ≈ 4.9:1 ✓);
  blanket "AA verified" comment (`:430`) not exhaustively recomputed.
- **Content outside the template (UC12, UC7):** flash strings live in
  controllers; OTP field label "OTP" (jargon) in the 2FA views; error copy in
  `_form`/settings forms. Live-region: grep `role="status"|role="alert"` → none.
- **Reduced motion / animation:** grep `transition|animation|@keyframes` → none,
  so a missing `prefers-reduced-motion` block is moot (recorded as non-finding).

## Per-screen coverage matrix

Legend: ✓ ok, F finding, — n/a. Columns: Title = distinct `<title>`; H = heading
order; Nav = persistent nav present/labelled; Focus/colour = inherits UC2/UC6;
Forms = labels + error assoc.

| Screen / partial | Title | H order | Nav | Focus/colour | Forms |
|---|---|---|---|---|---|
| layout `application.html.erb` | ✓ | — | F(UC4) + F(UC1) + F(UC7) | F(UC2) | — |
| `root/index` (+`_collection_list`,`_profile_row`) | ✓ | ✓ | ✓ | inherit | — |
| `profiles/show` (+`_collectible`,`_search_form`) | ✓ | F(UC5) | ✓ | F(UC3 toggle) | labels ✓ |
| `profiles/private_profile` | ✓ | ✓ | ✓ | inherit | — |
| `collectibles/show` | ✓ | ✓ | F(UC4 breadcrumb) | F(UC6 breadcrumb) | — |
| `collectibles/new`/`edit` (+`_form`) | ✓ | ✓ | ✓ | inherit | F(UC8) |
| `collectibles/confirm_delete` | ✓ | ✓ | ✓ | inherit | ✓ |
| `collectibles/import`/`review` (+`_import_fields`,`_import_help`) | ✓ | ✓ | ✓ | inherit | F(UC8) |
| `collections/index` (+`_search_form`,`_search_help`) | ✓ | ✓ | ✓ | inherit | F(UC11) |
| `settings/show` | ✓ | ✓ | F(UC4 subnav) | F(UC3 subnav) | F(UC8) |
| `settings/visibility/show` | ✓ | ✓ | ✓ | inherit | F(UC9 ×2 one-click delete) |
| `settings/sorting/show` (+custom_sorts `_form`/new/edit) | ✓ | ✓ | ✓ | inherit | F(UC9 delete) |
| `settings/labels/index`/`edit`/`confirm_delete` (+`_type_checkboxes`) | ✓ | ✓ | ✓ | inherit | F(UC8) |
| `two_factor_authentication/setup/show`,`sessions/show` | F(no `content_for :title`) | ✓ | ✓ | inherit | F(UC12) |
| `pwa/manifest`, `pwa/service-worker` | — | — | — | — | — |

Notes: the 2FA views set no page `<title>` (fall back to "Collection") and sit
outside the styled layout conventions — folded into UC12. Every other screen has a
distinct title, a single `<h1>`, and the persistent header nav; the recurring
misses are the shared-layout ones (UC1–UC4, UC7) and the per-form error pattern
(UC8), which is why the layout and stylesheet are the convergent High subjects.

## Two walks

- **Sighted mouse, first-time:** search DSL discoverability (UC10), destructive
  one-click deletes (UC9), monochrome in-text links (UC6).
- **Keyboard + screen reader:** no skip link (UC1), untuned focus (UC2), current
  item not announced (UC3), unlabelled nav landmarks (UC4), heading skip (UC5),
  flash not announced on re-render (UC7), unassociated form errors (UC8).
