# code-craft v9 - coverage sidecar (scaffolding, not the report)

Exhaustive inline review. Scope: all of `app/` (Ruby + view-triggered
behaviour) + `db/schema.rb` + `config/routes.rb`. Tests excluded per request.

## Coverage matrix (one row per in-scope Ruby/behaviour file)

Dimensions: DUP=duplication, DEP=dependency direction, CON=connascence,
SW=repeated switch, GOD=responsibility/God-class, N1=view/query N+1,
REL=reliability, SEC=security. `.`=swept clean, `F`=finding, `n/a`.

| File | DUP | DEP | CON | SW | GOD | N1 | REL | SEC |
|---|---|---|---|---|---|---|---|---|
| models/user.rb | . | F | F | . | F | . | . | . |
| models/collectible.rb | . | . | F | . | F | n/a | . | . |
| models/board_game.rb | . | . | . | . | . | n/a | n/a | n/a |
| models/book.rb | . | . | . | . | . | n/a | n/a | n/a |
| models/video_game.rb | . | . | . | . | . | n/a | n/a | n/a |
| models/custom_sort.rb | . | F | F | . | . | . | . | . |
| models/label.rb | . | . | . | . | . | . | . | . |
| models/collectible_label.rb | . | . | . | . | . | n/a | n/a | . |
| models/follow.rb | . | . | . | . | . | n/a | . (idempotent) | . |
| models/profile_access.rb | . | . | . | . | . | n/a | . | . |
| models/share_link.rb | . | . | . | . | . | . | . (token) | . |
| models/pagination.rb | . | . | . | . | . | . | . | . |
| queries/query_search.rb | . | . | . | . | . | . | n/a | F (LIKE wildcard) |
| queries/query_search/parser.rb | . | . | . | . | . | n/a | n/a | . |
| queries/collectible_search.rb | . | . | F | . | F | . | n/a | . (allowlist-safe) |
| queries/collection_search.rb | F (alias) | . | F | . | . | . | n/a | . (allowlist-safe) |
| services/collectible_exporter.rb | F | . | F (roster) | F | . | n/a | . | . |
| services/collectible_importer.rb | F (alias) | . | F (roster) | . | . | . | . (txn elsewhere) | . |
| helpers/application_helper.rb | . | . | . | . | . | . (memoised - credit) | n/a | . |
| helpers/collectibles_helper.rb | . | . | . | F | . | F (counts) | n/a | . |
| helpers/root_helper.rb | . | . | . | . | . | n/a | n/a | n/a |
| controllers/application_controller.rb | . | . | . | . | . | . | . | . |
| controllers/collectibles_controller.rb | F (label ids) | . | . | . | F (fat) | . | . (import txn - credit) | . |
| controllers/collections_controller.rb | . | . | . | . | . | . | . | . |
| controllers/profiles_controller.rb | . | . | . | . | F (long/9 ivars) | . (includes - see N1 note) | . | . |
| controllers/follows_controller.rb | . | . | . | . | . | . | . (idempotent - credit) | . |
| controllers/root_controller.rb | . | . | . | . | . | . | . | . |
| controllers/settings_controller.rb | F (complement) | . | . | . | . | . | . | . |
| controllers/settings/sorting_controller.rb | F (complement) | . | . | . | . | . | . | . |
| controllers/settings/labels_controller.rb | . | . | . | . | . | F (view) | . | . |
| controllers/settings/custom_sorts_controller.rb | . | . | F (matrix/custom-N) | . | . | . | . | . |
| controllers/settings/visibility_controller.rb | . | . | . | . | . | . | . | . |
| controllers/settings/profile_accesses_controller.rb | . | . | . | . | . | . | . | . |
| controllers/settings/share_links_controller.rb | . | . | . | . | . | . | . | . |
| controllers/two_factor_authentication/sessions_controller.rb | . | . | . | . | . | . | . | . |
| controllers/two_factor_authentication/setup_controller.rb | . | . | . | . | . | . | . | . |
| controllers/users/sessions_controller.rb | . | . | . | . | . | . | . | . |

Views swept for view-triggered I/O and type switches (code-craft lens):
_collectible (F: labels.ordered; SW via helpers), profiles/show (F same),
_profile_row (F: collectible_counts), settings/labels/index (F:
collectibles.size), _import_fields (F: labels.ordered per item; SW), _form (SW),
review, collectible show. All other templates: no per-row I/O.

## Per-dimension sweep commands (pasted, not "I looked")

- Type switches (SW): `grep -rn "is_a?\|\.class\b\|when VideoGame\|when BoardGame\|when Book" app/`
  -> hits in _import_fields, _form, collectibles_helper#collectible_subtitle,
  collectible_exporter#type_specific. (Pagination `.is_a?(Integer)` and
  `ActionController::Parameters`/`Array`/`Hash` guards are not type dispatch.)
- Type-alias duplication (DUP/CON): `grep -rn "TYPE_ALIASES" app/`
  -> defined twice: collectible_search.rb:87 and collectible_importer.rb:14
  (importer keeps its own copy; collection_search reuses CollectibleSearch's).
- Attribute roster spread (CON): loop over field names ->
  system/author 11-13 files, min/max_players 10, boolean flags 9-12 files.
- Dependency direction (DEP): `grep -rn "CollectibleSearch\|CollectionSearch" app/models/`
  -> user.rb (5 sites) + custom_sort.rb (5 sites) reach UP into the query layer.
- custom-N format (CON): `grep -rn "custom-" app/`
  -> agreed in custom_sort.rb:15 (writer), user.rb:117 (regex reader),
  collectible_search.rb (consumer via custom_sorts hash keys).
- applicable-label filtering (DUP): `grep -rn "applies_to_type?" app/`
  -> collectibles_controller:189, _form.erb:67, _import_fields.erb:72.
- shown/hidden complement (DUP): settings_controller:27-28 and
  sorting_controller:12-13 (same "store the complement of the ticked set").
- View I/O (N1): `grep -rn "\.ordered\b\|\.size\b\|\.count\b\|collectible_counts" app/views/`
  + `grep -rn "includes" app/controllers/`.
- SQL interpolation (SEC): `grep -rn "Arel.sql\|#{" app/queries/` -> all inlined
  values are fixed operators, `.to_i` integers, or allowlisted type/column
  names; LIKE `?`-parameterised. Only gap: `%`/`_` wildcards in the user value
  are not escaped (over-match, not injection).

## Responsibility census (God-class test - every unit, not the big ones)

App-authored axes counted; framework mixins = 1 axis.

- **User (145L) = 5+ axes: identity/username, social graph (follows),
  authorization/visibility, external-link prefs, sort prefs, view/theme prefs
  -> God Class, High.**
- **Collectible (105L) = 3 axes: STI type system, external-link catalogue,
  field-applicability validation -> Divergent Change, Medium** (link catalogue
  is the separable one).
- **CollectibleSearch (248L) = 3 axes: query-token filtering, sort
  vocabulary/config, player-bound arithmetic -> Divergent Change + Large Class,
  High** (the sort-config axis is what other layers depend on).
- **CollectiblesController (201L, 23 methods) = 3+ axes: collectible CRUD, bulk
  import flow (4 actions + 4 helpers), STI building + label filtering -> fat
  controller, High.**
- ProfilesController (66L, one action, 9 ivars): long single action, cohesive
  (one collection view) -> Medium (extract preference-remembering + exports).
- CustomSort (76L): custom-sort definition + 5 validations - cohesive, 1 axis
  (but DEP finding). CollectionSearch (155L): cohesive query object, 1 axis.
  CollectibleImporter (138L): import parsing, cohesive, 1 axis (DUP alias).
  CollectibleExporter (87L): serialisation, cohesive but carries the type SW.
  Label, Follow, ProfileAccess, ShareLink, CollectibleLabel, Pagination, the
  three STI subclasses, all settings sub-controllers, sessions/2FA
  controllers: 1 axis each, not God classes.

## Credits falsified (ledger)

- "includes(:labels) avoids the label N+1" - FALSE as written: the card partial
  calls `collectible.labels.ordered`, and a scope on a loaded association
  re-queries, defeating the preload. Became finding CC-1.
- "followed/shared ids memoised, no N+1 for the following decoration" - TRUE:
  application_helper memoises both sets once per request; `_profile_row` reads
  the sets, not per-row queries. Credit stands (scoped to the tag decoration -
  the counts on the same row are a separate N+1, CC-2).
- "import is idempotent/atomic" - `Collectible.transaction { save! }` gives
  atomicity (credit); no idempotency key, but import is an interactive
  non-retried POST, so not required.
- "follow is idempotent" - TRUE: `find_or_create_by` + unique index
  `(follower_id, followed_id)`. Credit stands.
- "raw SQL is injection-safe" - TRUE: operators fixed, integers cast, type via
  TYPE_ALIASES allowlist, columns from fixed sets; LIKE parameterised. Credit
  stands, with the unescaped-wildcard caveat (CC-sec).

## Self-grill (evidence)

- Sidecar exists with matrix + per-dimension commands + census: yes (this file).
- Every credit has a falsifying answer above: yes.
- Performance falsified from the template not the loader: yes -
  `_collectible.html.erb:24` / `show.html.erb:36` `.ordered`;
  `_profile_row.html.erb:12` `collectible_counts`;
  `settings/labels/index.html.erb:40` `label.collectibles.size`;
  `_import_fields.html.erb:72` `current_user.labels.ordered` per item.
- Subjects at 3+ dimensions each have a High finding: User, CollectibleSearch,
  CollectiblesController - all High. No downgrade applied.
- performance.md and reliability.md worked (app does DB I/O), not skipped.
- Surfaced in self-review: the `_import_fields` per-item label re-query (a 4th
  N+1 site, easy to miss because the partial looks like a form, not a list).
