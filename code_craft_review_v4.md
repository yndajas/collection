# Code craft review (v4)

A whole-codebase review through the code-craft lens (Metz, Fowler, GoF, the
Pragmatic Programmer / Code Complete, SOLID / connascence). Correctness and
security were run as separate passes over the same code.

Per the brief, **the testing gap is deliberately out of scope** (this is a
prototype branch). That is a real and significant hole — none of the classes
below have characterisation tests, so every refactoring suggestion here would
need tests written first — but it is excluded by request and not counted as a
finding.

## Scope

Everything under `app/` plus `config/routes.rb` and `db/schema.rb`:

- **Models (13):** `application_record`, `collectible` + STI subclasses
  (`video_game`, `board_game`, `book`), `label`, `collectible_label`,
  `custom_sort`, `follow`, `profile_access`, `share_link`, `pagination`, `user`.
- **Queries (4):** `query_search`, `query_search/parser`, `collectible_search`,
  `collection_search`.
- **Services (2):** `collectible_exporter`, `collectible_importer`.
- **Controllers (15):** `application`, `collectibles`, `collections`,
  `profiles`, `follows`, `root`, `settings`, `settings/{custom_sorts, labels,
  profile_accesses, share_links, sorting, visibility}`,
  `two_factor_authentication/{sessions, setup}`, `users/sessions`.
- **Helpers (3):** `application`, `collectibles`, `root`.

Not reviewed: framework config/initializers, migrations, `db/seeds.rb`, PWA
assets, and (by request) tests.

## What already works — credit where due

These are genuinely good and worth preserving as the code grows:

- **The `QuerySearch` base + `Parser` split is a strong abstraction.** The
  grammar (lexing, parens, AND/OR precedence, negation, the boolean AST) lives
  in one place, database-agnostic, and each subclass supplies only its token
  mapping via `#apply`. That is textbook "program to an interface" (GoF) and a
  deep module (Ousterhout): a small interface over substantial, well-hidden
  machinery. `evaluate` composing AND/OR through id-subqueries so `.or` stays
  valid across arbitrary nesting is a neat, correct piece of design.
- **STI is set up carefully:** snake_case `sti_name`/`sti_class_for`, a
  `model_for` guard that returns `nil` for unknown types, and per-subclass
  `applicable_fields`/`applicable_link_keys`. The polymorphic seam already
  exists — findings below are about *using it consistently*.
- **NULL-safe negation** in `match_like`/`match_any_like`/`match_players` is a
  subtle correctness point most code gets wrong, and it is handled and commented
  throughout.
- **Security posture is solid** (see the security pass): parameterised
  bind values, whitelisted columns and operators, strong-params everywhere,
  consistent `current_user`-scoped ownership checks.
- **The comments explain the *why*, not the *what*** (e.g. `Collectible#touch`
  on `collection_updated_at`, the `players:` overlap-vs-containment mapping, why
  `update_columns` is used for preferences). This is the good kind of comment.
- `import_create` wraps its saves in a **transaction**; `follows#create` uses
  `find_or_create_by` behind a **unique index** for idempotency. Reliability
  mechanisms are matched to real needs, not sprinkled speculatively.

## Findings, ranked

### 1. [High] The collectible field roster is duplicated across ~10 sites — Shotgun Surgery

The set of collectible attributes (`system`, `min_players`, `max_players`,
`author`, and the booleans `completed`, `evergreen`, `local_multiplayer`,
`online_multiplayer`, `cooperative`, `competitive`) is re-listed, in whole or in
part, in at least ten places:

- `Collectible::OPTIONAL_FIELDS` (`collectible.rb:25`)
- `CollectibleExporter::CSV_HEADERS` + `#common` + `#type_specific`
  (`collectible_exporter.rb:6,51,64`)
- `CollectibleImporter::KEY_MAP` + `BOOLEAN_ATTRS` (`collectible_importer.rb:21,30`)
- `CollectiblesController#collectible_params` (`collectibles_controller.rb:193`)
- `CollectiblesController#import_items_params` (`collectibles_controller.rb:133`)
- `_form.html.erb` and `_import_fields.html.erb` (the field inputs)
- `CollectiblesHelper#collectible_traits` (`collectibles_helper.rb:25`)

This is Fowler's **Shotgun Surgery**: adding one field (say `publisher`) means
editing all ten, and the two strong-params lists (`:193` and `:133`) are already
near-identical duplicates of each other — the clearest **Duplicated Code**. It
is also connascence of name and meaning spread across module boundaries, which
is the worst place for it (SOLID / Page-Jones: keep strong connascence local).

**Direction:** make the field roster answer for itself. A single source — e.g. a
`FIELDS` table on `Collectible` describing each field's name, type (boolean /
string / integer) and which subclasses use it — that `OPTIONAL_FIELDS`, the
importer's casting, the exporter's columns, the strong-params list, and the form
can all derive from. That is the Pragmatic Programmer's DRY (one authoritative
representation of the knowledge) and Code Complete's table-driven method. It
won't collapse to zero sites, but it can go from ten hand-maintained lists to
one plus thin derivations.

### 2. [High] Type-based conditionals that want polymorphism — Switch Statements, four+ sites

The same `case`/`is_a?` switch on the collectible subclass recurs:

- `CollectibleExporter#type_specific` — `case collectible when VideoGame /
  BoardGame / Book` (`collectible_exporter.rb:64`)
- `CollectiblesHelper#collectible_subtitle` — same switch
  (`collectibles_helper.rb:37`)
- `_form.html.erb:25-65` — `if @collectible.is_a?(VideoGame) elsif BoardGame
  elsif Book`, plus nested `unless Book` / `if VideoGame`
- `_import_fields.html.erb:18-69` — the *same* cascade duplicated from the form

This is Fowler's **Switch Statements** smell and a violation of Open/Closed
(Meyer): adding a fourth collectible type means finding and editing every one of
these branches. The irony is the polymorphic seam already exists — `Book`,
`BoardGame`, `VideoGame` already override `applicable_fields` and
`applicable_link_keys`. The fix is **Replace Conditional with Polymorphism**:
push the varying behaviour onto the subclasses (e.g. `#subtitle` on each,
`#export_attributes` driven by `applicable_fields`), and drive the form's
type-specific block from `applicable_fields` rather than an `is_a?` ladder.

`collectible_subtitle` and `collectible_traits` living in a helper and reaching
into the collectible's fields is also **Feature Envy** — that logic wants to be
on the model (or a presenter).

### 2 is the structural root cause

Pivoting the findings by subject (reviewing.md step 6): findings 1 and 2 both
converge on the same fact — **behaviour that varies by collectible type, and the
field roster that describes each type, are expressed *outside* the type
classes** and therefore scattered. The subclasses are currently almost
**Lazy Classes** (three or four lines each) precisely because the knowledge that
belongs in them lives in switches and constants elsewhere. The single highest-ROI
change in the codebase is to make `VideoGame`/`BoardGame`/`Book` (or a
`CollectibleType` value object they delegate to) the authoritative home for
"what fields do I have, how do I render, how do I export" — that one move
dissolves most of findings 1 and 2 together.

### 3. [High] `CollectiblesController` is a fat controller doing three jobs

At ~200 lines with a dozen private methods (`collectibles_controller.rb`), it
mixes:

1. RESTful CRUD for a single collectible (`show`/`new`/`create`/`edit`/
   `update`/`destroy`);
2. the entire three-step **bulk-import flow** (`import`, `import_template`,
   `import_review`, `import_create`, plus `import_format`, `infer_format`,
   `import_content`, `import_items_params`) — `:51-142`;
3. **domain logic** that isn't the HTTP layer's job: `build_collectible`
   choosing an STI class and filtering label ids (`:176`),
   `applicable_label_ids` intersecting against the user's labels (`:188`).

This is **Divergent Change** (the class changes for CRUD reasons *and* import
reasons *and* label-rules reasons) and breaches Metz's rule 4 (thin HTTP
boundary). Two moves, in order of payoff:

- Extract the import flow to its own `Collectibles::ImportsController` — the
  routes already namespace it as a collection sub-resource, so this is mostly a
  lift-and-shift.
- Move `build_collectible` / `applicable_label_ids` onto the domain — a
  `Collectible.build_for(user, attributes)` factory, or a small builder object.
  `applicable_label_ids` is Feature Envy on `User`/`Label`.

### 4. [Medium] Cross-layer coupling: models depend on query-object constants, and a stringly-typed `"custom-N"` key spread across four files

Dependency direction is inverted in places — lower/more-stable classes reach
*up* into the query layer:

- `User` depends on `CollectibleSearch::SORTS`, `::DEFAULT_OPTIONS`,
  `.default_option` and `Collectible::LINK_KEYS` (`user.rb:48,65,69,128`).
- `CustomSort` depends on `CollectibleSearch` for `order_clause`, `summary`, and
  three of its validations (`custom_sort.rb:19,29,50,71`).
- `CollectionSearch` reaches into `CollectibleSearch::TYPE_ALIASES`
  (`collection_search.rb:135`).

Related and more concrete: the **`"custom-N"` sort key** is a stringly-typed
convention (connascence of meaning) agreed by four places that must change
together — `CustomSort#key` (`:15`), `User#custom_sort_orders` (`user.rb:73`),
`User#collectibles_sort_is_known`'s `/\Acustom-\d+\z/` regex (`user.rb:117`), and
`CollectibleSearch#valid_sort?` (`:113`). If the format ever changes, all four
break silently. Consider a small value object (`CustomSortKey`) that owns
parsing/formatting, so the format is named once.

This is a design-smell to watch rather than an emergency — but it's the kind of
coupling that quietly makes the sort/preferences area hard to change.

### 5. [Medium] Unescaped LIKE wildcards — a correctness bug (not a security one)

This is the canonical correctness-vs-security split from the review protocol.
`match_like`, `match_any_like`, and `match_label` build
`"%#{value}%"` and pass it as a **bind value** — so it is fully
injection-safe (`query_search.rb:45,58`; `collectible_search.rb:226`). But the
`%` and `_` metacharacters inside `value` are *not* escaped, so they behave as
wildcards. Searching `title:50%` matches every title; `notes:a_b` treats `_` as
"any character". The security question ("is it injectable?") is a clean pass;
the separate correctness question ("do metacharacters behave literally?") fails.

**Fix:** escape `%`, `_` (and the escape char) in the value and add
`ESCAPE '\'`, or use Arel's matches with `escape`. Low effort, and it removes a
class of surprising results.

### 6. [Medium] Two N+1 query patterns

- **`labels.ordered` bypasses the eager load.** `ProfilesController#show`
  correctly does `includes(:labels)` (`profiles_controller.rb:35`), but the card
  partial then calls `collectible.labels.ordered`
  (`_collectible.html.erb:24`). `.ordered` is `order(:name)`, which issues a
  fresh query per collectible instead of using the preloaded association —
  reintroducing the N+1 the `includes` was meant to prevent. Sort in Ruby
  (`labels.sort_by { |l| l.name.downcase }`) to use the loaded records.
- **`collectible_counts` runs one grouped COUNT per row.**
  `_profile_row.html.erb:12` calls `collectible_counts(profile)`
  (`collectibles_helper.rb:5`), which is one `group(:type).count` query *per
  collection* — so the collections index and homepage lists fire ~15 count
  queries. The helper comment ("One grouped count query per user") acknowledges
  the per-user cost but not the per-list multiplication. For a prototype it's
  fine; at any scale, precompute counts for the whole page in one query
  (group by `user_id, type`) or a counter cache.

### 7. [Medium] `CollectibleSearch` is a Large Class with a long dispatch method

At ~248 lines (`collectible_search.rb`) the class carries the sort registry, the
custom-sort machinery, and the whole token-mapping surface. `#apply` is a
~35-line `case` (Metz rule 2, and Fowler **Long Method**). It's not urgent —
the class is cohesive (it's all "collectible search") and the switch is a
legitimate dispatch — but it's the first place to feel strain. Natural seams:
lift the sort concerns (`SORTS`, `DEFAULT_OPTIONS`, `SORT_FIELDS`,
`custom_order`, `order_clause`) into a `CollectibleSort` collaborator, leaving
the search class to filtering. That also gives findings 4's `User`/`CustomSort`
a more appropriate thing to depend on than the search object.

### 8. [Low] Duplicated `TYPE_ALIASES`

`CollectibleSearch::TYPE_ALIASES` (`collectible_search.rb:87`) and
`CollectibleImporter::TYPE_ALIASES` (`collectible_importer.rb:14`) encode the
same knowledge (type words → STI type) with slightly different entries — a
drift risk. `CollectionSearch` already imports the former across a class
boundary. One authoritative alias map (naturally on `Collectible`) removes the
duplication and the cross-class reach.

### 9. [Low] Smaller smells

- **`public` reopened mid-class** in `Collectible` (`:80`/`:92`): the
  `only_applicable_fields_set` private method is bracketed by `private`/`public`
  so `search_links` can stay public below it. Readers scan for one visibility
  block per class; move `search_links` above `private`.
- **`only_applicable_fields_set` is dense** (`collectible.rb:84`): the
  `[true, false].include?(value) ? value == true : value.present?` ternary is
  clever-but-opaque. A named predicate (`field_set?(value)`) would read better.
- **`CustomSort#custom_order` accepts both string and symbol keys**
  (`entry["field"] || entry[:field]`, `collectible_search.rb:79`) — defensive
  code that signals uncertainty about the data's shape. Decide the shape at the
  boundary (parse, don't validate) and trust it inside.
- **`FollowsController#destroy`** returns a bare `"Unfollowed"` notice when
  `target` is nil (`follows_controller.rb:25`) — a should-not-happen branch
  given the route; either treat a missing target as 404 (crash early) or drop
  the special-case copy.
- `Pagination#initialize` runs `scope.count` eagerly in the constructor
  (`pagination.rb:11`), so constructing one always hits the DB. Fine here, but
  worth being a conscious choice (a plain object that secretly queries on `new`
  can surprise).

## Security pass — summary

Run separately from correctness. No high-severity issues found:

- **SQL injection:** the raw-SQL sites (`match_players`/`match_player_field`
  interpolating column names + integers, `CollectionSearch#count_order` /
  `#match_type_count` interpolating `type`) only ever inline **whitelisted
  constants** (fixed column names, `numeric_bounds` integers cast with `.to_i`,
  `COUNT_SORTS`/`TYPE_ALIASES` values) — not user text. All user *values* go
  through bind parameters. Safe, and the code comments say why.
- **Access control:** `require_own_profile` (`collectibles_controller.rb:161`)
  and `visible_to?`/`visible_to_viewer` gate owner-only and private-profile
  access consistently; owner-scoped finders (`current_user.collectibles.find`,
  `current_user.labels.find`) prevent IDOR on edit/update/destroy.
- **Mass assignment:** strong params throughout; the label-id and
  link-key filters intersect against server-side allowlists
  (`applicable_label_ids`, `settings_params`).
- The one thing to keep honest is finding 5 (LIKE wildcards) — a correctness
  bug, explicitly *not* a security one.

## Coverage note

Every file in scope was read in full and swept per dimension (Metz sizing;
Fowler smells; SOLID/connascence; performance; reliability; and separate
correctness and security passes). Contrast/threading-level concurrency and load
behaviour were reasoned about, not measured. Tests were excluded by request; if
any of the refactorings above are pursued, characterisation tests come first
(Fowler: no refactoring without a green suite).
