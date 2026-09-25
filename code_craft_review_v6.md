# Code craft review (v6)

A whole-codebase review through the code-craft lens (Metz, Fowler, GoF,
Pragmatic Programmer / Code Complete, connascence). Ranked by severity, with a
theme view, a subject/hotspot grid, and a leverage-ordered fix list.

## Scope

In scope — every Ruby file under `app/`, plus `config/routes.rb`, `db/schema.rb`
and `config/initializers/content_security_policy.rb` read for context:

- Models: `application_record`, `user`, `collectible`, `video_game`,
  `board_game`, `book`, `collectible_label`, `label`, `custom_sort`, `follow`,
  `profile_access`, `share_link`, `pagination`.
- Queries: `query_search`, `query_search/parser`, `collectible_search`,
  `collection_search`.
- Services: `collectible_exporter`, `collectible_importer`.
- Controllers: `application`, `collectibles`, `collections`, `profiles`,
  `follows`, `root`, `settings`, `settings/*` (5), `two_factor_authentication/*`
  (2), `users/sessions`.
- Helpers: `application_helper`, `collectibles_helper`, `root_helper`.
- Views are in scope for the queries and domain logic that live in them (per the
  reviewing protocol: scope by lens, not file type). Markup/accessibility is the
  ui-craft report's job.

Out of scope / not covered: tests (per your instruction — this is the prototype
branch); Devise-generated views; JS (none of substance); the CSS (ui-craft
report); a full security audit (I ran a correctness and a security pass over the
search/SQL code specifically, noted below, but did not pen-test the auth flows).

Passes run: smells (Fowler), sizing + cohesion (Metz), SOLID + connascence +
dependency direction, duplication across files, design-level performance
(query patterns / N+1), reliability, and a separate correctness-vs-security pass
over the raw-SQL search code.

## Severity-ranked findings

### High

**H1. `User` is a God Object (Divergent Change / SRP).** `app/models/user.rb`
Describe it in one sentence and you need several "and"s: it is the auth identity
(Devise), *and* the store of view/sort/link/theme preferences
(`sort_options`, `custom_sort_orders`, `visible_link_keys`,
`collectibles_sort_is_known`, `hidden_default_sorts_are_known`,
`hidden_link_keys_are_known`), *and* the visibility/access policy
(`visible_to?`, `self.visible_to_viewer`), *and* the following relationship,
*and* username generation (`assign_username`). It converges findings from three
different dimensions (cohesion, dependency direction H2, duplication M4), which
per the reviewing protocol is itself the God-Object signal regardless of the
145-line length. Every future change to preferences, access rules, or following
touches the same file for unrelated reasons.
Cure: extract a preferences value object (sorts + hidden links + theme + view)
and a visibility/access policy object (`visible_to?`, `visible_to_viewer`,
`allowlisted_viewers`); leave identity/auth on `User`. Metz "extract a
collaborator with its own responsibility".

**H2. Type switches that beg for polymorphism, repeated in four places
(Fowler: Switch Statements; Open/Closed).** The same `case`/`is_a?` on
collectible subclass appears in:
- `app/services/collectible_exporter.rb:64` `type_specific` (`when VideoGame … BoardGame … Book`)
- `app/helpers/collectibles_helper.rb:37` `collectible_subtitle` (`when VideoGame …`)
- `app/views/collectibles/_form.html.erb:25` (`is_a?(VideoGame)/BoardGame/Book`)
- `app/views/collectibles/_import_fields.html.erb:18` (same switch again)

The subclasses already exist and already answer type questions politely
(`applicable_fields`, `applicable_link_keys`, `player_count`, `multiplayer?`).
These four sites are the same idea done the wrong way: asking the object what it
*is* instead of telling it to answer. Adding a fourth collectible type today
means editing all four switches (Shotgun Surgery), and it is easy to update
three and miss one.
Cure: Replace Conditional with Polymorphism. Give `Collectible` subclasses
methods like `export_attributes`, `subtitle`, and a description of their form
fields (or a small presenter per type). This is the single highest-leverage
structural change in the report.

**H3. `CollectibleSearch` is a Large Class and a dependency hub
(Metz 100-line rule; dependency direction; Divergent Change).**
`app/queries/collectible_search.rb` is 248 lines and carries two distinct
responsibilities: (a) the *sort catalogue* — `SORTS`, `DEFAULT_OPTIONS`,
`SORT_FIELDS`, `DIRECTIONS`, `custom_order`, `default_option`; and (b) the
*query-to-SQL translation* — `apply` and the `match_*`/`player_bounds` family.
The sort catalogue is domain configuration that other layers reach up into:
`User` (`sort_options`, `custom_sort_orders`, `collectibles_sort_is_known`),
`CustomSort` (`order_clause`, `summary`, four validators), `ProfilesController`,
and two views all depend on `CollectibleSearch` constants. A model depending
*upward* on a query object is an inverted dependency (SOLID D). Splitting the
sort catalogue into its own neutral object (e.g. `CollectibleSort` /
`SortCatalogue`) would let `User` and `CustomSort` depend on it without dragging
in the whole search engine, and would pull the class back under 100 lines.

### Medium

**M1. View-triggered N+1: `.ordered` defeats `includes(:labels)`
(performance).** `app/controllers/profiles_controller.rb:35` eager-loads with
`@search.results.includes(:labels)`, but the card partial then calls
`collectible.labels.ordered` (`app/views/collectibles/_collectible.html.erb:24`,
also `show.html.erb:36`). `.ordered` (`scope :ordered, -> { order(:name) }`)
returns a *new* relation with an `ORDER BY`, which the preloaded association
cannot satisfy, so ActiveRecord re-queries the labels once per card — the exact
"an ordering scope inside a per-row template silently defeats the controller's
`includes`" case from the performance reference. `.any?` on line 22 uses the
loaded set (fine); only `.ordered` re-queries.
Cure: order in Ruby against the preloaded set — `collectible.labels.sort_by { it.name.downcase }` — or preload an already-ordered association.

**M2. Second N+1: per-row grouped count on collection lists.**
`app/helpers/collectibles_helper.rb:5` `collectible_counts` runs
`user.collectibles.group(:type).count` once per profile row. Rendered for every
row of the collections index and the homepage lists (up to 15 per page), that is
15 grouped-count queries per page. The relationship helpers next to it
(`followed_collection_ids`, `shared_collection_ids`) are correctly memoised into
sets to avoid exactly this (credit) — the counts weren't.
Cure: one grouped query keyed by `user_id` for the whole page
(`Collectible.where(user_id: ids).group(:user_id, :type).count`), looked up per
row.

**M3. `CollectiblesController` mixes CRUD and a three-step import
(Divergent Change; Metz thin-controller / fat-controller).**
`app/controllers/collectibles_controller.rb` (201 lines) holds standard CRUD
*and* the whole bulk-import pipeline (`import`, `import_template`,
`import_review`, `import_create`, plus `import_format`, `infer_format`,
`import_content`, `import_items_params`). Import and CRUD change for different
reasons. The other multi-step settings features each got their own namespaced
controller (`Settings::CustomSortsController` etc.) — import is the outlier.
Cure: extract `Collectibles::ImportsController` (or a `CollectibleImport` use-case
object) mirroring the `Settings::` pattern already established.

**M4. Duplicated knowledge (Pragmatic Programmer: DRY).** Several pieces of
knowledge have two authoritative copies that can drift:
- `TYPE_ALIASES` in `collectible_search.rb:87` and `collectible_importer.rb:14`
  are near-identical maps; `collection_search.rb:135` reaches into
  `CollectibleSearch::TYPE_ALIASES` for a third consumer. One canonical alias map
  on `Collectible` would serve all three.
- The "store the complement of what's shown" rule is written twice:
  `settings_controller.rb:27` (`hidden_link_keys = LINK_KEYS - shown`) and
  `settings/sorting_controller.rb:13` (`hidden_default_sorts = keys - shown`).
- The `[label, key]` remapping of `DEFAULT_OPTIONS` appears in
  `profiles_controller.rb:30`, `_search_form.html.erb:2`, and (built by hand)
  `user.rb:64`.
- The "persist a whitelisted preference with `update_columns`, skipping
  validation and timestamps" move is duplicated in
  `collections_controller.rb:24` and `profiles_controller.rb:60`.

**M5. Connascence of meaning/algorithm on the `"custom-N"` key, spread across
four files.** The string format `"custom-#{id}"` is agreed by convention in
`custom_sort.rb:15` (`key`), `user.rb:117` (the `/\Acustom-\d+\z/` regex in
`collectibles_sort_is_known`), `user.rb:73` (`custom_sort_orders` builds the
map), and `collectible_search.rb:114` (`valid_sort?` checks membership).
Connascence of meaning worsens with distance, and this is spread across the
model, the sort model, and the query object. If the format ever changes, all
four must change together with nothing enforcing it.
Cure: centralise parse/format in one place (`CustomSort.key_for(id)` /
`CustomSort.id_from_key(key)`), and have the others call it.

### Low

**L1. LIKE metacharacters are not escaped — a correctness bug, not a security
one.** `query_search.rb:45,58` build `"%#{value}%"` and bind it as a parameter
(so it is injection-*safe* — good). But `%` and `_` inside the user's value are
still treated as SQL `LIKE` wildcards. Searching `title:100%` or
`notes:"a_b"` silently matches more than the literal text. This is precisely the
"parameterised yet still wrong" case the reviewing protocol calls out for a
separate correctness pass.
Cure: escape `%`, `_` (and the escape char) in the value and add `ESCAPE`.

**L2. Feature Envy in the exporter/helpers.**
`CollectibleExporter#type_specific` and `collectibles_helper#collectible_subtitle`
/ `#collectible_traits` reach across into a collectible's fields to make
type-based decisions the collectible could make itself. Folded into H2's
polymorphism fix.

**L3. Indifferent-access hack signals a representation smell.**
`collectible_search.rb:79` reads `entry["field"] || entry[:field]` because
criteria arrive sometimes string-keyed (from JSON columns) and sometimes
symbol-keyed (freshly built). That `||` is connascence of representation leaking
into the query object. Normalise criteria to one key type at the boundary
(parse, don't validate) so downstream code trusts it.

**L4. Content Security Policy is entirely commented out.**
`config/initializers/content_security_policy.rb` ships the generator default (all
commented), yet the layout emits `csp_meta_tag`. No policy is enforced. Fine for
a prototype, but worth a hardening note — and the app uses an inline
`style="background-color: …"` on label tags (`collectibles_helper.rb:19`) and an
inline SVG, which a future `style-src`/`img-src` policy would need to
accommodate (nonce or refactor to CSS custom properties).

## Theme view (symptom axis)

1. **Type switches wanting polymorphism** — H2 (four sites), L2. The dominant
   structural theme; the subclasses exist but callers keep asking `is_a?`.
2. **`CollectibleSearch` as an over-loaded hub** — H3, and it is the thing M4's
   `TYPE_ALIASES` and M5's `custom-N` knowledge are scattered around. Splitting
   the sort catalogue out dissolves several couplings at once.
3. **Duplicated knowledge that can drift** — M4 (four instances), M5, L3.
4. **View-triggered database work** — M1 (ordered labels), M2 (per-row counts).
   Both invisible from a controller-only read; both live in the render path.
5. **Cohesion / responsibility overload** — H1 (`User`), M3 (`CollectiblesController`).

## Subject / hotspot grid (subject × dimension)

| Subject | Cohesion/SRP | Dependency dir. | Duplication | Perf (N+1) | Size (Metz) | Distinct dims |
|---|---|---|---|---|---|---|
| `User` | H1 | H2/H3 (depends up on search consts) | M4 (option map) | — | 145 lines (borderline) | **3 → High** |
| `CollectibleSearch` | H3 (sort cat + filtering) | H3 (hub others depend on) | M4 (TYPE_ALIASES), M5 | — | 248 lines | **4 → High** |
| `CollectiblesController` | M3 (CRUD + import) | — | — | — | 201 lines | 2 → Medium-High |
| `_collectible.html.erb` | — | — | H2 (type switch) | M1 (`.ordered`) | — | 2 → Medium |
| `collectibles_helper` | — | L2 (feature envy) | — | M2 (counts) | — | 2 → Medium |
| `collectible_exporter` | — | L2 | H2 (type switch) | — | — | 2 → Medium |

Reading the grid: the two High subjects are cohesion failures (many *different*
lenses converge), not merely long files. `CollectiblesController` at 201 lines is
long *and* carries two responsibilities — the length is a symptom, the CRUD+import
split is the finding.

## Leverage-ordered fix list

Ordered by how many findings each dissolves, not by cost.

1. **Push type behaviour onto the subclasses (H2, L2).** *Cost: medium.*
   Add polymorphic `export_attributes` / `subtitle` / form-field description to
   `VideoGame`/`BoardGame`/`Book`; delete the four switches. Dissolves H2 and L2
   and removes the Shotgun-Surgery cost of adding a future type. Highest leverage.
2. **Extract the sort catalogue out of `CollectibleSearch` (H3, and eases M4/M5).**
   *Cost: medium.* A neutral `CollectibleSort`/`SortCatalogue` that `User`,
   `CustomSort`, controllers and views depend on, inverting the current model→query
   dependency and pulling the class under 100 lines. Natural home for M5's
   `custom-N` parse/format.
3. **Extract preferences + access policy off `User` (H1).** *Cost: medium-high.*
   The structural anchor; do it after 1–2, which remove some of `User`'s reasons
   to reach into the search classes. "Do this last; it lands the rest."
4. **Fix the two view N+1s (M1, M2).** *Cost: low each.* Order labels in Ruby;
   batch the per-row counts into one grouped query.
5. **Move bulk import into its own controller (M3).** *Cost: low-medium.*
6. **De-duplicate the four knowledge copies (M4).** *Cost: low.*
7. **Escape LIKE metacharacters (L1); normalise criteria keys (L3); add a CSP
   (L4).** *Cost: low each.*

## What already works (credit)

- **`QuerySearch` / `Parser` split is genuinely good design.** The parser is a
  deep module (Ousterhout): a simple `call` over a substantial, schema-agnostic
  implementation, with a clean boolean-AST contract. The base/subclass split
  (Template Method with `apply` as the varying step) keeps the grammar in one
  place and is reused cleanly by both `CollectibleSearch` and `CollectionSearch`.
- **SQL safety.** Despite raw-SQL string building in the search classes, the
  correctness/security pass found the interpolations all use whitelisted literal
  column names (`min_players`/`max_players`), a fixed operator set, and
  integer-cast bounds (`numeric_bounds`, `player_bounds`); user values go through
  bound `?`/`:q` parameters. The `count_order`/`match_type_count` subqueries
  interpolate only fixed STI type strings. The code even comments *why* each is
  safe. (The one residual is L1, a correctness not a security issue.)
- **Authorization is careful and consistent.** `require_own_profile` +
  `set_owned_collectible` scope every mutating action to `current_user`'s own
  records; `applicable_label_ids` intersects submitted ids with the user's own
  labels so a label can't be attached across owners; `visible_to?` gates every
  read path.
- **Negation is NULL-safe throughout** the search (`match_like`, `match_players`,
  `match_player_field`) — a subtle correctness point handled deliberately and
  commented.
- **`Pagination` is a tidy plain object** with clear responsibilities and a
  nicely-commented `series` gap algorithm.
- **Reliability is matched to the risk:** `import_create` wraps the batch in a
  transaction; `follows#create` uses `find_or_create_by` against a unique index
  for idempotency; there are no external HTTP calls to need timeouts. No
  over-engineered retry/circuit-breaker machinery where it isn't warranted.
- **Comments explain the *why*** (the `collection_updated_at` touch rationale,
  `update_columns` skipping validation/timestamps, the overlap semantics of
  `players:`), which is what comments are for.

## Coverage gaps / caveats

- Tests were excluded by request; I have not assessed the existing spec suite's
  design or coverage.
- I did not exhaustively pen-test the Devise/2FA flows; the review of those
  controllers was structural (they read as conventional and correct).
- Performance findings are design-level (query patterns); I did not run a
  profiler or `bullet` — the N+1s are identified by reading the render path.
