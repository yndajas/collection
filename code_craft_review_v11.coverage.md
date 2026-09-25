# code_craft_review_v11 — coverage sidecar

Scaffolding for the exhaustive code-craft pass. Not a deliverable; the report
carries the findings and one attestation line each, this carries the censuses,
matrix, and per-dimension searches behind them.

- **Commit:** 0a2078c
- **Execution:** inline, 2 independent passes (my own + one fresh critic agent),
  diffed and reconciled against the code.
- **Scope:** `app/`, `lib/`, `config/`. Tests excluded per brief.

## Roster (seeded from `find app -type f`)

Controllers (12): application, collectibles, collections, profiles, follows,
root, settings, settings/custom_sorts, settings/labels,
settings/profile_accesses, settings/share_links, settings/sorting,
settings/visibility, two_factor_authentication/sessions,
two_factor_authentication/setup, users/sessions.
Models (15): application_record, user, collectible, board_game, book,
video_game, collectible_label, label, custom_sort, follow, profile_access,
share_link, pagination.
Queries (4): query_search, query_search/parser, collectible_search,
collection_search.
Services (2): collectible_exporter, collectible_importer.
Helpers (3): application_helper, collectibles_helper, root_helper.

## 1. Responsibility census (God Object / Divergent Change)

App-authored axes only; a framework mixin (Devise, AR persistence) counts as one
axis, not an exemption.

| Unit | Responsibility axes | Count | Flag |
|---|---|---|---|
| `User` | auth (devise) · identity/username-gen · social graph (follows) · visibility policy · sort/link preferences · presentation (`name`) | 5+ | **C-01 God Object** |
| `Collectible` | STI base · link catalogue+formatting · field-applicability validation | 3 | C-02/C-12 (converges) |
| `CollectiblesController` | CRUD · 3-step import pipeline (format infer, content extract, nested params) | 2 | **C-11 fat controller** |
| `CollectibleSearch` | token→SQL mapping · sort/order handling | 2 | ok (cohesive) |
| `CollectionSearch` | token→SQL mapping · sort/order · viewer-relative flags | 2 | ok |
| `QuerySearch` (base) | AST evaluation + LIKE/numeric helpers | 1 | ok (good abstraction) |
| `QuerySearch::Parser` | lex+parse to AST | 1 | ok |
| `CollectibleImporter` | parse (3 formats) + normalise + label-resolve | 1-2 | ok (cohesive) |
| `CollectibleExporter` | CSV + JSON serialise | 1 | ok |
| `ApplicationController` | pagination · link-visibility policy · 2FA gate | 3 | **C-20** (minor while small) |
| `Pagination` | page math | 1 | ok |
| `CustomSort` | criteria validation + display | 1-2 | ok |
| `Label` | validation + prune-on-type-change | 1-2 | ok |
| `Follow`/`ProfileAccess`/`ShareLink` | join + guard | 1 each | ok |
| helpers | tag/count/subtitle presentation | 1 each | ok (collectibles_helper hosts C-02 switch + C-03 N+1) |

## 2. Type-dispatch census (Repeated Switch → C-02)

`grep -rnE 'is_a\?|\.class\b|when [A-Z]' app` (relevant hits):
- `_form.html.erb:25,30,42,55,58` — `is_a?(VideoGame/BoardGame/Book)` chain
- `_import_fields.html.erb:18,24,33,50,51` — same chain
- `collectibles_helper.rb:39,41,44` — `collectible_subtitle` `when VideoGame/BoardGame/Book`
- `collectible_exporter.rb:66,74,81` — `type_specific` same switch
Non-findings (idiomatic): `pagination.rb:37` (`is_a?(Integer)`), `collectibles_controller.rb:177` (`is_a?(ActionController::Parameters)`), importer `is_a?(Array/Hash)`, `collectible.rb:67`/`collectible_search.rb:119` (`self.class`).
→ 4 app-type switch sites, subclasses already exist. C-02.

## 3. Duplication / connascence census

- `grep -rn 'TYPE_ALIASES' app`: defined in `collectible_search.rb:87` AND
  `collectible_importer.rb:14` (drifted copies); `collection_search.rb:135`
  reuses the search copy. → **C-06**.
- Visibility rule: `user.rb:89-95` (`visible_to_viewer` scope) vs `:104-112`
  (`visible_to?` predicate) — same policy twice, token branch only in the
  predicate. → **C-10** (connascence of algorithm).
- `negated ? scope.where.not(id:) : scope.where(id:)` idiom: 8 sites in
  `collection_search.rb`, 1 in `collectible_search.rb`, 2 in `query_search.rb`
  (`grep -rnc`). Consistent, not drifted — noted, not a finding (extractable but
  the repetition is thin and each reads clearly).

## 4. Query / N+1 per-template trace

For every template iterating a collection, the per-row call and whether it fires I/O:

| Template | Per-row call | I/O? | Finding |
|---|---|---|---|
| `_profile_row.html.erb:12` | `collectible_counts(user)` → `user.collectibles.group(:type).count` | **yes, per row** | **C-03** |
| `_profile_row.html.erb:2` | `collection_tags` → memoised Set lookup | no (credited) | — |
| `_collectible.html.erb:24` | `collectible.labels.ordered` (scope on preloaded assoc) | **yes, per row** | **C-04** |
| `_collectible.html.erb:22,28` | `labels.any?`, `search_links` | no (loaded / in-memory) | — |
| `collectibles/show.html.erb:36` | `@collectible.labels.ordered` | yes (single record) | C-04 (same root) |
| `labels/index.html.erb:40` | `label.collectibles.size` | **yes, per row** | **C-05** |
| `sorting/show.html.erb:30,32` | `custom_sorts.ordered` twice | yes ×2 | C-18 |
| `profiles/show.html.erb:55,64` list/cards | link_to / helper (no DB) | no | — |
| `root/index` highlights | `_collectible` ×2 (labels not preloaded) | 2 queries | C-18 (minor) |

Rendered-at map for C-03: `_profile_row` ← `collections/index.html.erb:15`,
`root/_collection_list.html.erb:5` (×3 lists: @recent, @followed, @shared).

## 5. High-stakes-flow census

| Flow | Loads-then-authorizes? / oracle | Verdict |
|---|---|---|
| Sign in (`users/sessions`) | warden auth; 2FA gate on `consumed_timestep` | ok; invariant spread → C-17 |
| 2FA verify (`tfa/sessions`) | session `otp_user_id` guarded | ok |
| Collectible **show** (`set_collectible`) | `.find` **before** `visible_to?` → 404-vs-403 | **C-07 existence oracle** |
| Collectible edit/update/destroy | `current_user.collectibles.find` (owner-scoped) | ok |
| Grant access (`profile_accesses#create`) | user lookup answers hit≠miss + echoes name | **C-08 enumeration** |
| Label/custom_sort/share_link destroy | `current_user.*.find` (owner-scoped) | ok |
| Follow create/destroy | `visible_to?` + not-self + unique index | ok (idempotent) |
| CSV/JSON export | owner or visible profile; raw values written | **C-09 CSV injection** |

## 6. Security sub-pass

- Access control: mutating actions all owner-scoped via `current_user.*.find`
  (falsified: no `Model.find(params[:id])` on a write path). Read path leaks: C-07.
- Injection: all LIKE/where use bound params (safe) BUT `count_order`
  interpolates whitelisted `type` (C-14) and LIKE values don't escape `%`/`_`
  (C-13, correctness). No SQLi.
- Mass assignment: strong params + constant intersection everywhere (settings,
  labels, collectibles). ok.
- Info disclosure: C-07, C-08. Tokens `SecureRandom.urlsafe_base64(16)` (ok).
- Misconfig: CSP commented stub (`content_security_policy.rb`) → C-15; production
  `force_ssl`/`assume_ssl`/`hosts` commented (`production.rb:24-66`) → C-16.
- Output: user fields rendered via ERB (auto-escaped); `@qrcode.html_safe` is
  library-generated SVG (same-origin) — low risk but argues for CSP (C-15).

## 7. Coverage matrix (in-scope files × dimensions swept)

All 12 controllers, 15 models, 4 queries, 2 services, 3 helpers, routes,
initializers (CSP, devise, filter_params, assets, inflections, CSP), both env
files, locales: each read and swept for responsibility, duplication, N+1 (where
it renders), security, correctness. `lib/tasks/*.rake` (coverage, cucumber) and
`db/migrate/*` read for indexes/integrity only — noted as a coverage gap for a
deeper migration audit. No blank rows.

## Self-grill (evidence)

- Credits falsified from the right file? N+1 credits (tag memoisation) checked
  from the *view* (`_profile_row` → memoised Set), not the helper. The surviving
  N+1 (C-03 counts) is a different call — credit scoped to tags only. ✓
- Every named smell has a pasted search (§2, §3). ✓
- Responsibility census covers *every* unit, not just big ones (§1 full roster). ✓
- Existence-oracle downgraded from "bug" to precise 404-vs-403 claim after
  re-reading `set_collectible:146-157`. ✓
- RANDOM nil case (`root_controller.rb:21`) re-traced: empty→nil, 1-item→nil,
  guarded by view; **not** a live bug (C-18 keeps it as a latent-idiom note only). ✓
