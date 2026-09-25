# ui-craft v9 - coverage sidecar (scaffolding, not the report)

Exhaustive inline review. Scope: every view, partial, layout, and the single
stylesheet, plus content/accessible-names assembled in controllers, helpers,
and models. Tests excluded per request.

## Per-screen matrix (row per rendered screen)

Cols: TTL=distinct <title>, HN=heading order sane (one h1, no skip), NAV=persistent
nav present, LM=landmark naming, FRM=form a11y (labels/errors), AC=announced
state (aria-current where visual state shown). `.`=ok, `F`=finding, `-`=n/a.

| Screen | TTL | HN | NAV | LM | FRM | AC |
|---|---|---|---|---|---|---|
| layouts/application (shell) | . | - | . | F (site-nav unlabelled; no skip link) | - | - |
| root/index (home) | . | . | . | . | - | - |
| collections/index | . | . | . | . | . (search only) | - |
| profiles/show (collection) | . | . | . | . | . | F (view-toggle active not announced) |
| profiles/private_profile | . | . | . | . | - | - |
| collectibles/show | . | . | . | F (breadcrumb nav unlabelled) | - | - |
| collectibles/new | . | . | . | . | F (no summary/assoc/focus; required unmarked) | - |
| collectibles/edit | . | . | . | . | F (same) | - |
| collectibles/confirm_delete | . | . | . | . | . (destructive - credit) | - |
| collectibles/import | . | . | . | . | F (labels/fieldsets ok; no summary) | - |
| collectibles/review (import) | . | . | . | . | F (per-item errors not linked/focused) | - |
| settings/show | . | . | . | F (subnav unlabelled) | F (errors to_sentence, no field assoc) | F (subnav active not announced) |
| settings/sorting/show | . | . | . | F (subnav) | F | F (subnav) |
| settings/visibility/show | . | . | . | F (subnav) | F | F (subnav) |
| settings/labels/index | . | . | . | F (subnav) | F | F (subnav) |
| settings/labels/edit | . | . | . | . | F | - |
| settings/labels/confirm_delete | . | . | . | . | . (destructive - credit) | - |
| settings/custom_sorts/new | . | . | . | . | F (table of selects; hidden labels - credit) | - |
| settings/custom_sorts/edit | . | . | . | . | F | - |
| two_factor_authentication/setup/show | F (no title -> "Collection") | . | . | . | F (QR has no text alt / manual key) | - |
| two_factor_authentication/sessions/show | F (no title -> "Collection") | . | . | . | F (bare divs, weak label) | - |
| application/_pagination | - | - | - | . (aria-label + aria-current - CREDIT) | - | . (CREDIT) |

## Per-dimension sweep commands (pasted)

- Focus styles: `grep -n ":focus\|focus-visible\|outline\|:active" application.css`
  -> NONE. No custom focus style; and no `outline:none` either, so the UA
  default ring is preserved (functional, but unstyled/unverified across the 7
  themes). Finding UI-4.
- Landmarks / labelling: `grep -rn "<nav\|aria-label\|<main\|<header\|skip" app/views/`
  -> navs: site-nav (no label), settings subnav (no label), breadcrumb (no
  label), pagination (aria-label="Pagination" - credit), view-toggle
  (role=group aria-label="View" - credit). One <main>, no `id`, no skip link.
- aria-current parity: `grep -rn "active\|aria-current\|current_page" app/views/ application.css`
  -> pagination `aria-current="page"` (credit); subnav `.active` (class only);
  view-toggle `.active` (class only). Findings UI-1.
- Page titles: loop `grep -q "content_for :title"` over non-partial views
  -> only the two 2FA screens lack one. Finding UI-6.
- Images/alt: `grep -rn "image_tag\|<img\|alt=\|qrcode\|<svg" app/views/`
  -> only image is the 2FA QR (`@qrcode` inline SVG). No text alternative /
  manual secret key. Finding UI-6.
- Form error a11y: `grep -rn "aria-invalid\|aria-describedby\|error_summary\|autofocus\|required" app/views/`
  -> none except one `autofocus` on the collectible title. No error summary,
  no field-level association, no focus move. Finding UI-5.
- Required/optional marking: `grep -rn "(optional)\|inputmode\|autocomplete" app/views/`
  -> "(optional)" on 2 fields; no required marking; otp fields have
  autocomplete=one-time-code (credit) but no inputmode=numeric.

## Contrast falsification (computed, not trusted from the "AA verified" comment)

WCAG AA thresholds: body text 4.5:1, large 3:1, UI component boundary 3:1.
Computed ratios (relative luminance) for the tightest pairs across all 7 themes:

- muted text on bg/surface: 5.5-17.4 across themes (min 5.52, woodland). PASS.
- brand link on bg: min 4.54 (retro). PASS (>=4.5 even as body-size link).
- .card__type eyebrow (brand, ~12px bold => 4.5:1): min 5.0 (retro). PASS.
- tag text on tag-bg: min 6.65. PASS.
- All 9 label backgrounds vs the theme's --label-text, all 5 colour themes
  (mono themes are literal ink/paper): every pair >= 4.5:1. PASS (no failures).
- Form-control borders (--field-border) vs their field/surface bg, per theme:
  3.45-5.1. PASS (>=3:1, WCAG 1.4.11).
- Only sub-3:1 pairs: `.tag--link` border and `.card` border (both ~1.26:1 in
  light). `.card` is decorative (1.4.11 n/a). `.tag--link` is interactive but
  carries visible link text, so identifiable without the border -> Low, not a
  fail. Finding UI-visual (Low).

Conclusion: the "all pairs WCAG-AA verified" comment is SUBSTANTIATED for text
and control boundaries across every theme. Strong credit.

## Two walkthroughs

- First-time sighted mouse user: nav conventions solid (brand=home, persistent
  nav, search+sort toolbar, breadcrumb on leaf, confirm pages before destroy).
  Clickable things look clickable. Main friction: no marked-required fields;
  view-toggle/subnav active states are subtle (weight/colour).
- Assistive-tech user: gaps concentrate in (a) no skip link + unlabelled
  repeated landmarks, (b) state shown-not-announced (subnav, view toggle),
  (c) form errors not summarised/associated/focused, (d) 2FA QR with no text
  fallback and 2FA pages with no distinct title. All caught above.

## Credits falsified (ledger)

- "pagination is accessible" - TRUE: aria-label on the nav + aria-current on the
  current page. Credit. But its siblings (subnav, view-toggle) do NOT match ->
  parity finding UI-1 (the credit is exactly what exposes the gap).
- "all colour pairs AA" - TRUE, computed above across all themes. Credit.
- "labels present on all inputs" - TRUE: visible labels or visually-hidden
  labels (search inputs, sort/direction selects, share-link fields). Credit.
- "focus never removed" - TRUE: no `outline:none` anywhere, UA ring preserved.
  Credit, but no positive/consistent focus style exists (UI-4).
- "destructive actions are confirmed" - TRUE: collectible + label delete both
  route through a confirm_delete page with an explicit button_to. Credit.

## Self-grill (evidence)

- Sidecar exists with per-screen matrix + per-dimension commands + contrast
  computation: yes.
- Every leaf/error/empty screen has a row: yes (private_profile,
  confirm_delete x2, 2FA x2, review, empty states noted in-report).
- aria-current parity swept across ALL current/active cues: yes (3 cues found;
  1 announces, 2 don't).
- Contrast computed for the tightest pairs incl. focus consideration: yes.
- Content-outside-template swept: flash/notice/alert wording (controllers),
  validation messages (models), export/import status - read through the content
  lens; wording is plain and identifies the object. No jargon findings.
- Surfaced in self-review: the two 2FA screens (easy to skip as "Devise-ish"
  plumbing) are the only title miss and the only unlabelled image.
