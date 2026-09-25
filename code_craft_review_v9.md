# Code-craft review (v9)

**Lens:** code craft (Metz, Fowler, GoF, Pragmatic Programmer / Code Complete,
reliability, performance). **Scope:** the whole `app/` tree plus `db/schema.rb`
and `config/routes.rb`; correctness and security run as separate passes over the
query layer. **Depth:** exhaustive (the low-severity tail is reported).
**Execution:** inline single pass, with the rigour apparatus in
`code_craft_review_v9.coverage.md` (coverage matrix, per-dimension search
commands, responsibility census, credits ledger, self-grill).

Tests are out of scope by request (prototype branch). Coverage: 37 Ruby/behaviour
files and every template swept for view-triggered I/O and type switches.

This is a genuinely well-built prototype. The query DSL, the STI model, the
pagination object and the theming are thoughtful, and much of the code is small,
named for intent, and cohesive. The findings below are concentrated in a few
places, and the top three themes account for most of them.

---

## Themes (by symptom, swept across the whole scope)

### T1. Collectible type knowledge is scattered, not polymorphic (highest leverage)

The single biggest structural theme. The knowledge of "what is different about a
video game vs a board game vs a book" is spread across four files as explicit
type switches, when the STI subclasses already exist to own it. This is Fowler's
**Switch Statements** smell and Metz's **duck-typing / "ask what it does, not
what it is"**, repeated (Shotgun Surgery risk: adding a 4th type means editing
all of these):

- `app/helpers/collectibles_helper.rb:38-47` - `collectible_subtitle` is a
  `case collectible; when VideoGame … when BoardGame … when Book`.
- `app/services/collectible_exporter.rb:64-86` - `type_specific` is the same
  `case … when VideoGame/BoardGame/Book`.
- `app/views/collectibles/_form.html.erb:25-65` - `if @collectible.is_a?(VideoGame)
  … elsif BoardGame … elsif Book`, plus `unless Book` for multiplayer.
- `app/views/collectibles/_import_fields.html.erb:18-69` - the same per-type
  field ladder again, in parallel with `_form`.

The subclasses already model the differences declaratively (`applicable_fields`,
`applicable_link_keys`, `BoardGame#player_count`, `VideoGame#multiplayer?`), so
the fix is **Replace Conditional with Polymorphism** (Fowler) / **Tell, Don't
Ask** (Metz): give each subclass a `subtitle`, an `export_attributes` hash, and
a declaration of its form fields, and let the callers iterate that instead of
branching on class. `_form` and `_import_fields` are near-duplicate ladders
(Fowler **Duplicated Code**), so this also collapses two templates toward one
field-list driven partial.

### T2. The collectible "roster" and its type aliases are restated in many places

Fowler **Data Clumps** / Pragmatic **DRY** (knowledge, not text). The set of
collectible attributes and the type-alias mapping each live in several files
that must change together:

- `TYPE_ALIASES` is defined **twice** with slightly different contents -
  `app/queries/collectible_search.rb:87` and
  `app/services/collectible_importer.rb:14`. `CollectionSearch` correctly reuses
  `CollectibleSearch::TYPE_ALIASES` (`collection_search.rb:135`), so the importer
  is the odd one out; the two copies can drift.
- The attribute roster (`system, author, min/max_players, completed, evergreen,
  local/online_multiplayer, cooperative, competitive, notes, label_ids`) is
  restated as: strong-params in `collectibles_controller.rb:133-142` and
  `:193-200`, the CSV header list and export bodies in
  `collectible_exporter.rb:6-10,20-37`, `KEY_MAP` + `BOOLEAN_ATTRS` in
  `collectible_importer.rb:21-30`, and the two form ladders (T1). Ten-plus files
  reference these names (census in the sidecar). There is no single authoritative
  list, so export, import, params and forms drift independently.

### T3. Sort vocabulary is a shared secret across four layers (inverted dependency)

`CollectibleSearch` owns not just query filtering but the whole **sort
configuration** - `SORTS`, `DEFAULT_OPTIONS`, `SORT_FIELDS`, `DIRECTIONS`,
`custom_order`, `default_option` (`collectible_search.rb:31-85`). The model layer
then reaches **up** into the query layer to use it:

- `app/models/user.rb:48,65,69,117,123` and
  `app/models/custom_sort.rb:19,30,50,51,71` both depend on
  `CollectibleSearch::*` constants and class methods.
- The stringly-typed `"custom-N"` key (SOLID **connascence of meaning /
  algorithm**) is produced in `custom_sort.rb:15`, validated by regex in
  `user.rb:117`, and consumed as hash keys in `collectible_search.rb`.

A model depending on a query object is a **dependency-direction inversion**
(SOLID Dependency Inversion): the more stable layer (domain model) should not
depend on the less stable one (a query/presentation object). The sort vocabulary
is really a piece of **domain configuration** that both layers need; it wants to
live in a neutral place (a `Sortable`/`CollectibleSort` config module or a value
object) that both the model and the query depend on, rather than the model
depending on the query.

### T4. View-triggered N+1 queries (four sites)

Performance-as-design (`performance.md`): I/O hidden in templates. Each defeats or
skips an eager load. Ordered by blast radius:

- **`app/views/collectibles/_collectible.html.erb:24`** (and the identical
  `collectibles/show.html.erb:36`): `collectible.labels.ordered.each`. The
  controller eager-loads (`profiles_controller.rb:35`,
  `@search.results.includes(:labels)`), but `.ordered` is a **scope on an
  already-loaded association**, which issues a fresh `ORDER BY name` query per
  card - so the `includes` is silently defeated and the cards view fires one
  extra query per collectible (up to 15 per page). This is the canonical
  eager-load trap. Fix: sort in Ruby on the loaded set
  (`collectible.labels.sort_by { it.name.downcase }`).
- **`app/views/profiles/_profile_row.html.erb:12`** ->
  `collectibles_helper.rb:5` `collectible_counts`: one
  `collectibles.group(:type).count` per collection row. Rendered on
  `collections/index` (up to 15 rows) and three lists on `root/index`. Fix: a
  single grouped count keyed by `user_id`, or a counter-cache per type.
- **`app/views/settings/labels/index.html.erb:40`**: `label.collectibles.size`
  per label (`@labels` loaded without counts). Fix: `.left_joins(:collectibles)
  .group(:id).select("labels.*, COUNT(...)")` or a counter cache.
- **`app/views/collectibles/_import_fields.html.erb:72`**:
  `current_user.labels.ordered` re-runs for **every** imported item on the review
  page (import 50 -> 50 label queries). Fix: load the user's labels once in the
  controller and pass them in.

### T5. Fat / God units (three, all High)

Surfaced by the responsibility census, not by line count (see the subject grid).
`User`, `CollectibleSearch`, and `CollectiblesController` each carry 3+
app-authored responsibilities. Detailed under Findings.

### T6. Small duplications worth a mention

- **Applicable-label filtering** (`current_user.labels…select { applies_to_type? }`)
  appears three times: `collectibles_controller.rb:189`, `_form.html.erb:67`,
  `_import_fields.html.erb:72`. Extract `User#labels_for_type(type)` (or a scope).
- **shown/hidden complement** ("checkboxes list what to show; store the
  complement as hidden") is written twice: `settings_controller.rb:27-28` (link
  keys) and `settings/sorting_controller.rb:12-13` (default sorts). Same idea,
  two hand-rolled copies.

---

## Findings (ranked)

### High

**CC-1. `User` is a God Class (SOLID SRP / Fowler Divergent Change).**
`app/models/user.rb` (145 lines). Responsibility census (sidecar): identity &
username generation (`assign_username`, `to_param`, `name`), the social graph
(`follows_*`, `following?`), authorization/visibility (`visible_to_viewer`,
`visible_to?`, `allowlisted_viewers`, share links), external-link preferences
(`visible_link_keys`), sort preferences (`sort_options`, `custom_sort_orders`,
three sort/link validations), and view/theme preferences. That is five-plus
app-authored axes - you cannot describe it in one sentence without "and", which
is Metz's and Riel's God-Class test, so it rates High regardless of length.
Extract at least the visibility/authorization concern (a policy object) and the
preferences concern (link + sort + view/theme), leaving `User` as identity + the
social graph.

**CC-2. `CollectibleSearch` mixes query filtering with sort configuration
(Divergent Change + Large Class).** `app/queries/collectible_search.rb` (248
lines - over Metz's 100, and the largest file in the app). It changes for two
unrelated reasons: the query grammar (`apply`, the `match_*` methods) and the
sort catalogue (`SORTS`/`DEFAULT_OPTIONS`/`SORT_FIELDS`/`custom_order`). The sort
half is also the shared secret of theme T3. Extract the sort configuration into
its own object; both the query and the model/`CustomSort` then depend on that,
which simultaneously fixes the T3 inverted dependency.

**CC-3. `CollectiblesController` is a fat controller (Metz rule 4 / Divergent
Change).** `app/controllers/collectibles_controller.rb` (201 lines, 23 methods).
It carries standard CRUD **and** the entire three-step bulk-import flow
(`import`, `import_template`, `import_review`, `import_create` plus
`import_format`, `infer_format`, `import_content`, `import_items_params`) **and**
STI construction/label filtering (`build_collectible`, `requested_type`,
`applicable_label_ids`). The import flow is a separate resource's worth of
behaviour and its own axis of change; extract it to a dedicated
`Collectibles::ImportsController` (routes already group these under a
`collection` block). This is the highest-leverage controller fix.

### Medium

**CC-4. Dependency-direction inversion: models depend on the query layer.** See
theme T3. `app/models/user.rb` and `app/models/custom_sort.rb` reach up into
`CollectibleSearch`/`CollectionSearch` constants. Resolve by relocating the sort
vocabulary to a neutral domain module (bundles with CC-2).

**CC-5. Repeated type switch instead of polymorphism.** See theme T1
(`collectibles_helper.rb:38`, `collectible_exporter.rb:64`, `_form.html.erb:25`,
`_import_fields.html.erb:18`). Replace Conditional with Polymorphism; push the
per-type knowledge onto the STI subclasses that already exist.

**CC-6. `Collectible` carries a separable external-link catalogue (Divergent
Change).** `app/models/collectible.rb:5-16,96-104`. `LINK_DEFINITIONS` plus
`search_links` (URL templating, `CGI.escape`, formatting, sorting) is a distinct
responsibility from the STI type system and field validation - the class changes
when the link catalogue changes and when the type rules change. Extract a small
`SearchLinks`/`LinkCatalogue` collaborator. Medium (the class is otherwise
coherent at 105 lines).

**CC-7. Duplicated `TYPE_ALIASES` and the attribute roster.** Theme T2. The two
`TYPE_ALIASES` copies can drift; the roster has no authoritative home. Consolidate
the aliases (have the importer reuse the canonical map) and drive export/import/
params/forms from one field descriptor list.

**CC-8. `ProfilesController#show` is a long, many-variable action.**
`app/controllers/profiles_controller.rb:4-53` (one action, ~9 instance variables,
visibility gate + preference-remembering + search setup + 3-format `respond_to`).
Cohesive (one collection view) so not a God object, but past Metz's controller
guidance. Extract the preference-remembering and the export responses; consider a
small view/query builder so the action reads as orchestration.

### Low

**CC-9. Applicable-label filtering duplicated three times.** Theme T6. Extract
`User#labels_for_type`.

**CC-10. shown/hidden complement logic duplicated.** Theme T6
(`settings_controller.rb:27`, `sorting_controller.rb:12`). Extract a shared
helper (e.g. `complement_of(shown, all)`), or model the preference as "shown"
directly.

**CC-11. Unescaped `LIKE` wildcards (correctness, not injection).**
`app/queries/query_search.rb:45-67` and `collectible_search.rb:226`. Queries are
correctly `?`-parameterised (no SQL injection - credit), but `%` and `_` in the
user's value are not escaped, so `notes:50%` or `title:a_c` over-match. Escape
the wildcards before building the `LIKE` pattern. (This is the classic
"injection-safe yet still wrong" case.) Note the "case-insensitive" help text
holds on the SQLite adapter in use, but `LIKE` would become case-sensitive on
PostgreSQL - worth an `ILIKE`/`LOWER()` abstraction if the store may change.

**CC-12. `count_order` safety depends on an out-of-band allowlist.**
`app/queries/collection_search.rb:67-73` inlines `type` into SQL. It is safe
today because `resolve_count_type` only ever returns an allowlisted value, but
the method itself trusts its caller (SOLID: safety by connascence, not by the
method's own contract). A guard/assertion inside `count_order`, or building it
from a symbol keyed into a fixed map, makes the safety local.

**CC-13. `only_applicable_fields_set` reopens visibility with `public`/`private`
bracketing.** `app/models/collectible.rb:80-92` closes `private`, then re-opens
`public` for `search_links`, an unusual shape that is easy to trip over in later
edits. Reorder so the one public method sits with the others; keep the private
validation grouped with the private section.

---

## Subject grid (by hotspot - within one file, different problems)

Only subjects touched by 2+ distinct dimensions are listed; the convergence gate
(3+ dimensions -> its own High finding) is applied.

| Subject | Dimensions (distinct) | Verdict |
|---|---|---|
| `User` | God-class (SRP), dependency direction, connascence (`custom-N`, sort keys) | **3 -> High (CC-1)** |
| `CollectibleSearch` | Large Class, Divergent Change, connascence hub, inverted-dependency target | **4 -> High (CC-2)** |
| `CollectiblesController` | fat controller, duplication (label ids), STI type logic | **3 -> High (CC-3)** |
| `_collectible` / `profiles/show` | N+1 (labels.ordered), type switch (via helpers) | 2 -> Medium (CC-1 view / CC-5) |
| `collectible_exporter` | type switch, roster duplication | 2 -> Medium (CC-5 / CC-7) |
| `collectible_importer` | alias duplication, roster duplication | 2 -> Medium (CC-7) |
| `Collectible` | link-catalogue Divergent Change, connascence (roster) | 2 -> Medium (CC-6) |

Interpretation of the three High convergences is in the findings; each names its
responsibilities rather than resting on a count.

---

## Leverage-ordered fix list (by findings dissolved, not by cost)

1. **Extract a sort-configuration object out of `CollectibleSearch`** (moderate).
   Dissolves CC-2, CC-4, and the `custom-N`/sort-key connascence in CC-1/T3 - one
   move fixes the largest class, the inverted dependency, and a connascence hub.
2. **Push per-type knowledge onto the STI subclasses** (moderate). Dissolves CC-5
   and the `_form`/`_import_fields` duplication, and shrinks the exporter and
   helper. The single highest-leverage *readability* change.
3. **Extract `Collectibles::ImportsController`** (moderate). Dissolves the fat
   half of CC-3 and moves four of the import helpers with it.
4. **Fix the four view N+1s** (small, mechanical, independent). Dissolves T4/CC
   performance items; do the `labels.ordered` one first (widest blast radius).
5. **Introduce one authoritative field/alias descriptor** (moderate). Dissolves
   CC-7 and the T2 roster spread across export/import/params/forms.
6. **Extract a visibility/authorization policy + a preferences object from `User`**
   (larger). Finishes CC-1 after step 1 has removed the sort coupling.
7. **Small independent wins** (tiny each): `User#labels_for_type` (CC-9),
   shared complement helper (CC-10), escape `LIKE` wildcards (CC-11), guard
   `count_order` (CC-12), tidy `Collectible` visibility bracketing (CC-13).

---

## What already works (credits, falsified - see the ledger)

- **The query DSL is cleanly layered.** `QuerySearch` + `Parser` own the grammar
  and boolean AST once; `CollectibleSearch`/`CollectionSearch` supply only the
  token mapping. `CollectionSearch` correctly reuses `CollectibleSearch`'s
  aliases. Good use of a Template-Method-ish base (GoF), and the parser is small
  and single-purpose.
- **Raw SQL is injection-safe.** Verified across every interpolation site:
  operators are a fixed set, numbers are `.to_i`-cast, types/columns come from
  fixed maps, and `LIKE` is `?`-parameterised. (Only the wildcard-escaping nuance
  of CC-11 remains.)
- **`follow` is idempotent** (`find_or_create_by` + the unique
  `(follower_id, followed_id)` index), and **import is atomic**
  (`Collectible.transaction`). Reliability mechanisms are matched to real failure
  modes, not over-applied.
- **The following/shared decoration avoids an N+1**: `application_helper`
  memoises both id sets once per request (a deliberate, correct fix - credit
  scoped to that decoration; the counts on the same row are the separate CC-2).
- **`Pagination` is a tidy, well-named plain object** with a genuinely nice
  `series` method; **STI is modelled correctly** (snake_case `sti_name`, a
  guarded `model_for`); the schema has the right unique indexes and foreign keys.
