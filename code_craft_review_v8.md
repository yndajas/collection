# Code-craft review (v8)

**Lens:** code craft (Metz, Fowler, GoF, Pragmatic Programmer, Code Complete).
**Scope:** the whole `app/` tree (controllers, models, queries, services,
helpers) plus `config/routes.rb` and the security-relevant initializers.
Views are reviewed for the *code* that lives in them (queries, type switches,
domain logic), not their markup - that is the ui-craft report's job.
**Excluded:** tests (`spec/`) and test design, by request (prototype branch);
generated Rails config; the stylesheet (ui-craft).
**Depth:** exhaustive - the low-severity tail is reported.
**Execution:** inline single pass, with the credits ledger, instance census and
self-grill applied by hand.

Coverage: 11 controllers, 13 models, 4 query classes, 2 services, 3 helpers,
routes and 2 initializers - all swept against the refactoring, SOLID/connascence
and object-oriented-design catalogues, plus separate correctness and security
passes. No files in scope were sampled or skipped.

The overall standard is high. The query/parser layer, STI modelling and strong-
params discipline are genuinely good (see Credits). The findings cluster around
two hotspots (`CollectiblesController`, `User`) and one cross-file theme (type
switches that the STI hierarchy could answer for itself).

---

## Findings by severity

### High

#### H1. `CollectiblesController` carries three or four responsibilities (Divergent Change)

`app/controllers/collectibles_controller.rb` (201 lines) is the one fat
controller in the app. Pivoting every finding that lands on it, it changes for
several unrelated reasons - Fowler's **Divergent Change**:

1. **Collectible CRUD** - `show`/`new`/`create`/`edit`/`update`/`destroy`/
   `confirm_delete` (lines 7-49).
2. **Bulk import** - a separate three-step flow (`import`, `import_template`,
   `import_review`, `import_create`) plus its own helpers `import_format`,
   `infer_format`, `import_content`, `import_items_params` (lines 51-142).
3. **Authorisation** - `require_own_profile`, the visibility branch in
   `set_collectible`, `set_owned_collectible` (lines 146-170).
4. **Collectible construction and label filtering** - `build_collectible` and
   `applicable_label_ids` (lines 176-191) are domain logic (which class to
   instantiate, which labels a type may carry), not request handling. This is
   **Feature Envy** on `Collectible`/`Label`.

It also carries two catalogue smells in its own right:

- **Duplicated permit list (connascence of value).** `collectible_params`
  (193-200) and `import_items_params` (133-142) list the same ~13 attributes.
  Add a field and both must change in lockstep, plus `build_collectible`'s
  label handling. See census in D1.
- **Long Method / repeated construction.** `build_collectible` re-implements
  type resolution and label filtering that `create`/`update` also touch.

Because this subject crosses 4 distinct dimensions (responsibility spread,
duplication, misplaced domain logic, long method), it clears the convergence
gate on its own.

**Direction (not a demand for a prototype):** lift the import flow into its own
`Collectibles::ImportsController` (the three steps + their param/format
helpers), and move `build_collectible`/`applicable_label_ids` toward the model
(e.g. `Collectible.build_for(type, attributes, user:)` and
`Label.applicable_ids_for(user, type, ids)`). That dissolves H1, D1 and part of
the type-switch theme (T1) at once.

#### H2. `User` mixes visibility policy, preferences and view-model shaping

`app/models/user.rb` (145 lines) is cohesive-looking but changes for at least
three unrelated reasons - the subject-pivot puts three distinct dimensions on
it:

1. **Divergent Change.** Beyond the Devise/association baseline it owns:
   visibility policy (`visible_to?`, `self.visible_to_viewer`, lines 89-112),
   viewer preferences (`visible_link_keys`, `sort_options`,
   `custom_sort_orders`, lines 56-75) and username generation
   (`assign_username`, 132-144). Three app-authored axes, each with its own
   reason to change.
2. **Duplication / consistency risk (connascence of meaning).** The visibility
   rules are encoded *twice*: `self.visible_to_viewer` (a scope, public + self +
   shared, no token) and `visible_to?` (instance, adds the share-token case).
   They must agree on "who can see a collection" but are written independently
   and can drift - if a new visibility rule (say, followers-only) is added,
   both need it. This is the classic pair the review protocol warns about.
3. **Presentation logic in the model.** `sort_options` and
   `self.default_option` (via `CollectibleSearch`) return `[label, value]` pairs
   shaped specifically for a `<select>` (lines 64-70). That is view-model
   assembly living in the model - Feature Envy toward the view.

**Direction:** extract a `CollectionVisibility` policy object (or at minimum
have `visible_to?` delegate to the same predicate `visible_to_viewer` is built
from, so there is one source of truth), and move the `[label, value]` shaping
into a helper or the query object. The dual visibility encoding (item 2) is the
one worth fixing even on a prototype, because a silent drift there is a
data-exposure bug, not a style nit.

### Medium

#### M1. Type switches the STI hierarchy could own (Repeated Switch)

The subclasses already model type-varying behaviour *well* in places -
`applicable_link_keys` and `applicable_fields` are overridden per subclass
(`board_game.rb`, `book.rb`, `video_game.rb`), and `Collectible#only_applicable_
fields_set` iterates them polymorphically. That is the pattern to extend. But
three more sites still branch on the concrete type instead of asking the object:

- `app/helpers/collectibles_helper.rb:37` `collectible_subtitle` - `case
  collectible when VideoGame / BoardGame / Book`.
- `app/services/collectible_exporter.rb:64` `type_specific` - the same
  three-way `case` on class.
- `app/views/collectibles/_form.html.erb:25` and
  `app/views/collectibles/_import_fields.html.erb:18` - `is_a?(VideoGame) /
  is_a?(BoardGame) / is_a?(Book)` chains selecting which fields to render.

**Census** (`grep -rn 'is_a?(\(VideoGame\|BoardGame\|Book\)\|when VideoGame\|when BoardGame\|when Book' app`): 4 sites, listed above. `collectible_subtitle`
and `type_specific` are the clean wins - a `#subtitle` and a
`#export_attributes` method on each subclass removes both `case`es and follows
the existing override pattern. The two form partials are harder (they emit
markup) and can stay; note them but don't force a pattern there.

This is Fowler's **Repeated Switch** and GoF's argument for polymorphism over
conditionals - justified here only because the switch already appears more than
once and a clean seam (the STI subclasses) exists.

#### M2. `TYPE_ALIASES` duplicated across two classes (drift-prone roster)

`CollectibleImporter::TYPE_ALIASES` (`app/services/collectible_importer.rb:14-18`)
duplicates `CollectibleSearch::TYPE_ALIASES` (`app/queries/collectible_search.rb:87-94`).
`CollectionSearch#resolve_count_type` already reuses the search copy
(`collection_search.rb:135`), which is the right instinct - the importer should
too. They happen to agree today, but two hand-maintained copies of the same
alias table is connascence of value across files: add an alias
(`vg`, `boardgames`) in one and the other silently disagrees.

**Fix:** one canonical alias map (e.g. `Collectible::TYPE_ALIASES`) both classes
reference.

#### M3. CSP is entirely disabled

`config/initializers/content_security_policy.rb` is 100% commented out, so no
`Content-Security-Policy` header is sent. This is a defence-in-depth gap
(OWASP A05: Security Misconfiguration). The app does use inline `style="..."`
(`collectibles_helper.rb:20` label tags) and inline SVG, so a real policy would
need `style-src 'unsafe-inline'` - but even a policy that only locks
`default-src 'self'; object-src 'none'; base-uri 'self'` would meaningfully
reduce XSS blast radius. Reasonable to defer on a prototype; worth a line in the
backlog.

### Low

#### L1. Non-escaped `LIKE` wildcards - the "parameterised but still wrong" trap

`match_like` and `match_any_like` (`app/queries/query_search.rb:45-67`) and
`match_label` (`app/queries/collectible_search.rb:226`) build the pattern as
`"%#{value}%"` and bind it as a parameter. That is **injection-safe** (good),
but the user's `%` and `_` are passed through unescaped, so they act as SQL
wildcards. A search for `50%` matches "50" followed by anything; `a_b` matches
`aXb`. This is the canonical correctness bug that a security-only read misses.

**Census** (`grep -rn 'LIKE' app/queries`): 3 methods, all in the query layer,
all affected. Low severity because the blast radius is search semantics, not
data exposure. Fix by escaping `%`, `_` (and the escape char) in the value
before interpolation, e.g. `value.gsub(/[%_\\]/) { "\\#{_1}" }` with an
`ESCAPE '\'` clause.

#### L2. Preference-persistence duplicated across two controllers

`ProfilesController#remember_collection_preferences`
(`profiles_controller.rb:60-65`) and
`CollectionsController#remember_collections_sort`
(`collections_controller.rb:24-28`) are the same shape - "persist a whitelisted
viewer preference with `update_columns`, skipping validation and `updated_at`",
even down to the explanatory comment. Small, but it's duplication across files.
A single `current_user.remember_preference(col, value)` (or a tiny concern)
would hold the "`update_columns` so we don't bump recency" rule in one place.

#### L3. Share-link expiry fails open to "never expires"

`Settings::ShareLinksController#create` (`share_links_controller.rb:15-16`):
`duration = EXPIRY_OPTIONS[params[:expires_in]]`. Any value not in the fixed
option set (including a tampered one) yields `nil`, which is stored as "never
expires". Fail-open rather than fail-safe. No privilege escalation (the owner is
the one creating the link), so Low, but a defaulted/rejected unknown expiry
would be tidier.

#### L4. `CustomSort` name relies on the form always sending the key

Schema has `custom_sorts.name NOT NULL` with no default (`db/schema.rb:49`), the
model has *no* presence validation on `name` (it is "optional" -
`custom_sort.rb:4`), and the controller builds it straight from
`params.dig(:custom_sort, :name)` (`custom_sorts_controller.rb:12,26`). Via the
form this is a blank string (safe), but a request omitting the key entirely
sends `nil` and hits a `NOT NULL` violation (500) rather than a validation
error. Either give the column a `default: ""` or coerce `nil` to `""` in the
controller.

#### L5. Scattered visibility keyword in `Collectible`

`app/models/collectible.rb` opens `private` at line 80, then re-opens `public`
at line 92 to expose `search_links`. Interleaving visibility sections makes the
public surface harder to read (Code Complete: keep a routine's visibility
obvious). Move `search_links` above the `private` marker.

#### L6. `apply_flag` signatures differ between the two searches

`CollectibleSearch#apply_flag(scope, flag, negated:)` (keyword) vs
`CollectionSearch#apply_flag(scope, flag, negated)` (positional). Sibling methods
in a small class family reading differently is a minor consistency snag - pick
one.

#### L7. AND/OR evaluation nests an id-subquery per node

`QuerySearch#evaluate` (`query_search.rb:24-35`) intersects AND children with
`acc.where(id: evaluate(child, base))` and unions OR children similarly, so a
deeply nested query produces deeply nested `WHERE id IN (SELECT ...)`. Correct
and composable (that is the design's virtue), and fine at collection sizes here,
but worth a comment that it trades query depth for composability. No action for
a prototype.

---

## Themes (across-files, same problem)

- **Type dispatch that wants polymorphism (M1).** 4 sites; 2 are clean wins
  that extend a pattern the codebase already uses well.
- **Hand-maintained rosters duplicated across files (M2, D1, and the two
  `TYPE_ALIASES` copies).** The type-alias table, the permit list, and the
  visibility rules are each encoded in more than one place. All are connascence
  of value/meaning that worsens with distance.
- **Domain logic living in controllers (H1 item 4, and to a lesser extent the
  `RootController` query cluster).** Construction and policy that models/queries
  should own.

## Subjects (within-one-file, different problems) - the hotspot grid

| Subject | Dimensions it collects | Verdict |
|---|---|---|
| `CollectiblesController` | Divergent Change · duplicated permit list · misplaced domain logic (Feature Envy) · long method | **High (H1)** - 4 dimensions |
| `User` | Divergent Change · dual visibility encoding · presentation-in-model | **High (H2)** - 3 dimensions |
| `CollectibleSearch` (248 ln) | LIKE wildcards (L1) · `apply_flag` signature (L6) | Not escalated - genuinely one responsibility (the collectible search grammar); size is cohesive, evidence: every method serves parsing/ordering/matching for one query. |
| query layer (`query_search`, parser) | LIKE wildcards (L1) · subquery nesting (L7) | Low only; strong design otherwise (see Credits) |
| `Collectible` | type helpers · scattered visibility (L5) | Low |

Two subjects (`CollectiblesController`, `User`) cross the 3+ dimension floor and
each gets its own High finding above, per the convergence gate. No other subject
does - `CollectibleSearch` reads large but has a single reason to change, so it
stays below the floor on evidence, not on a "feels cohesive" wave-through.

---

## Fix list, ordered by leverage (findings dissolved), not by effort

1. **Move collectible construction + label filtering onto the model**
   (`Collectible.build_for`, `Label.applicable_ids_for`). *Medium effort.*
   Dissolves H1 item 4, D1's third coupling, and feeds M1. Highest leverage.
2. **Extract `Collectibles::ImportsController`.** *Medium effort.* Dissolves the
   bulk of H1 (responsibility split) and localises D1's duplicated permit list
   to one flow.
3. **Single source of truth for visibility** (`visible_to?` and
   `visible_to_viewer` share one predicate). *Small-medium.* Dissolves H2 item 2
   - the one with a real correctness/exposure risk.
4. **One canonical `TYPE_ALIASES`.** *Small.* Dissolves M2.
5. **`#subtitle` / `#export_attributes` on the STI subclasses.** *Small.*
   Dissolves 2 of M1's 4 sites.
6. **Escape `%`/`_` in LIKE values.** *Small.* Dissolves L1 across 3 methods.
7. **Shared `remember_preference` helper.** *Small.* Dissolves L2.
8. Individual small fixes: L3, L4, L5, L6 (one-liners each).
9. **Enable a baseline CSP** (M3) - *small config, deferrable.*

---

## Credits (each falsified before writing)

- **Query/parser separation is a clean design.** `QuerySearch` owns generic
  AND/OR/negation evaluation; `Parser` is schema-agnostic; subclasses supply
  only `#apply` + ordering. *Falsify:* both `CollectibleSearch` and
  `CollectionSearch` reuse it with no parser changes and genuinely different
  token maps - confirmed by reading both `#apply`s. Real reuse, not accidental.
- **Raw SQL is injection-safe throughout.** *Falsify (the point of a separate
  security pass):* the only string interpolations into SQL are (a) numeric
  bounds - fixed operator set + `.to_i` cast (`query_search.rb:72-79`), and
  (b) `count_order`'s `type` (`collection_search.rb:67-73`), which is only ever
  reached via `COUNT_SORTS` keys / `resolve_count_type` → the whitelisted STI
  strings. LIKE patterns are bound parameters. Checked every `where("...")` and
  `Arel.sql` in `app/queries` - none interpolate unbounded user input. Holds.
  (The residual is L1: wildcard semantics, not injection.)
- **Strong params use allowlist intersection, not just `permit`.**
  `settings_params` intersects `shown_link_keys` with `Collectible::LINK_KEYS`
  (`settings_controller.rb:27`), `label_params` intersects `collectible_types`
  with `Collectible::TYPES` (`labels_controller.rb:50`), and
  `applicable_label_ids` intersects against the user's own labels
  (`collectibles_controller.rb:188-191`). *Falsify:* checked each mass-assignment
  site - all list explicit attributes and re-filter array inputs. No `permit!`.
- **Access control is enforced, not assumed.** `require_own_profile` guards every
  owner action (`collectibles_controller.rb:161-163`); `set_owned_collectible`
  scopes to `current_user.collectibles`; `Follow`/`ProfileAccess` both validate
  `!= self` *and* carry unique DB indexes (`schema.rb:62,82`). *Falsify:* looked
  for an owner action reachable without `require_own_profile` - `show` is the
  only public one and it runs its own `visible_to?` check. Holds.
- **`otp` is in the log parameter filter** (`filter_parameter_logging.rb:7`), so
  `otp_attempt` is redacted. *Falsify:* the filter matches partially, `:otp`
  matches `otp_attempt` - confirmed. Good, given 2FA is on by default.
- **`simple_format @collectible.notes`** (`show.html.erb:43`) sanitises HTML by
  default, so free-text notes are not an XSS vector. *Falsify:* Rails
  `simple_format` runs `sanitize` unless `sanitize: false` is passed; it isn't.
  Holds.
- **`touch: :collection_updated_at`** (`collectible.rb:34`) is a deliberate,
  correct design: a content-only recency signal distinct from `updated_at`,
  fed to both list ordering and the "recently updated" homepage. Coherent across
  `RootController`, `CollectionSearch#order_clause` and the schema index.
- **`Pagination`** is a tidy plain-object with the page math in one place and a
  sensible `series` gap algorithm. No notes.

Scoped credit I could *not* fully verify: the stylesheet's "all pairs WCAG-AA
verified" claim is a colour concern - covered (and mostly upheld) in the
ui-craft report, not here.

---

## Self-grill (what the final pass surfaced)

- *Which in-scope file has neither a finding nor a swept mark?* None - the thin
  controllers (`visibility`, `sorting`, `share_links`, `profile_accesses`,
  `follows`, `collections`, `root`, `settings`) and the small models
  (`Follow`, `ProfileAccess`, `ShareLink`, `CollectibleLabel`, the STI
  subclasses) were swept and are clean/single-responsibility; that absence of a
  finding is deliberate, not an unread file.
- *Every 3+-dimension subject has a High finding?* Yes - `CollectiblesController`
  (H1) and `User` (H2). No subject at the floor was talked down with cohesion
  language; `CollectibleSearch` sits *below* the floor (2 dims) with evidence.
- *Every named smell has a census, not one example?* Type switches (4 sites,
  grep pasted in M1), LIKE (3 methods, grep in L1), duplicated rosters (M2/D1
  enumerated).
- *High-stakes flows swept:* auth/2FA (`application_controller#ensure_2fa_setup`,
  the two `two_factor_authentication` controllers, `Users::SessionsController`) -
  logic is sound; destructive actions (`destroy` across collectibles, labels,
  custom sorts, share links, accesses, follows) - all scope to `current_user`'s
  own associations, none mass-delete.

> D1 is the duplicated-permit-list finding folded into H1; called out separately
> in the fix list because it can be fixed independently of the controller split.
