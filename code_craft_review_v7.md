# Code-craft review (v7)

**Lens:** code craft (Metz, Fowler, GoF, Pragmatic Programmer / Code Complete, reliability, performance).
**Scope:** whole `app/` (models, controllers, queries, services, helpers, views) plus `config/routes.rb` and `db/schema.rb`. Views are in scope for this lens where they trigger queries or carry domain logic.
**Excluded:** automated tests (prototype branch, at the user's instruction), generated Devise/Rails internals, `config/initializers`, dependencies.
**Depth:** exhaustive (the low-severity tail is reported).
**Execution:** inline single pass, with the craft-reviewing rigour apparatus (credits ledger, instance census, coverage attestation, self-grill).

This is a genuinely well-built prototype. The query DSL (`QuerySearch` base + `Parser` + two subclasses) is a clean Template-Method/Strategy split, STI is used correctly, access control is scoped through associations throughout, and the raw SQL is parameterised or whitelisted. The findings below are mostly about a few systematic patterns, not scattered defects.

---

## Themes (the across-files, same-problem view)

1. **Repeated Switch on collectible type** — the same `VideoGame` / `BoardGame` / `Book` branch appears in four files. The strongest structural theme.
2. **Behaviour in templates: view-triggered N+1 queries** — several partials fire queries per row, one of which silently defeats a controller `includes`.
3. **The domain layer depends upward on the query layer** — `User` and `CustomSort` (models) reach into `CollectibleSearch` / `CollectionSearch` (query objects) for constants and behaviour.
4. **Duplicated knowledge** — the "checkboxes list what to *show*, store the complement as hidden" rule, and the "options → `[label, key]`" mapping, each live in 2–3 places.
5. **Stringly-typed cross-file contracts** — the `"custom-N"` sort key and the export/import column roster are agreed by convention across several files (connascence of meaning/position).

---

## Findings

### High

**H1. Repeated Switch on collectible type (Fowler: Switch Statements; Metz: duck typing; Meyer: Open/Closed).**
The type triad is branched on in four places:
- `app/services/collectible_exporter.rb:65` — `case collectible when VideoGame … BoardGame … Book`
- `app/helpers/collectibles_helper.rb:38` (`collectible_subtitle`) — same `case`
- `app/views/collectibles/_form.html.erb:25,30,42,55,58` — `is_a?(VideoGame)` / `elsif …`
- `app/views/collectibles/_import_fields.html.erb:18,24,33,50,51` — the same ladder again

The `Collectible` hierarchy already answers type questions polymorphically (`applicable_fields`, `applicable_link_keys`, `player_count`, `multiplayer?`). These four sites re-ask "what type is this?" instead. Adding a fourth collectible type is Shotgun Surgery: you would edit at least these four files plus the model. Move the presentation each site needs onto the subclasses — e.g. `Collectible#subtitle` (overridden per subclass), `#export_attributes` returning the type-specific hash, and a small field-metadata method the two form partials render from. That turns each `case` into one polymorphic send and makes a new type a single new class (Open/Closed). Severity High because it is the one smell that spans the most files and directly taxes the app's core extension point.

**H2. View-triggered `.ordered` defeats the controller's eager load (N+1; Fowler: leaked abstraction; `performance.md`).**
`app/controllers/profiles_controller.rb:35` eager-loads labels: `@search.results.includes(:labels)`. But the card partial re-orders the association in the view:
- `app/views/collectibles/_collectible.html.erb:24` — `collectible.labels.ordered.each`
- `app/views/collectibles/show.html.erb:36` — same

`labels.any?` (line 22/34) correctly uses the loaded association, but `.ordered` applies an `ORDER BY` and issues a fresh query **per card**, silently undoing the `includes`. A Ruby-only reading of the controller passes the `includes` and never sees the `.ordered` that negates it — this is the canonical case in `performance.md`. Fix: order in the eager load (`includes(:labels)` + a default `order` on the association, or sort the already-loaded array in Ruby with `labels.sort_by(&:name)`), so no per-row query fires. Severity High: it's on the collection page's hot path (up to 15 cards/page) and is invisible without reading controller and template together.

### Medium

**M1. More view-layer N+1s (`performance.md`).**
- `app/views/settings/labels/index.html.erb:40` — `label.collectibles.size` runs a `COUNT` per label; `@labels` is loaded without a counter cache or `includes`. Use a counter cache (`collectibles_count`) or a grouped count loaded once in the controller.
- `app/views/profiles/_profile_row.html.erb:12` — `collectible_counts(profile)` (helper at `collectibles_helper.rb:5`) runs one grouped `COUNT` **per collection row**. On the collections index (15/page), the homepage, and the followed/shared lists this is N grouped queries. The helper comment ("One grouped count query per user") documents the per-row cost without resolving it. Batch it: one `group(:user_id, :type).count` for the whole page, passed into the partial.
- `app/views/settings/sorting/show.html.erb:30,32` — `@user.custom_sorts.ordered` is evaluated twice (`.any?` then `.each`), i.e. two queries; assign it once in the controller (or memoise).

**M2. Models depend upward on the query layer (Dependency Inversion; connascence across boundaries).**
`app/models/user.rb:48,65,69,73` and `app/models/custom_sort.rb:18,31,60,67` reference `CollectionSearch::SORTS`, `CollectibleSearch::SORTS` / `::DEFAULT_OPTIONS` / `::SORT_FIELDS` / `::DIRECTIONS` and call `CollectibleSearch.custom_order` / `.default_option`. A model (stable domain layer) depending on a query object (a higher, more volatile layer) is an inverted dependency: a change to the search DSL ripples into model validations. The sort/field vocabulary is really domain configuration — consider hoisting `SORT_FIELDS` / `SORTS` to a neutral home (a `Sorting` module or the `Collectible` model) that both the models and the query objects depend on, so the arrow points down. Severity Medium: it works today but couples the two layers tightly and is easy to trip over when editing either.

**M3. `CollectiblesController` has Divergent Change (Fowler; Metz: fat controller).**
`app/controllers/collectibles_controller.rb` (~200 lines) carries two unrelated reasons to change: single-item CRUD (`new`/`create`/`edit`/`update`/`destroy`) and the three-step bulk-import pipeline (`import`, `import_template`, `import_review`, `import_create`, plus `import_format`, `infer_format`, `import_content`, `import_items_params`). The import half is a self-contained flow with its own params and format inference. Extract a `Collectibles::ImportsController` (routes already namespace the import actions under the collection). That halves this class and lets each side change independently.

**M4. Stringly-typed `"custom-N"` sort key spread across files (connascence of meaning/algorithm).**
The format is produced in `app/models/custom_sort.rb:15` (`"custom-#{id}"`), validated by regex in `app/models/user.rb:117` (`/\Acustom-\d+\z/`), and consumed as a hash key in `app/queries/collectible_search.rb:114,118` and built into `custom_sort_orders` (`user.rb:73`). Four sites must agree on one undocumented string shape; connascence of meaning worsens with distance, and these are far apart. Give `CustomSort` a single `.key_for(id)` / `.parse_key` (or a small value object) so the shape is defined once. Severity Medium.

**M5. Export/import column roster is a positional/name contract between two services (connascence).**
`CollectibleExporter::CSV_HEADERS` (`collectible_exporter.rb:6`) and `CollectibleImporter::KEY_MAP` (`collectible_importer.rb:21`) must stay in lockstep for the documented round-trip, but neither references the other and the header strings are duplicated (as headers in one, as normalised keys in the other). Adding a column means editing both by hand with no failing signal if you forget. A shared field-definition list (name + attribute + type) that both derive from would make the round-trip structurally guaranteed. Severity Medium (it's the feature's whole promise).

### Low

**L1. Unescaped LIKE wildcards — parameterised but still wrong (`protocol.md`'s canonical correctness-vs-security split).**
`app/queries/query_search.rb:45,58` and `collectible_search.rb:226` build `"%#{value}%"` and bind it with `?`, so it is injection-safe — but `%` and `_` inside `value` are still treated as LIKE wildcards. Searching `title:100%` or `system:v_1` matches more than the literal string. Not a vulnerability; a correctness surprise. Escape `%`, `_` (and the escape char) in the value before wrapping, or use `sanitize_sql_like`.

**L2. Duplicated "shown → store hidden complement" rule (DRY — knowledge, not text).**
`app/controllers/settings_controller.rb:27` (link keys) and `app/controllers/settings/sorting_controller.rb:12` (default sorts) implement the same idea — "the form lists what to show; persist the set-difference as the hidden list". Same decision, two encodings. A small shared helper (`complement_of(shown, full_set)`) would name it once.

**L3. Repeated `DEFAULT_OPTIONS.map { |key, label| [label, key] }` (DRY).**
The same inversion into select-option pairs appears at `user.rb:67` (inside `sort_options`), `profiles_controller.rb:30`, and `collectibles/_search_form.html.erb:2`. Expose it once, e.g. `CollectibleSearch.default_sort_options`.

**L4. Presentation logic on the `User` model (Feature Envy toward the view/query layer).**
`user.rb:64` `sort_options`, `:73` `custom_sort_orders`, `:56` `visible_link_keys` assemble dropdown pairs and option maps — view/query concerns living on the record. Combined with M2 this makes `User` a hub with several reasons to change (auth, preferences, visibility, presentation). Not a God Object by cohesion yet, but trending; watch it as features land.

**L5. `follows#create` can raise on a concurrent double-submit (`reliability.md`).**
`app/controllers/follows_controller.rb:12` uses `find_or_create_by`, which has a check-then-insert race; two simultaneous follows can raise `RecordNotUnique`. The unique index (`schema.rb` `index_follows_on_follower_id_and_followed_id`) protects the data, so this is at worst a 500 on a rare race, not duplication. Rescue `RecordNotUnique` and treat it as success if you want the endpoint fully idempotent. Very low priority for a prototype.

**L6. `RootController#index` sets six instance variables (Metz rule 4).**
`app/controllers/root_controller.rb` exposes `@recent`, `@newest_collectible`, `@random_collectible`, `@link_keys`, `@followed`, `@shared`. It's a dashboard, so multiple reads are inherent and this is a defensible rule-break — noted only for completeness. If it grows, a `HomeDashboard` presenter would carry them.

**L7. `Collectible#only_applicable_fields_set` re-opens `public` mid-class (`object-oriented-design.md`: clarity).**
`app/models/collectible.rb:80` drops to `private` for one validation, then `:92` flips back to `public` for `search_links`. It works, but the private/public/private-less shuffle is easy to misread. Grouping the public methods above the single private validation reads more predictably.

---

## Subject pivot (the within-file, many-problems view)

Findings re-indexed by the file they touch; a subject spanning 2+ dimensions is a cohesion signal, not a size one.

| Subject | Dimensions it collects | Read |
|---|---|---|
| **Collectible type triad** (`_form`, `_import_fields`, `collectible_exporter`, `collectibles_helper`) | Switch Statements (H1) · Open/Closed (H1) · missed duck typing (H1) | One missing seam — type-specific presentation — scattered as a repeated conditional. Highest leverage. |
| **`User` model** | Dependency direction (M2) · Feature Envy / presentation (L4) · trending Divergent Change | A hub accreting preference/presentation/visibility responsibilities on top of auth. Not yet a God Object by cohesion, but the convergence is the warning. |
| **`CollectiblesController`** | Divergent Change (M3) · fat controller (M3) | Two flows (CRUD vs import) with independent change reasons in one class. |
| **View partials firing queries** (`_collectible`, `_profile_row`, `labels/index`, `sorting/show`) | N+1 (H2, M1) · leaked abstraction | The same root cause (querying from templates) with differing symptoms; the `.ordered`-defeats-`includes` case (H2) is the sharpest. |
| **Export ↔ import pair** | Connascence of position/name (M5) · DRY (M5) | Two services bound by an implicit contract with no shared definition. |

`CollectibleSearch` (248 lines) is over Metz's 100-line guide, but it is cohesive — one responsibility (turn a query + sort into a relation) — and its big `apply` `case` is an interpreter dispatch, not a type switch the objects could answer. Length here is acceptable; I flag it only so the size isn't mistaken for the H1 problem.

---

## Leverage-ordered fix list (by findings dissolved, not by cost)

1. **Push type-specific presentation onto the `Collectible` subclasses** (H1). Cost: M. Dissolves the four-file switch, restores Open/Closed, and shrinks two form partials and two services. Highest leverage by far.
2. **Order labels in the eager load, not in the view** (H2) and **batch the per-row counts** (M1). Cost: S each. Removes the collection-page and list-page N+1s.
3. **Extract `Collectibles::ImportsController`** (M3). Cost: M. Halves the fattest controller; enables the export/import contract (M5) to be co-located.
4. **Introduce a shared sort/field vocabulary both layers depend on** (M2, and enables L3). Cost: M. Flips the inverted dependency and removes the repeated options mapping.
5. **Single home for the `custom-N` key** (M4) and **a shared export/import field list** (M5). Cost: S / M. Collapses two connascence-of-meaning spreads.
6. **Small DRY/clarity tidies**: complement helper (L2), LIKE-escaping (L1), `public`/`private` ordering (L7). Cost: S. Genuine one-liners to small.

---

## Credits (each falsified before writing — see `rigour.md`)

- **Raw SQL is injection-safe.** Checked every interpolation: `collection_search.rb:68` (`count_order`) and `:128` (`match_type_count`) inline only `COUNT_SORTS`/alias-whitelisted `type` and `numeric_bounds`-cast integers with fixed operators; `collectible_search.rb:176,192` inline fixed column names and integer-cast bounds; every `LIKE` binds its value. No user string reaches SQL unparameterised. (The residual wildcard issue is L1 — correctness, not injection.)
- **Access control is consistently scoped.** Falsified by listing every owner-only action: `require_own_profile` (`collectibles_controller.rb:161`) guards the nested username; `set_owned_collectible`, `set_label`, `set_custom_sort`, and the profile-access / share-link destroys all resolve through `current_user.<association>.find`, so an id from another user 404s rather than leaking. `visible_to?` gates public/shared/token reads (`user.rb:104`). No unscoped `Model.find(params[:id])` on a protected resource.
- **`Collectible.model_for` can't be tricked into arbitrary `constantize`.** `collectible.rb:55` returns `nil` unless the param is in the `TYPES` allowlist before `camelize.constantize` — no constant-injection surface.
- **Bulk import is atomic.** `import_create` wraps the saves in `Collectible.transaction` (`collectibles_controller.rb:101`) after an all-valid check, so a mid-batch failure rolls back. Correct.
- **`collection_updated_at` recency is content-only.** `belongs_to :user, touch: :collection_updated_at` (`collectible.rb:34`) plus `update_columns` in the preference-persisting controllers (which skip touching) means logins/settings don't bump recency. Verified the two `update_columns` sites don't write `updated_at`.

Scope of the contrast/verification credits belongs to the UI report; here the credits are correctness/security/reliability and are scoped to what I traced above.

---

## Coverage attestation

All 40 `app/` code files (13 models, 12 controllers, 4 query files, 2 services, 3 helpers) plus `routes.rb` and `schema.rb` were swept against each dimension; every view was read for view-triggered queries and domain logic. High-stakes flows checked against their criteria: authentication/2FA (`ensure_2fa_setup`, `Users::SessionsController`, the two 2FA controllers), authorization (owner-only actions, `visible_to?`, share tokens), destructive actions (collectible/label/access/share-link destroys, `prune_disallowed_collectibles`), and state-change idempotency (import transaction, `find_or_create_by` follow). Instance censuses were run by search for the two systematic smells (type switches: 4 files; view `.ordered`/association queries: the grep in this review). No files were sampled or skipped.

**Surfaced during the self-grill:** the `.ordered`-defeats-`includes` pairing (H2) — the controller `includes` alone read as fine until the template was held against it; and the second `custom_sorts.ordered` evaluation in `sorting/show` (M1), caught by re-reading the view rather than trusting the `.any?`.
