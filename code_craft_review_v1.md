# Design Review: Collection

Design review of the whole app (models, controllers, queries, services, helpers)
through the combined `code-craft` lens: Sandi Metz (POODR / 99 Bottles) and
Martin Fowler (*Refactoring*) for object shape and smells, the Gang of Four for
patterns, and the Pragmatic Programmer / Code Complete for construction quality
and reliability. Smell names are Fowler's; principle attributions go to their
originators.

This revision re-grounds the original pass against the actual code, corrects two
overstated findings, and names the connascence where it sharpens the argument.
Tests are deliberately out of scope: this is a prototype branch, and test
coverage will be addressed piece by piece when these changes land on `main`.

**34 findings — 11 High, 15 Medium, 8 Low.**

---

## Verdict

The bones are genuinely good. Query objects (`CollectibleSearch`,
`CollectionSearch`), services (importer/exporter), a clean `Pagination` value
object, a schema-agnostic recursive-descent `Parser`, and disciplined STI all
already exist and are used - the controllers orchestrate rather than compute.

The smells that remain are concentrated and systematic, not scattered - the
healthy kind. They collapse into five recurring patterns, so fixing the pattern
fixes many findings at once.

---

## What's already working (credit first)

- **The `Parser`** knows nothing about valid keys or any database - tokenizer
  and recursive-descent stages cleanly separated, and `simplify` canonicalises
  the tree. Right boundary, not over-engineered.
- **The id-subquery composition in `evaluate`** - AND intersects via
  `where(id:)`, OR unions structurally-identical subqueries so negation and
  nesting compose. A real design insight, well commented.
- **`Pagination`** is a textbook small object - no AR coupling, tell-don't-ask
  methods (`prev?`, `next?`, `series`), sensible defaults.
- **The STI dispatch mechanism** - snake_case `sti_name` mapping plus
  `applicable_fields`/`applicable_link_keys` as overridable methods - is genuine
  polymorphism. The leaks are at the leaf methods, not the dispatch.
- **Small, correct join models** (`Follow`, `ProfileAccess`, `ShareLink`) with
  DB indexes matching their validations; and `User` already owns most of its
  policy, so most controller fixes are moving a call, not writing new logic.

---

## Five recurring themes

Every finding below is an instance of one of these. Referenced as T1-T5 in the
priority list.

- **T1 - Type switches that want polymorphism.** The STI type keeps reappearing
  as a `case` instead of the object answering for itself (the dominant Metz
  smell): exporter `type_specific`, helper `collectible_subtitle`, importer
  aliases, `only_applicable_fields_set`'s boolean type-sniff, and the search
  `case key` / `case flag`.
- **T2 - Dependency points the wrong way.** Persistence models and controllers
  reach *up* into the query layer (`CollectibleSearch::SORTS`, `SORT_FIELDS`),
  and the `"custom-N"` sort-key format is duplicated by convention in three
  places. Fix: a neutral `SortCatalogue`/`SortField` registry both depend on.
- **T3 - Preferences belong on `User`.** The sort/view-remember dance is
  copy-pasted across two controllers, and its resolution logic leaks into
  `profiles#show`. Highest ROI: `current_user.remember_collection_preferences(...)`
  and `effective_sort(requested)`.
- **T4 - `User` is a God Object.** Five responsibilities in one file (auth,
  identity, visibility, sort-preferences, follow wiring), which is also why
  `profiles#show` and `root#index` are fat. Extract `SortPreferences` and
  `ProfileVisibility` policy objects; this absorbs much of T2 and T3.
- **T5 - Hand-built SQL strings in search.** One real bug (unescaped LIKE, below)
  and a NULL-safe negation clause duplicated across four methods. The interpolated
  numeric clauses look risky but aren't an injection surface - operators are
  whitelisted and values pass through `Integer()`/`.to_i` first - so the fix is
  about duplication and readability, not safety. Fix: `sanitize_sql_like` for the
  bug, reuse `match_like` in `match_label`, and a `NumericBound` value object to
  retire the duplicated clause.

---

## The one actual bug

**Unescaped `LIKE` wildcards** - `query_search.rb:45`, `collectible_search.rb:226`.
`match_like`/`match_any_like` build `"%#{value}%"` without escaping, so `%` and
`_` in a search term act as wildcards: `title:100%` or `notes:a_b` match more
than the user typed. Binding stops injection but not this. One line:
`ActiveRecord::Base.sanitize_sql_like`.

---

## Full findings

Format: **[Severity] Title** - `file:line` - *smell* - description **→ refactor**.

### Models (4 High, 5 Medium, 3 Low)

- **[High] User is a God Object** - `user.rb` - *Large Class / Divergent Change* -
  Auth, identity, visibility, sort-preferences and follow wiring in one file.
  **→ Extract `SortPreferences` and `ProfileVisibility` policy objects; User delegates.**
- **[High] Models depend on query-object internals** - `user.rb:48,117`,
  `custom_sort.rb:30,68`, `label.rb:24` - *Dependency Direction / Feature Envy* -
  User/CustomSort reach up into `CollectibleSearch::SORTS`, `SORT_FIELDS`,
  `.custom_order`. **→ A neutral `SortCatalogue`/`SortField` registry both layers depend on.**
- **[High] `only_applicable_fields_set` type-sniffs via primitives** -
  `collectible.rb:82` - *Primitive Obsession / hidden Repeated Switch* -
  `[true,false].include?(value)` exists only because booleans and strings share
  one flat `OPTIONAL_FIELDS` array. **→ Model each optional field as an object
  answering `set?(collectible)`.**
- **[High] `search_links` envies `LINK_DEFINITIONS`** - `collectible.rb:96` -
  *Feature Envy / Primitive Obsession* - CGI-escape, intersect, select/format/map/sort
  over an array of hashes. **→ A `SearchLink` value object (`key`, `name`,
  `url_template`, `#for(query)`).**
- **[Medium] Duplicated self-reference validation** - `profile_access.rb:10`,
  `follow.rb:10` - *Duplicated Code / Shotgun Surgery* - Two directed user-to-user
  joins with the identical "these FKs must differ" rule. **→ A shared
  `DistinctUserPair` concern.**
- **[Medium] `assign_username` is a Long Method** - `user.rb:132` -
  *Long Method / SRP* - A slug + collision-resolution loop in a callback.
  **→ Extract `UsernameGenerator.call(email)`.** *(Correction to the first pass:
  the check-then-set loop is a TOCTOU race, but `users.username` has a unique
  index (`db/schema.rb:124`), so a concurrent collision raises `RecordNotUnique`
  rather than creating a duplicate. It's a not-retry-safe callback, not a
  data-integrity bug - the fix is extraction plus a rescue/retry, not new
  locking.)*
- **[Medium] `sort_options` builds view data in the model** - `user.rb:64` -
  *Long Method / Feature Envy* - Produces `[label, key]` dropdown pairs inside
  the AR model. **→ Move to the `SortPreferences` object.**
- **[Medium] Stringly-typed `custom-N` regex** - `user.rb:117` -
  *Primitive Obsession / Connascence of Meaning* - `/\Acustom-\d+\z/` silently
  shares a format with `CustomSort#key` (`custom_sort.rb:15`) and the search's
  `@custom_sorts` keys - three places that agree on what `"custom-5"` means only
  by convention, so they must change together (the strongest, most spread-out
  form of connascence here). **→ Give the format one owner: `CustomSort.key?(str)`
  / `CustomSort.key_for(id)`.**
- **[Medium] Label prune hidden in `after_update`** - `label.rb:13,37` -
  *Callback side effect / Tell-Don't-Ask* - A destructive cascade buried in a
  callback, invisible to callers. **→ Extract `LabelTypePruner` (or a public
  `prune!`) invoked explicitly.**
- **[Low] `player_count` formatting on the model** - `board_game.rb:10` -
  *Primitive Obsession / presentation in model* - "2-4"/"up to 4"/"3+" guard
  ladder is view formatting. **→ A `BoardGamePresenter` (same as `CustomSort#summary`).**
- **[Low] `type_label` defined twice** - `collectible.rb:61` - *minor Duplicated
  Code* - Instance method delegates to the class method; only the class one is
  documented. Harmless.
- **[Low] `visible_to?` guard ladder** - `user.rb:104` - *borderline Law of
  Demeter* - Five auth rules in one method; the scoped queries are idiomatic.
  **→ Natural home for the `ProfileVisibility` extraction.**

### Controllers (4 High, 5 Medium, 2 Low)

- **[High] Sort/view preference persistence duplicated** - `profiles_controller.rb:60`,
  `collections_controller.rb:24` - *Duplicated Code / Feature Envy* - Near-identical
  whitelist → `update_columns` → read-back, comments and all. **→
  `current_user.remember_collection_preferences(view:, sort:)`.**
- **[High] `profiles#show` does five jobs, eight ivars** - `profiles_controller.rb:4` -
  *Long Method / SRP* - Gate, resolve preferences, build search, resolve link
  keys, branch 3 formats. **→ Extract preference resolution; a `before_action`
  for the gate.**
- **[High] `valid_sorts` resolution in the controller** - `profiles_controller.rb:22` -
  *Feature Envy* - `CollectibleSearch::SORTS.keys + custom_orders.keys` and a
  literal `"updated"` default. **→ `User#effective_sort(requested)`.**
- **[High] Visibility gate duplicated across two controllers** -
  `profiles_controller.rb:8`, `collectibles_controller.rb:152` -
  *Duplicated Code / Shotgun Surgery* - Same visible_to? → store_location →
  render forbidden; the copies have already drifted. **→ Shared
  `before_action :require_visible_profile`.**
- **[Medium] `root#index` builds four sections inline** - `root_controller.rb:4` -
  *Long Method / Feature Envy* - Queries another user's relationships from the
  controller. **→ `current_user.shared_collections`,
  `User.recently_updated_visible_to(user)`, `highlight_collectibles`.**
- **[Medium] `viewer_link_keys` asks then decides** - `application_controller.rb:20` -
  *Feature Envy / Tell-Don't-Ask* - Computes the viewer's own display policy
  outside the viewer. **→ `current_user.link_keys_for(owner)`.**
- **[Medium] Email-or-username lookup inline with duped string** -
  `settings/profile_accesses_controller.rb:6` - *Primitive Obsession / Feature
  Envy* - Raw SQL + the normalised identifier twice; the concept isn't named.
  **→ `User.find_by_identifier(str)`.**
- **[Medium] `CustomSortsController` carries the criteria algorithm** -
  `settings/custom_sorts_controller.rb:47` - *Feature Envy* - `build_criteria`/
  `matrix_from_criteria` with its own error accumulation is domain logic. **→ A
  `CustomSort::CriteriaMatrix` value object; rank-uniqueness as a model validation.**
- **[Medium] `ShareLinksController` owns expiry math** -
  `settings/share_links_controller.rb:5` - *Feature Envy / Divergent Change* -
  Holds `EXPIRY_OPTIONS` and computes `expires_at`. **→ Move both onto
  `ShareLink` (the view needs the options too).**
- **[Low] Inconsistent strong-params style** - `settings/*_controller.rb` -
  *Inconsistent patterns* - `require.permit` vs `params.dig` vs flat `params[]`;
  the show→hidden-complement transform is duplicated. **→ Standardise; extract
  `hidden_complement(shown, all)`.**
- **[Low] `FollowsController#destroy` double ternary** - `follows_controller.rb:20` -
  *minor duplicated conditional* - Branches on `target` twice; a nil target reads
  as success. **→ Guard early; add `current_user.unfollow(target)`.**

### Queries, services & helpers (3 High, 5 Medium, 3 Low)

- **[High] `apply` is a Repeated Switch, duplicated across subclasses** -
  `collectible_search.rb:132`, `collection_search.rb:81` - *Repeated Switch /
  Open-Closed (Meyer)* - Both open with the same unpack + blank guard then a long
  `case key`. **→ A lookup of filter-handler objects; the base owns `apply`.**
- **[High] `apply_flag` - nested switch with inconsistent shapes** -
  `collectible_search.rb:230`, `collection_search.rb:99` - *Repeated Switch /
  mixed abstraction* - Most branches return a condition hash; `"multiplayer"`
  breaks the pattern with early returns. **→ Flag → predicate objects with one
  uniform apply/negate contract.**
- **[High] Unescaped LIKE + duplicated NULL-safe negation** - `query_search.rb:45`,
  `collection_search.rb:67`, `collectible_search.rb:176,192` - *safety (the bug) +
  Duplicated Code* - Two distinct issues the first pass merged under one "safety"
  banner. (1) The real bug: unescaped `%`/`_` in `match_like`/`match_any_like`
  (see below). (2) The interpolated numeric clauses are **not** an injection
  surface - operators come from a fixed whitelist and every value passes through
  `Integer()`/`.to_i` before interpolation, so the justification for a
  `NumericBound`/Arel rewrite is *duplication and readability* (the NULL-safe
  `IS NULL OR NOT (...)` clause is copy-pasted verbatim across `match_players`,
  `match_player_field` and both `match_*_like` helpers), **not** safety.
  **→ `sanitize_sql_like` for the LIKE bug; a `NumericBound` value object to
  retire the duplicated negation clause.**
- **[Medium] Sort constants + resolution bloat `CollectibleSearch`** -
  `collectible_search.rb:31` - *Large Class* - `SORTS`/`DEFAULT_OPTIONS`/
  `SORT_FIELDS` + `custom_order`/`valid_sort?`/`order_clause` are a distinct
  concern. **→ Extract a `CollectibleSort` value object.**
- **[Medium] Exporter `type_specific` switches on class** -
  `collectible_exporter.rb:64` - *Repeated Switch / Feature Envy* - `when
  VideoGame / BoardGame / Book` reaches into each subclass's fields. **→
  Polymorphic `#export_attributes` on each subclass (retires the helper switch too).**
- **[Medium] `to_csv` - 16-element positional row** - `collectible_exporter.rb:16` -
  *Long Method / Connascence of Position* - The row and `CSV_HEADERS` must stay
  index-aligned by position alone; reorder one and the export silently mislabels
  every column. Positional connascence is the brittlest kind. **→ Derive the row
  from an ordered header→attribute mapping so name, not index, binds them.**
- **[Medium] Importer `normalise` - per-attribute repetition** -
  `collectible_importer.rb:94` - *Long Method / Primitive Obsession* - 14 lines
  of `result[:x] = ... if attrs.key?(:x)`; the row is a bare Hash. **→
  Data-driven loop keyed by attribute type; an `ImportedRow`.**
- **[Medium] Helpers holding model logic** - `collectibles_helper.rb:5,37`,
  `root_helper.rb` - *misplaced responsibility / dead code* - `collectible_counts`
  runs a query + domain formatting; `collectible_subtitle` is the type switch;
  `RootHelper` is empty. **→ Move to model/presenter; delete `RootHelper`.**
- **[Low] `page_url` reads ambient `request`** - `application_helper.rb:50` -
  *hidden dependency* - Mildly test-hostile, acceptable for a view helper.
- **[Low] `own_ids` builds a relation for one known id** - `collection_search.rb:144` -
  *small smell (deliberate)* - Used as an id-subquery for uniform composition.
  **→ A one-line comment noting the reason.**
- **[Low] Repeated `return ... if @viewer.nil?` guard** - `collection_search.rb:138` -
  *minor Duplicated Code* - Three methods open identically. **→ A single
  `viewer_scoped { ... }` wrapper.**

---

## If you do five things (ROI order)

1. **Preferences → `User`** (T3) - kills the two/three-controller duplication; small.
2. **Escape LIKE values** (T5, the bug) - one line.
3. **Polymorphic `#export_attributes`/`#subtitle` on subclasses** (T1) - retires
   the exporter and helper type switches.
4. **`SortCatalogue` registry + one owner for `custom-N`** (T2) - inverts the
   dependency.
5. **Extract `SortPreferences` + `ProfileVisibility` from `User`** (T4) - the
   structural one; do it last, it lands the rest.
