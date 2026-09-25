# ui_craft_review_v11 — coverage sidecar

Scaffolding for the exhaustive ui-craft pass. Not a deliverable.

- **Commit:** 0a2078c
- **Execution:** inline, 2 independent passes (my own + one fresh critic agent),
  reconciled against the code and computed contrast.
- **Scope:** all views/partials/layouts under `app/views/`, `application.css`,
  PWA manifest + service worker, helpers, controller flash strings, `en.yml`.

## Per-screen basics matrix (row per view)

Title = distinct `content_for :title`; H-order = no skipped heading level; Nav =
persistent header nav present (all inherit the layout, so ✓ unless standalone).

| View | Title | H-order | Landmarks | Note |
|---|---|---|---|---|
| layouts/application | n/a | n/a | header/main present; **no skip link, nav unlabelled** | UI-02/03/05/06 |
| root/index | ✓ Collection | h1→h2 ✓ | ✓ | — |
| root/_collection_list | (partial) | — | — | — |
| collections/index | ✓ | h1 ✓ | ✓ | — |
| profiles/show | ✓ | **h1→h3 in cards** | ✓ | UI-07 (card partial) |
| profiles/private_profile | ✓ | h1 ✓ | ✓ | — |
| profiles/_profile_row | (partial) | — | — | — |
| collectibles/show | ✓ | h1→h2 ✓ | breadcrumb nav unlabelled | UI-05 |
| collectibles/_collectible | (partial) | **emits h3** | — | UI-07 |
| collectibles/new, edit | ✓ | h1 ✓ | ✓ | — |
| collectibles/confirm_delete | ✓ | h1 ✓ | ✓ | confirm pattern ✓ (credit) |
| collectibles/import | ✓ | h1 ✓ | ✓ | — |
| collectibles/review, _import_fields | ✓ | h1 ✓ | ✓ | error assoc UI-08 |
| settings/show | ✓ | h1→h2 ✓ | subnav unlabelled | UI-05, UI-13 |
| settings/sorting/show | ✓ | h1,h2,h3 | h3 "Custom sorts" sibling-level | UI-15 |
| settings/visibility/show | ✓ | h1,h2,**h3 sibling sections** | forms | UI-15, UI-11 |
| settings/labels/index | ✓ | h1,h2,h3 | — | UI-08 |
| settings/labels/edit, confirm_delete | ✓ | h1 ✓ | — | confirm pattern ✓ |
| settings/custom_sorts/new, edit, _form | ✓ | h1 ✓ | — | labels ✓ |
| tfa/setup/show | **✗ (falls back "Collection")** | h1 ✓ | — | UI-01, UI-09, UI-10 |
| tfa/sessions/show | **✗** | h1 ✓ | — | UI-01, UI-09 |

`grep -L "content_for :title"` over non-partial views → only the two 2FA views
(plus the layout, n/a). Confirmed.

## Name/role/value & status parity sweep

- `aria-current`: `grep -rn "aria-current" app/views` → **1 hit**
  (`_pagination.html.erb:8`). Missing on: settings/_nav active tab, profiles/show
  view-toggle active link, site-nav current item → **UI-04**.
- `.active` visual-only cues: `_nav.html.erb:2-5` (×4), `profiles/show.html.erb:5`
  (view-toggle). None announced.
- Live regions: `grep -rnE "role=|aria-live" app/views` → **0** status/alert
  regions (only `role="group"` on the view-toggle). Flash (`layout:42-43`) and all
  form error blocks announce nothing → **UI-03, UI-08**.

## Landmark naming & bypass

`grep -rn "<nav" app/views`: site-nav (layout:26, no label), subnav (_nav:1, no
label), breadcrumb (collectibles/show:4, no label), pagination (aria-label ✓),
view-toggle uses `role=group aria-label="View"` (✓). Multiple unlabelled navs →
**UI-05**. `grep -rniE "skip|#main"` → none; `<main>` has no `id`/`tabindex` →
**UI-06**.

## Focus & contrast across 7 themes

- Focus: `grep -nE "focus|outline" application.css` → only a comment (line 53). No
  `:focus`/`:focus-visible` rule; no `outline:none` either. UA default outline
  retained (2.4.7 AA met) but unenhanced/weak on brand-fill controls → **UI-02**
  (Medium; enhanced-focus contrast is AAA 2.4.13, not AA).
- Contrast computed (WCAG relative-luminance), not trusted from the "AA verified"
  comment. Tightest text/UI pairs per theme:

| Theme | muted/bg | brand/bg | on-brand/brand | on-brand/danger | field-border/surface | label-text/label-bg (min) |
|---|---|---|---|---|---|---|
| light | 5.99 | 6.13 | 6.56 | 4.63 | 3.70 | 5.13 |
| dark | 7.97 | 7.73 | 7.73 | 7.59 | 5.10 | 8.43 |
| mono_light | 17.4 | 17.4 | 17.4 | 17.4 | 17.4 | 17.4 |
| mono_dark | 15.4 | 15.4 | 15.4 | 15.4 | 15.4 | 15.4 |
| woodland | 5.52 | 5.41 | 5.77 | 5.85 | 3.90 | 7.58 |
| parlour | 5.72 | 5.39 | 7.62 | 5.53 | 3.61 | 7.01 |
| retro | 6.70 | 4.54 | 5.00 | 6.50 | 4.81 | 5.58 |

  All ≥ 4.5 (text) / ≥ 3.0 (UI/border). Flash notice/alert text: 5.25–8.4 across
  themes. **Text contrast credit holds** (tightest: retro brand/bg 4.54, light
  on-danger 4.63). NOT checked: placeholder text (browser-controlled), and the
  `--border` value used as an *interactive* boundary on `.tag--link` (css:337) and
  `.pagination a` (css:677) — light `--border` #e2e5ee on #fff ≈ **1.26:1** →
  **UI-12** (non-text contrast of interactive boundaries).

## Forms sweep

Every form: labels tied to inputs (search fields use `visually-hidden`
`label_tag`; sort-composer selects each get a hidden `label_tag`;
`collection_check_boxes`/`check_box_tag` label-wrapped) — **no unlabelled input
found** (credit). Radio/checkbox groups all use `fieldset`/`legend` (credit).
Gaps: error identification/association (UI-08, all 9 forms); "OTP" label (UI-09);
missing `autocomplete` on display_name/username/identifier (UI-13); required-field
indication — optional fields marked "(optional)", low-noise convention (credit).

## Content sweep

- Images: QR SVG (`@qrcode`) raw, no `role`/label/text alt, and secret only in the
  image → **UI-10**. No other content images (icons are CSS/emoji ★).
- Link text: "CSV"/"JSON" single-word export links → **UI-14**. Others descriptive.
- Flash/error wording: plain-language, good ("This can't be undone", etc.). "OTP"
  is the one jargon label (UI-09).
- `en.yml` is the Rails stub (`hello: Hello world`) — unused; no app strings there.
- PWA manifest: `theme_color`/`background_color` = literal `"red"`, description
  `"Collection."` placeholder → **UI-15/UI-16**.

## Destructive-action census (error prevention)

| Action | Confirm step? | Finding |
|---|---|---|
| Collectible delete | ✓ confirm_delete screen | credit |
| Label delete | ✓ confirm_delete screen | credit |
| Remove person's access | ✗ single `button_to` | **UI-11** |
| Revoke share link | ✗ single `button_to` | **UI-11** |
| Delete custom sort | ✗ single `button_to` | **UI-11** |
| Sign out | ✗ (low stakes) | ok |

## Self-grill (evidence)

- Contrast credit computed, not asserted (table above); scoped — placeholder and
  interactive-border pairs explicitly excluded and the latter became UI-12. ✓
- `aria-current` census pasted (1 hit) — the parity finding is enumerated, not
  exemplified. ✓
- Every non-partial view has a title row; the two blanks (2FA) are findings, not
  omissions. ✓
- Shared-partial heading checked in *every* render context (cards vs homepage),
  which is what surfaced UI-07. ✓
- Focus: verified `outline:none` absent before calling UI-02 a missing-enhancement
  (not broken-focus), keeping it Medium not High. ✓
