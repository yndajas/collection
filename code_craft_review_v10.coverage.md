# Code-craft v10 — coverage sidecar

Scaffolding for `code_craft_review_v10.md`. Retained so every attestation in the
report traces to a filled cell or a search. Synthesised from two independent
passes' sidecars (`pass_A.coverage.md`, `pass_B.coverage.md`) plus an adjudication
read.

## Responsibility census (every controller / model / service / query)

Axes = distinct app-authored reasons to change (a framework mixin counts once).

| Unit | Axes | Count | Verdict |
|---|---|---|---|
| `application_controller` | pagination, link-visibility, 2FA gate | 3 | fat-ish (link logic → CC7) |
| `collectibles_controller` | CRUD, 3-step import, STI build, label filter | 4 | **fat (CC5)** |
| `collections_controller` | index/search, sort persistence | 2 | ok |
| `profiles_controller` | show/search/export, pref persistence | 2 | ok (GET-write CC11) |
| `follows_controller` | follow CRUD | 1 | ok (race CC10) |
| `settings_controller` | profile+link settings | 1 | ok (inversion CC7) |
| `settings/visibility,share_links,profile_accesses,custom_sorts,labels,sorting` | one concern each | 1 | ok (enum SEC3) |
| `two_factor_authentication/*`, `users/sessions` | auth | 1 | ok (SEC4) |
| `models/user` | auth, identity, social graph, visibility, preferences | **5** | **God Class (CC1)** |
| `models/collectible` | persistence+STI, link catalogue, applicability, type meta | **4** | **multi-responsibility (CC2)** |
| `video_game`/`board_game`/`book` | type behaviour | 1 | ok (should absorb CC3) |
| `label`, `collectible_label`, `custom_sort`, `follow`, `profile_access`, `share_link`, `pagination` | one each | 1 | ok (CC12) |
| `queries/query_search` (+parser) | AST eval, match primitives | 2 | ok (LIKE CC9) |
| `queries/collectible_search` | token map, sort, player algebra | 3 | **fat (CC6)** |
| `queries/collection_search` | token map, sort, counts | 2 | ok (clause dup CC8) |
| `services/collectible_exporter` | CSV+JSON serialise, type switch | 2 | type switch (CC3) |
| `services/collectible_importer` | parse 3 formats, normalise, label resolve | 2 | ok (alias dup CC8) |

## Whole-scope dimension sweeps (searches run)

- **Type switches (CC3):** `grep -rn 'is_a?\|case .*when [A-Z]\|\.class\b' app` →
  `collectibles_helper.rb:38`, `collectible_exporter.rb:65`, `_form.html.erb:25`,
  `_import_fields.html.erb:18`. 4 sites.
- **Duplicated roster (CC8):** searched `TYPE_ALIASES` → 2 defs
  (`collectible_search.rb:87`, `collectible_importer.rb:14`); NULL-safe negation
  clause `(col IS NULL OR NOT` → 3 sites; sort keys (`SORTS`/`DEFAULT_OPTIONS`/
  `SORT_FIELDS`/`custom-\d+`) spread across query, `user.rb`, `custom_sort.rb`,
  views.
- **Inverted dependency (CC1):** grep `user.rb` for higher-layer constants →
  `CollectionSearch::SORTS:48`, `CollectibleSearch::DEFAULT_OPTIONS:65`,
  `.default_option:69`, `CollectibleSearch::SORTS:117`, `Collectible::LINK_KEYS:128`.
- **Raw/interpolated SQL (security + CC9):** grep `"#{`/`Arel.sql`/`LIKE` in
  `app/queries` → LIKE wildcard wrap (`query_search.rb:46,59`,
  `collectible_search.rb:226`) = CC9; ORDER/HAVING interpolation
  (`collection_search.rb:70,128`; `collectible_search.rb:176,179,192,195`) — all
  operands integer/whitelisted, injection-safe.
- **N+1 per-template trace (CC4):** every template iterating a collection —
  `_profile_row` → `collectible_counts` GROUP/COUNT per row; `_collectible`/
  `show` → `labels.ordered` re-query defeating `includes(:labels)`;
  `settings/labels/index:40` → `label.collectibles.size` per row;
  `_import_fields:72` → `labels.ordered` per item. `profiles/show` list view and
  `root/index` highlights fire no per-row I/O.
- **IDOR (credit):** grep `find(`/`find_by!` in controllers → all mutable loads go
  through `current_user.<assoc>.find`; `require_own_profile` guards nested owner
  paths; `ProfilesController#show`/`CollectiblesController#show` gate on
  `visible_to?`.
- **Idempotency/races (CC10):** `find_or_create_by`/`while User.exists?` →
  `follows_controller:11`, `user.rb:139`, `profile_accesses:15` (unique index is
  the guard; `RecordNotUnique` unhandled).

## File coverage matrix (in-scope code files)

Legend: ✓ swept, F finding, n/a not applicable.

| File | SRP/OO | Dup/connasc | Switch | Perf/N+1 | Reliability | Security |
|---|---|---|---|---|---|---|
| user.rb | F(CC1) | F(CC8) | ✓ | ✓ | F(CC10) | ✓ |
| collectible.rb | F(CC2) | F(CC2) | F(CC3 src) | ✓ | ✓ | ✓ |
| video/board/book.rb | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| label / collectible_label / custom_sort / follow / profile_access / share_link | ✓ | ✓ | ✓ | ✓ | ✓(CC10 follow/pa) | ✓ |
| pagination.rb | ✓ | ✓ | n/a | F(CC12) | ✓ | n/a |
| query_search(+parser) | ✓ | F(CC8) | ✓ | ✓ | ✓ | F(CC9) |
| collectible_search.rb | F(CC6) | F(CC8) | ✓ | ✓ | ✓ | F(CC9) |
| collection_search.rb | ✓ | F(CC8) | ✓ | ✓ | ✓ | ✓ |
| collectible_exporter.rb | ✓ | ✓ | F(CC3) | ✓ | ✓ | ✓ |
| collectible_importer.rb | ✓ | F(CC8) | ✓ | ✓ | ✓ | ✓ |
| application_controller | F(CC7) | ✓ | ✓ | ✓ | ✓ | ✓ |
| collectibles_controller | F(CC5) | ✓ | ✓ | ✓ | ✓ | ✓(param allowlist) |
| collections/profiles_controller | ✓ | ✓ | ✓ | F(CC4 origin) | ✓ | ✓(CC11) |
| follows_controller | ✓ | ✓ | ✓ | ✓ | F(CC10) | ✓ |
| settings/* controllers | F(CC7 settings) | ✓ | ✓ | ✓ | ✓ | F(SEC3 pa) |
| 2fa/* + users/sessions | ✓ | ✓ | ✓ | ✓ | ✓ | F(SEC4) |
| helpers (application/collectibles/root) | ✓ | ✓ | F(CC3 subtitle) | F(CC4 counts) | ✓ | ✓ |
| config/initializers/CSP | n/a | n/a | n/a | n/a | n/a | F(SEC1) |
| config/environments/production | n/a | n/a | n/a | n/a | n/a | F(SEC2) |

All in-scope code files have a finding or a ✓ in every applicable cell.
Performance and reliability were worked (not marked optional): the app does DB
I/O throughout, so both catalogues applied.
