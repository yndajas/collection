# Code-craft review

A review through the code-craft lens (Metz on OO design, Fowler on smells, GoF
on patterns, the Pragmatic Programmer). Overall this is a high-quality, unusually
well-commented codebase: the `QuerySearch` AST design is elegant, access control
is centralised and consistent, and the query objects are genuinely nice pieces of
work. Findings are ranked by impact. (Test coverage is out of scope — this is a
prototype branch; specs land when changes port to `main`.)

## 1. `TYPE_ALIASES` is duplicated with divergent contents

**Where:** `app/queries/collectible_search.rb:87` and
`app/services/collectible_importer.rb:14`.

**Why it matters:** Fowler's Duplicated Code, and worse — the two copies have
already drifted (each hand-maintains its own alias set). This is connascence of
value across two files: add a new type or alias and you must remember to edit
both, with nothing to catch it if you don't.

**Fix:** Make one the single source of truth (e.g. a constant on `Collectible`)
and have both refer to it. `CollectionSearch` already reaches across to
`CollectibleSearch::TYPE_ALIASES` (`collection_search.rb:135`), so the sharing
pattern is established; extend it.

## 2. Type-branching re-encodes knowledge that STI subclasses already hold

**Where:** `CollectibleExporter#type_specific` (`collectible_exporter.rb:64`)
switches `when VideoGame / when BoardGame / when Book`; the helpers
`collectible_subtitle` and `collectible_traits`
(`collectibles_helper.rb:37`, `:25`) do the same by type.

**Why it matters:** This is Fowler's "switch on type" smell in a design that has
already paid for polymorphism. The model layer knows each type's fields
(`applicable_fields`, plus the subclasses in `video_game.rb`/`board_game.rb`/
`book.rb`), but the exporter re-states "a VideoGame has system + these flags."
Add a fourth type and you must find and update every one of these `case`
statements — nothing points you at them. It's the classic case for Replace
Conditional with Polymorphism (Fowler/GoF): the subclass that owns the data
should own its serialisation/summary.

**Fix:** Give each subclass a small method (e.g. `#export_attributes`, or drive
the exporter from `applicable_fields`) and let the exporter/helpers call it
uniformly. Good learning exercise in Replace Conditional with Polymorphism —
happy to walk through it if useful.

## 3. Raw-SQL string building relies on an unenforced "trusted caller" invariant

**Where:** `query_search.rb:45–79`, `collectible_search.rb:170–213`,
`collection_search.rb:67–73` and `:128`.

**Why it matters:** There is **no SQL injection vulnerability today** — values
are parameterised or `to_i`-cast, operators come from fixed sets, and column and
type names are hard-coded or drawn from an allowlist (the comments say as much,
e.g. `collection_search.rb:66`). But safety currently rests on every caller
passing a trusted column/operator, an invariant the type system doesn't enforce.
That's connascence of meaning spread across methods: `match_like` is safe
*because* callers only ever pass literals like `"collectibles.title"`. One future
caller passing a user-derived column name turns a helper into an injection point
silently.

**Fix:** Keep the parameterised-value approach, but make the invariant explicit —
check column names against a known allowlist inside the helpers (raise or return
`none` on anything else), or introduce a tiny column-name value object. This
converts a convention into an enforced contract.

## 4. `ProfilesController#show` is a Long Method doing several jobs

**Where:** `app/controllers/profiles_controller.rb:4–53`.

**Why it matters:** It resolves visibility, computes per-viewer view/sort
preferences (with fallbacks), persists them, builds the search, and dispatches
three response formats. Metz's guidance (methods small, one responsibility) and
Fowler's Long Method both point here. The preference-resolution block
(`:22–34`) is the most extractable — it's a cohesive unit with its own comment
already.

**Fix:** Extract preference resolution into private methods (`resolved_view`,
`resolved_sort`) or a small params object, leaving `show` to read as a sequence
of intent. Behaviour-preserving.

## 5. Label-applicability logic leaks into the controller (Feature Envy)

**Where:** `collectibles_controller.rb:29–41` (`update`) and `:176–191`
(`build_collectible` / `applicable_label_ids`).

**Why it matters:** The controller reaches into `current_user.labels`, asks each
whether it `applies_to_type?`, and filters submitted ids — twice, in two shapes.
That's Feature Envy toward the label/type rules and duplicated intent across the
create and update paths.

**Fix:** Move `applicable_label_ids` to where the knowledge lives (a `User`
method, or a small form object that owns collectible-params assembly). The
controller then just hands over params. This also lets you retire the
`ActionController::Parameters`-vs-`Hash` coercion dance in `build_collectible`.

## 6. Near-duplicate negation SQL builders

**Where:** `collectible_search.rb` `match_players` (`:170`) and
`match_player_field` (`:187`) — and the negated/positive clause-building shape
recurs in `match_type_count` / `apply_flag`.

**Why it matters:** Both methods build the same "NULL-safe `NOT (col op n)` OR-ed
vs `col op n` AND-ed" clause; only the column-vs-bounds source differs. Low-risk
duplication, but the kind that drifts.

**Fix:** Extract a helper taking `[[column, op, n], …]` and a `negated:` flag and
returning the clause, then have both callers feed it their bounds.

## 7. Minor: username assignment has a benign race

**Where:** `app/models/user.rb:132` (`assign_username`).

**Why it matters:** The `while User.exists?(...)` loop is check-then-act; two
concurrent sign-ups deriving the same base could both pass the check. The DB
unique index (correctly present) would then raise on the second save rather than
retry. Very low likelihood, but the loop reads as if it fully guarantees
uniqueness and it doesn't.

**Fix:** Either rescue the uniqueness violation and retry with the next suffix,
or add a comment that the index is the real guarantor. Cheap to note; not worth
heavy machinery for a prototype.

---

**Not problems (called out so they're not "fixed" by mistake):** the
`update_columns` preference persistence (`profiles_controller.rb:60`,
`collections_controller.rb:24`) is a deliberate, well-documented choice to skip
validations and avoid bumping `updated_at`; `Follow` creation via
`find_or_create_by` (`follows_controller.rb:12`) is correctly idempotent against
the unique index; and the `QuerySearch` AST separation of grammar from
model-specific `#apply` is a clean Template Method (GoF) that earns its keep.
