# Code-craft review (whole codebase, `prototype` branch)

A review through the code-craft lens: Fowler's smells, Metz's OO sizing and dependency rules, SOLID and connascence, the Pragmatic Programmer / Code Complete construction principles, plus separate correctness and security passes. Tests are out of scope by request (prototype), so "no tests" is never raised below.

This is a strong codebase. The query/search layer is genuinely well designed, access control is scoped consistently, and the comments explain *why* rather than *what*. The findings below are mostly about duplication and one or two classes quietly accreting responsibilities, not about brokenness.

## Scope and coverage

Reviewed in full:

- **Controllers (13):** `application`, `collectibles`, `collections`, `profiles`, `follows`, `root`, `settings`, `settings/{custom_sorts,labels,profile_accesses,share_links,sorting,visibility}`, `two_factor_authentication/{sessions,setup}`, `users/sessions`.
- **Models (13):** `application_record`, `collectible`, `board_game`, `book`, `video_game`, `label`, `collectible_label`, `custom_sort`, `follow`, `profile_access`, `share_link`, `user`, `pagination`.
- **Queries (4):** `query_search`, `query_search/parser`, `collectible_search`, `collection_search`.
- **Services (2):** `collectible_importer`, `collectible_exporter`.
- **Helpers (3):** `application_helper`, `collectibles_helper`, `root_helper`.
- **Config:** `routes.rb`. Skimmed `database.yml` (SQLite) and the `_profile_row`/`_collection_list` views only to confirm an N+1.

**Not reviewed** (out of scope): views/ERB (that is the ui-craft pass), migrations, initializers beyond routing, `db/seeds.rb`, JS, CSS, generated Devise/PWA files.

**Correctness and security** were run as separate passes over the queries, controllers, and importer.

---

## Theme 1: Duplicated domain knowledge across files (DRY / connascence)

The single most repeated shape in the codebase. Each instance is individually small; together they are the highest-leverage cluster because a change to the underlying rule now needs edits in several places.

### High — `TYPE_ALIASES` is defined twice and has already drifted
`app/queries/collectible_search.rb:87` and `app/services/collectible_importer.rb:14`. Two authoritative copies of "how a type word maps to an STI type". `CollectionSearch` reaches across to `CollectibleSearch::TYPE_ALIASES` (`collection_search.rb:135`) yet the importer keeps its *own* copy. They already differ in surface (the importer inlines the alias list; the search omits `"videogame"` vs includes it differently). This is Fowler's Duplicated Code plus connascence of meaning across a module boundary. **Fix:** make one the authority (e.g. `Collectible::TYPE_ALIASES`, since the model already owns `TYPES` and `model_for`) and have both callers use it.

### Medium — the id-subquery negation pattern is written five times
`match_label` (`collectible_search.rb:225-228`), and in `collection_search.rb`: `apply_flag` (99-110), `match_has_type` (113-119), `match_type_count` (123-131). Every one ends with the identical `negated ? scope.where.not(id: matching) : scope.where(id: matching)`. **Fix:** pull one helper up into `QuerySearch`, e.g. `def match_subset(scope, matching, negated) = negated ? scope.where.not(id: matching) : scope.where(id: matching)`. Removes four duplicates and names the idea.

### Medium — the NULL-safe numeric-bounds clause builder is written four times
`match_players` (`collectible_search.rb:170-182`), `match_player_field` (187-198), and `match_type_count`'s HAVING (`collection_search.rb:128`) all build `bounds.map { … }.join(" AND " / " OR ")` with the same "negated ⇒ `col IS NULL OR NOT(...)` joined by OR, else joined by AND" logic. **Fix:** extract a `numeric_clause(column_expressions, negated)` helper in `QuerySearch` beside `numeric_bounds`. This is Fowler's Extract Function against a Data Clump of (columns, ops, values, negated).

### Medium — "shown minus complement = hidden" logic duplicated in two controllers
`SettingsController#settings_params` (`settings_controller.rb:27-28`) and `Settings::SortingController#update` (`sorting_controller.rb:12-13`) both compute `CANONICAL - (submitted & CANONICAL)` to store a hidden set. Same decision, two representations. **Fix:** a small helper (`hidden_complement(submitted, canonical:)`) or push the "show/hide" inversion onto the `User` model, which already owns `hidden_link_keys`/`hidden_default_sorts`.

### Low — visibility/"who is shared with me" knowledge is spread
`User.visible_to_viewer` (`user.rb:89-95`), `CollectionSearch#shared_owner_ids` (`collection_search.rb:150-154`), `RootController#index`'s `@shared`/`@followed` (`root_controller.rb:26-32`), and `ApplicationHelper#shared_collection_ids` (`application_helper.rb:18-23`) each re-derive some slice of the sharing/following graph. Not wrong, but the sharing rule lives in four places. **Fix:** consolidate the "collections shared with viewer" and "collections viewer follows" relations as named scopes/methods on `User` and have the others compose them.

---

## Theme 2: Classes accreting responsibilities (Divergent Change / God Class)

Surfaced by the subject-pivot (see the grid below), not by line count alone.

### High — `User` is a God Class (Divergent Change)
`app/models/user.rb` (~145 LOC). Describe it without "and": it handles **authentication** (Devise + OTP), **preferences** (themes, link visibility, sort options, custom-sort orders), **authorization/visibility** (`visible_to_viewer`, `visible_to?`), **the social graph** (following, allowlisted viewers), and **identity** (`assign_username`, `to_param`). That is five reasons to change. It also shows **Feature Envy** on the query layer: `sort_options` (64-70) and `custom_sort_orders` (73-75) know `CollectibleSearch::DEFAULT_OPTIONS` internals and the `[label, key]` pair shape. Rated High by convergence of dimensions (sizing + Divergent Change + Feature Envy + connascence), per Riel's God Class / Fowler's Divergent Change. **Fix (incremental, not a rewrite):** extract a `CollectionVisibility` policy object for `visible_to?`/`visible_to_viewer`, and a `SortPreferences`/`LinkPreferences` collaborator for the sort/link option assembly. Do it opportunistically the next time you touch each area.

### Medium — `ProfilesController#show` is a fat controller (Metz rule 4 + Long Method)
`app/controllers/profiles_controller.rb:4-53`. ~40 lines, ~9 instance variables (`@user, @token, @owner, @view, @sort_options, @search, @link_keys, @pagination, @collectibles`), and it carries domain logic: resolving the effective view/sort from params-vs-remembered-vs-default (22-34) and persisting the preference (`remember_collection_preferences`). Metz rule 4 wants one object instantiated and views knowing one ivar; this is the clearest breach. **Fix:** extract a `CollectionView`/query object that takes `(owner, viewer, params)` and exposes `view`, `sort_options`, `results`; the controller then does auth + `respond_to` + pagination only.

### Medium — `CollectibleSearch` mixes token-mapping with sort configuration
`app/queries/collectible_search.rb` (~250 LOC). Two responsibilities that change for different reasons live together: the **sort catalogue** (`SORTS`, `DEFAULT_OPTIONS`, `SORT_FIELDS`, `DIRECTIONS`, `custom_order`, `default_option`) and the **query token mapping** (`apply` and its helpers). `CustomSort`, `User`, and `ProfilesController` all reach into the sort constants, so the sort catalogue has real external clients. **Fix:** extract a `CollectibleSort` (or `SortCatalogue`) value/module owning the sort constants and `custom_order`; `CollectibleSearch` keeps only querying. This also gives Theme 3's `custom-N` format one home.

---

## Theme 3: Type-based conditionals the object could answer (Switch Statements)

### Medium — STI type switch in the exporter
`CollectibleExporter#type_specific` (`collectible_exporter.rb:64-85`) is a `case collectible when VideoGame / BoardGame / Book`. This duplicates knowledge the subclasses already hold in `applicable_fields`. Fowler's Switch Statements → Replace Conditional with Polymorphism; Metz's duck typing. **Fix:** give each `Collectible` subclass an `export_attributes` (or reuse `applicable_fields`) so the exporter maps over `applicable_fields` without knowing concrete classes. Then adding a fourth type touches only the new subclass (Open/Closed).

### Medium — type switch in `collectible_subtitle`
`CollectiblesHelper#collectible_subtitle` (`collectibles_helper.rb:37-47`) switches on the same three subclasses to build a one-line subtitle. **Fix:** a polymorphic `#subtitle` on each subclass (or a presenter method), leaving the helper to call `collectible.subtitle`. Lower priority than the exporter because it is pure presentation, but it is the same smell in a second place, so worth noting as a pair.

*(Credit: the parallel switch is **not** everywhere — `applicable_link_keys` and `applicable_fields` are already correctly polymorphic on the subclasses. These two are the stragglers.)*

---

## Theme 4: Stringly-typed conventions coupled across files (connascence of meaning)

### Medium — the `"custom-N"` sort key is agreed by convention in four places
`CustomSort#key` produces it (`custom_sort.rb:14-16`); `User#collectibles_sort_is_known` validates `/\Acustom-\d+\z/` (`user.rb:117`); `CollectibleSearch` keys `@custom_sorts` by it and looks it up (`collectible_search.rb:114,118`); `ProfilesController#show` builds `valid_sorts` from `custom_orders.keys` (`profiles_controller.rb:23`). This is connascence of meaning/algorithm (the `custom-` prefix and integer suffix) spread across model, model-validation, query, and controller — connascence that worsens with distance. **Fix:** centralise construction and recognition (`CustomSort.key_for(id)` / `CustomSort.key?(string)`), ideally on the extracted sort catalogue from Theme 2, so no other file re-encodes the format.

---

## Theme 5: Domain logic leaking into the HTTP/view layer (Feature Envy)

### Medium — `applicable_label_ids` belongs on the domain, not the controller
`CollectiblesController#applicable_label_ids` (`collectibles_controller.rb:188-191`) filters submitted label ids down to those whose `Label#applies_to_type?` matches. It is a method more interested in `User`'s labels and `Label`'s applicability than in the controller (Feature Envy). It is also duplicated in intent between `update` (30-33) and `build_collectible` (180-182). **Fix:** move it to `User#label_ids_applicable_to(type, ids)` (or a `LabelSelection` object). The controller then just forwards params.

### Low — `collectible_counts` runs a query from a helper
`CollectiblesHelper#collectible_counts` (`collectibles_helper.rb:5-13`) issues SQL. View helpers issuing queries mixes layers and, here, causes the N+1 in Theme 6. **Fix:** move the count to a model/query method and, better, batch it (below).

---

## Theme 6: Performance

### Medium — N+1 grouped-count query on every collection list
`CollectiblesHelper#collectible_counts` is called once per row in `profiles/_profile_row` (`_profile_row.html.erb:12`), which renders for every collection in `collections#index` **and** the three homepage lists (`@recent`, `@followed`, `@shared`). Each row fires its own `SELECT type, COUNT(*) … GROUP BY type`. The method's own comment ("one grouped count query per user") is true per call but misleading across a list. This is Fowler's leaked-abstraction N+1. **Fix:** compute counts for the whole page in one query keyed by `user_id` (`Collectible.where(user_id: ids).group(:user_id, :type).count`) and pass the map into the partial. The follow/shared decorations were already de-N+1'd via memoised sets in `ApplicationHelper` — apply the same treatment here.

### Low — `assign_username` is a query-per-attempt loop with a check-then-act race
`user.rb:132-144` loops `User.exists?(username: candidate)`, one query per collision, and the check-then-insert has a TOCTOU race under concurrent signups. The `uniqueness` validation and (I'd assume) a DB unique index are the real guard, so the loop is belt-and-braces. **Fix:** acceptable for a prototype; if hardened, rescue the unique-violation and retry rather than pre-checking. Note it, don't block on it.

### Low — SQLite-specific SQL limits portability
`RootController#index` uses `Arel.sql("RANDOM()")` (`root_controller.rb:21`) and `CollectionSearch` combines `.distinct` with `ORDER BY lower(coalesce(...))` / a correlated count subquery (`collection_search.rb:47,60,67`). On SQLite (the configured adapter) this is fine. On PostgreSQL, `SELECT DISTINCT … ORDER BY <expr not in select list>` raises, and `RANDOM()` semantics differ. Flagging as a reversibility/portability note (Pragmatic Programmer), not a live bug, since the app is committed to SQLite.

---

## Theme 7: Correctness (separate pass)

### Medium — LIKE searches treat `%` and `_` as wildcards (metacharacters not literal)
`QuerySearch#match_like` / `#match_any_like` (`query_search.rb:45-67`) and `CollectibleSearch#match_label` (`collectible_search.rb:226`) build `"%#{value}%"` as a **bound parameter** — so this is injection-*safe* (see the security pass) but **incorrect** for user-entered metacharacters: searching `title:100%` or `notes:a_b` silently matches on the SQL wildcards rather than the literal characters. This is exactly the canonical "parameterised yet metacharacter-wrong" trap. **Fix:** escape `%`, `_` (and the escape char) in `value` and add `ESCAPE '\'` to the clause, in the two base helpers so every caller inherits it.

### Low — private-collection collectibles leak existence via 404-vs-403
`CollectiblesController#set_collectible` (`collectibles_controller.rb:146-157`) calls `@profile.collectibles.find(params[:id])` (raising `RecordNotFound` → 404 for a missing id) *before* the `visible_to?` check (which renders `private_profile` → 403). So for a private collection, an existing id returns 403 and a missing id returns 404, letting an unauthorised viewer probe which collectible ids exist. **Fix:** run the visibility check before the `find`, or rescue so both cases return an identical response.

### Low — user enumeration on the profile-access form
`Settings::ProfileAccessesController#create` (`profile_accesses_controller.rb:6-11`) returns "No user found with that email or username" for a miss and a success message naming the user for a hit, so the form confirms whether an email/username is registered. Low severity for this app class, but worth a conscious decision. **Fix:** if it matters, use a neutral confirmation regardless of match.

---

## Security pass (separate from correctness)

I specifically re-read every raw-SQL construction site asking "is this injectable?" — and the answer is consistently **no**. Recording it because the discipline is worth crediting:

- **Numeric filters** (`match_players`, `match_player_field`, `match_type_count`, `numeric_bounds`) inline only `column` (hardcoded literals), `op` (from the fixed regex set `>=|>|<=|<|=`), and integers via `.to_i`. Safe. Clearly commented as such.
- **`CollectionSearch#count_order`** (`collection_search.rb:67-73`) interpolates `#{type}` into raw SQL, but `type` is a value from the frozen `COUNT_SORTS` map, never user input. Safe, and the comment says so.
- **`match_like`/`match_any_like`** interpolate `column` (class-supplied literals) and bind `value` as a parameter. Safe.
- **`ProfileAccessesController`** uses `find_by("LOWER(email) = ? OR username = ?", …)` with bound params. Safe.
- **Mass assignment:** every controller uses `permit` allowlists, and the two "set" endpoints (`visibility#update`, sort/link toggles) intersect submitted values with a canonical frozen list before assigning. No `permit!`/`to_unsafe_h` reaching a model (`to_unsafe_h` in `custom_sorts_controller.rb:48` is read by known `SORT_FIELDS` keys only, then validated by `CustomSort`). Good.
- **Broken access control:** owner-scoped resources are consistently loaded via `current_user.association.find` (labels, custom_sorts, share_links, profile_accesses, collectibles for edit/update/destroy). Nested collectible mutations are gated by `require_own_profile` (username match). `FollowsController#followable?` re-checks `visible_to?`. No IDOR found. This is the strongest part of the codebase.
- **Token sharing:** `visible_to?` checks `share_links.active.exists?(token:)` with the token bound; tokens are `SecureRandom.urlsafe_base64(16)`. Sound.

The only security-adjacent items are the two Low information-disclosure findings in the correctness pass (404-vs-403, user enumeration).

---

## Subject × dimension grid (hotspot view)

Counting *distinct dimensions* per subject, not raw findings:

| Subject | Dup/DRY | Divergent Change | Feature Envy | Switch | Connascence | Perf | Correctness | Dims |
|---|---|---|---|---|---|---|---|---|
| **`User`** | · | ● | ● | · | ● (custom-N, SORTS) | ● (username loop) | · | **4 → High** |
| **`CollectibleSearch`** | ● (bounds) | ● (sort vs mapping) | · | · | ● (custom-N) | · | ● (LIKE) | **4 → High** |
| **`CollectionSearch`** | ● (id-subquery, bounds) | · | · | · | · | ● (distinct+order) | ● (LIKE) | 3 |
| **`ProfilesController`** | · | ● (fat controller) | ● (prefs logic) | · | ● (custom-N) | · | · | 3 |
| **`CollectibleExporter`** | · | · | · | ● | · | · | · | 1 |
| **`CollectiblesHelper`** | · | · | ● (counts query) | ● (subtitle) | · | ● (N+1) | · | 3 |

The two "4-dimension" subjects (`User`, `CollectibleSearch`) are the structural anchors: the convergence, not any single finding, is why they rate High.

## Leverage-ordered fix list (by findings dissolved, not by cost)

1. **Extract a sort catalogue** from `CollectibleSearch` (`CollectibleSort` module owning `SORTS`/`DEFAULT_OPTIONS`/`SORT_FIELDS`/`custom_order` and the `custom-N` format). *Larger.* Dissolves the `CollectibleSearch` Divergent Change, the `custom-N` connascence across four files, and part of `User`/`ProfilesController`'s Feature Envy. Do this one last; it lands the rest.
2. **Extract a `CollectionVisibility` policy + preferences collaborator** from `User`. *Larger.* Dissolves the God Class and the visibility-logic scatter (Theme 1 Low).
3. **Extract a `CollectionView` query object** behind `ProfilesController#show`. *Medium.* Dissolves the fat controller and moves `applicable_label_ids`/preferences out of HTTP.
4. **Single authority for `TYPE_ALIASES`** on `Collectible`. *Small.* Removes the drifted duplicate.
5. **Pull `match_subset` and `numeric_clause` up into `QuerySearch`.** *Small.* Removes five + four duplications.
6. **Batch the collection counts** into one query passed to `_profile_row`. *Small.* Kills the homepage/index N+1.
7. **Escape LIKE metacharacters + `ESCAPE`** in the two base helpers. *One-liner-ish.* Fixes the search-correctness bug everywhere at once.
8. **Reorder the visibility check before `find`** in `collectibles#show`. *One-liner.* Closes the 404/403 leak.

## What already works well (specific credit)

- **The `QuerySearch` AST design** (`query_search.rb` + `parser.rb`) is the highlight: a schema-agnostic parser producing a boolean tree, evaluated generically via id-subqueries so AND/OR/negation compose to arbitrary depth, with the model-specific mapping isolated in `#apply`. Textbook Template Method + Open/Closed, and the two subclasses prove the seam.
- **Consistent owner-scoping** for access control (`current_user.association.find` everywhere) — no IDOR surface.
- **Deliberate raw-SQL safety** with comments explaining *why* each interpolation is safe.
- **`collection_updated_at` via `touch:`** (`collectible.rb:34`) is a clean way to get a content-only recency signal that logins/settings don't disturb.
- **Comments explain intent, not mechanics** throughout — e.g. the overlap semantics of `players:` filtering, the NULL-safe negation reasoning. This is the good kind of comment.
- **`Pagination`** is a tidy, single-responsibility plain object with a genuinely nice `series` gap algorithm.
- **STI `applicable_fields`/`applicable_link_keys`** are already polymorphic (making the two remaining exporter/helper switches stand out as the exceptions, not the rule).

## Coverage gaps / caveats

- I did not run RuboCop/Reek/flog, so the Metz sizing calls are read by eye (the `User` and `CollectibleSearch` line counts are approximate; the *cohesion* judgment stands regardless of exact count).
- I did not confirm a DB unique index backs the `username`/`follow`/`profile_access` uniqueness validations (schema not read in full) — the `assign_username` race note assumes one exists as the real guard.
- ERB/CSS/JS deliberately left to the ui-craft pass; I touched `_profile_row` only to substantiate the N+1.
- Behaviour of the search evaluator under pathological deeply-nested queries (very long `OR` chains generating deep subquery nesting) was reasoned about, not benchmarked; fine for expected collection sizes.
