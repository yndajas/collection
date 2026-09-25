# UI-craft review v13 — coverage sidecar

Scaffolding for `ui_craft_review_v13.md`. Commit `0a2078c`, branch `prototype`.
Two independent parallel passes (A, B), reconciled and verified against source by
the synthesiser.

## 1. Catalogue-load ledger

| Catalogue | Read (evidence) | Single-subject checks it contributed |
|---|---|---|
| accessible-code.md | Both passes cite it; applied for landmarks, skip link, focus, name/role/value, live regions | UI-03, UI-04, UI-05, UI-08, UI-09 |
| usability.md | Nielsen heuristics + Krug applied per screen | UI-10, UI-13, UI-15, UI-18, UI-20 |
| forms.md | Error-summary pattern, required marking, input types, fieldset/legend | UI-02, UI-12, UI-14; fieldset/legend credit |
| content.md | Plain language, link text, alt text | UI-11, UI-12, UI-16, UI-17 |
| visual-design.md | Contrast (computed), colour-only state, focus visibility | UI-04, UI-10, UI-17; contrast credit |

## 2. Credits ledger (falsification per credit)

| Credit | Falsifying question | Result |
|---|---|---|
| Contrast AA across themes | Which of the N theme pairs falls below 4.5:1 (text) / 3:1 (UI)? | Computed all principal pairs, all themes — none below. Stands. (`--border` at 1.26:1 is decorative, 1.4.11 n/a.) |
| Form labels real, not placeholders | Which field is placeholder-labelled? | Search boxes use `label_tag … visually-hidden`; placeholders only for examples. Stands. |
| fieldset/legend on all groups | Which radio/checkbox group lacks a legend? | All cited groups wrapped. Stands. |
| Destructive actions guarded | Is any delete a bare one-click with no confirm? | Both routes via GET `confirm_delete`. Stands. |
| Pagination accessible | Is `aria-current` present and is state colour-only? | `aria-current="page"` + weight/border. Stands. |
| Per-page `<title>` everywhere | Which page has no distinct title? | The two 2FA pages set none → folded into UI-14. Mostly stands. |
| `rel="noopener"` on external links | Missing anywhere? | Present. Stands — but the new-tab *warning* is missing → UI-11. |

## 3. Instance censuses (per whole-scope dimension)

**Heading-hierarchy census** — every page/partial that emits a heading:
- layout: no page heading (correct). root/index: h1 (hero) → h2 sections → cards h3
  (correct, h2→h3). profiles/show: h1 → cards h3 (**skip → UI-06**). collectibles/show:
  h1 → h2 (ok). settings/*: h1 "Settings" (generic, one per page — **UI-07**) → h2.
  collections/index: h1 → rows (ok). Shared partial `_collectible` emits a fixed `h3`
  → right under an h2 host, wrong under an h1 host → UI-06.

**Landmark / skip-link / title census** — `grep -rn "skip\|<main\|role=" app/views`:
`<main class="site-main">` present, no `id`, no skip link → UI-03. One `<main>`, native
`<header>`/`<nav>`, `<html lang>` present. Per-page `<title>` via `content_for` on all
but the 2FA pages.

**Form-accessibility census** — every form: collectible `_form`, `_import_fields`,
search forms, settings show/visibility/sorting, labels index/edit, custom_sorts `_form`,
2FA setup/session, Devise (defaults). Programmatic labels: present. Required marking:
title has no `required` indication (minor; not raised separately — the error-summary gap
UI-02 dominates). Error association: none have summary/focus/`aria-invalid` → **UI-02**
across all app-owned forms; Devise unknown → **UI-14**.

**Colour-only / unannounced-state census** — enumerate every state cue: view-toggle
`.active` (class + brand fill — needs a non-colour cue check; low, folded into UI-04
focus habit), follow "Following" vs "Follow" (ghost vs solid fill + state-named →
**UI-08**), link chips vs static chips (**UI-10**), pagination current (weight+border,
OK — credit), flash notice/alert (colour banner + not announced → **UI-05**).

**Name/role/value census** — interactive controls: follow toggle (**UI-08**), repeated
Edit/Delete/Revoke/Remove list controls (**UI-09**), external link chips (**UI-11**),
QR SVG (**UI-01**), sort-composer selects (labelled — credit), search boxes (labelled —
credit).

**Alt / non-text census** — images: no `<img>` content images (icons are favicons/link
rels); the only generated graphic is the QR SVG (**UI-01**); the "★" text glyph
(**UI-17**); breadcrumb "/" correctly `aria-hidden` (credit).

**Links-in-prose census** — external "look it up" links styled as chips, no underline,
new tab (**UI-10**, **UI-11**); nav links `text-decoration:none` (covered by the
focus/affordance habit).

## 4. Coverage matrix (in-scope screens)

Every template read in full at `0a2078c`: layout/application; root/index +
_collection_list; all 12 collectibles views/partials (_collectible, _form,
_import_fields, _import_help, _search_form, _search_help, confirm_delete, edit, import,
new, review, show); collections/index + _search_form + _search_help; all 4 profiles
views (show, private_profile, _profile_row, _follow_button); application/_pagination;
all settings views (show, _nav, visibility, sorting, labels index/edit/confirm_delete/
_type_checkboxes, custom_sorts _form/new/edit); both 2FA views; pwa/manifest.json.erb +
service-worker.js; application.css (all themes); the three helpers; flash/error strings
in every controller. Leaf/error/empty-state screens covered: private_profile, empty
collection states (profiles/show :72-82), import "nothing to import", labels
confirm_delete, homepage empty shelves (UI-18). Config/manifest: manifest (UI-16),
service-worker (no UI surface).

High-stakes-flow census (every screen swept against the full criteria):

| Flow | Screens | Result |
|---|---|---|
| Sign in (entry) | header links → Devise default | UI-14 (unaudited default) |
| 2FA setup | setup/show + generated QR | UI-01 (no key/label), UI-12 (label), UI-14 (structure) |
| 2FA challenge | sessions/show | UI-12, UI-14; UI-05 (invalid-OTP flash not announced) |
| Delete collectible | confirm_delete | Guarded (credit); Delete/Cancel real controls |
| Delete label | labels/confirm_delete | Guarded (credit) |
| Import | import → review → create | UI-13 (conflicting inputs), UI-02 (per-item errors), UI-05 (flash.now) |
| Visibility/sharing | visibility/show | UI-09 (Remove/Revoke names), UI-02 (grant errors) |

## 5. Self-grill (what it caught)

- Pass-diff: pass A alone found the h1→h3 heading skip (UI-06), settings generic-h1
  (UI-07), chip affordance (UI-10), new-tab warning (UI-11), the "★" glyph (UI-17),
  empty homepage shelves (UI-18), and the dual-submit confusion (UI-20). Pass B alone
  found the repeated-control-names-per-row framing (UI-09) and the search "no plain
  controls" framing (UI-15). The union is materially larger than either pass — the
  evidence for running two.
- UI-06 was verified against source in both host contexts (root/index h2 vs
  profiles/show h1) before accepting it, because only one pass raised it.
- Focus-visible severity: adjudicated to Medium with evidence (no `outline: none` in the
  CSS, so the UA default is present and 2.4.7 not outright failed) rather than accepting
  pass A's High — the fact was checked, not asserted.
- Convergence gate: 2FA setup/session crosses 3 dimensions and is held at High (UI-01);
  `_collectible.html.erb` and the layout also reach 3 and were kept at Medium only with
  the stated evidence (independent small-fix single-criterion issues), not a cohesion
  impression.

## 6. Not verifiable from source (needs a running app)

Live axe/Lighthouse; screen-reader lived experience; reflow at 400%/320px and
text-spacing (1.4.10/1.4.12); target size (2.5.8); the exact SVG attributes
`RQRCode.as_svg` emits (UI-01); the rendered Devise default markup (UI-14). These bound
the confidence on UI-01, UI-02, UI-05, and UI-14 and are stated in the report.
