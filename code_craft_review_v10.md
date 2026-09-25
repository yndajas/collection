# Code-craft review — v10

**Lens:** code craft (design, refactoring, SOLID, OO, patterns, reliability,
performance, security). **Scope:** the whole app — `app/` (models, controllers,
queries, services, helpers, views for query/perf concerns), `config/routes.rb`,
`config/initializers`, `config/environments`. **Depth:** exhaustive.
**Execution:** two independent inline passes (fresh reviewers, no shared
context) plus an adjudication read, diffed and synthesised into this report.
**Out of scope:** automated tests (prototype branch, by request).
**Date:** 2026-08-12.

## Coverage caveat

A review samples a larger space; gaps are likely, including high-severity ones.
This report is the reconciled union of two independent passes and a third
adjudication read, which raises coverage above any single pass but does not make
it complete. Where the passes disagreed on severity, the reasoning is recorded
inline. A further fresh pass remains the most reliable way to close what all
three missed. Severity ("how alarmed to be") is kept separate from the
leverage-ordered fix list ("what to do first"); the two legitimately diverge.

---

## Findings

### High

**CC1. `User` is a God Class, and it depends *up* on the query/presentation
layer.** `app/models/user.rb` (145 lines) carries five app-authored axes of
change: authentication/2FA (Devise config), identity (`username`,
`assign_username`, `to_param`, `name`), the social graph (`follows_*`,
`following?`), access control / visibility (`visible_to?`, `visible_to_viewer`,
profile accesses, share links), and viewer *presentation* preferences
(`visible_link_keys`, `sort_options`, `custom_sort_orders`, the theme/view/sort
validators). It cannot be described in one sentence without "and" — Divergent
Change / SRP.

The mechanism that lets it accrete is an inverted dependency: the model (the
most stable layer) reaches up into query- and view-layer constants —
`CollectionSearch::SORTS` (`user.rb:48`), `CollectibleSearch::DEFAULT_OPTIONS`
(`:65`), `CollectibleSearch.default_option` (`:69`), `CollectibleSearch::SORTS`
(`:117`), `Collectible::LINK_KEYS` (`:128`). Changing a sort key or a dropdown
label forces an edit in the model.

*Fix:* extract a `ViewerPreferences` collaborator (sort/view/theme/link prefs +
their three validators) and push visibility resolution into a `ProfileVisibility`
policy object. This also dissolves CC7 (link show/hide inversion) and part of
CC8 (duplicated sort roster), and unwinds the inverted dependency. This is the
expensive structural anchor — see the fix list.

*(Both passes flagged this independently; pass B named the inverted dependency as
a distinct High. Convergent subject at 4 axes — see the subject grid.)*

**CC2. `Collectible` carries four responsibilities.**
`app/models/collectible.rb`. Persistence + STI *and* the external-link URL
catalogue (`LINK_DEFINITIONS`, `LINK_KEYS`, `search_links`) *and* the
field-applicability rules (`OPTIONAL_FIELDS`, `only_applicable_fields_set`) *and*
type metadata. The link catalogue is a presentation concern living on the record.
*Fix:* extract the link catalogue into its own registry/value object; each STI
subclass already owns `applicable_fields`/`applicable_link_keys`, so lean on that.
Convergent subject (SRP + type-dispatch source + roster) — see the grid.

### Medium

**CC3. Repeated Switch on STI type — polymorphism refused (theme).** The same
three-way dispatch on `VideoGame` / `BoardGame` / `Book` recurs in four places,
though the subclasses already exist:
- `app/helpers/collectibles_helper.rb:38` — `collectible_subtitle` (`case` on class).
- `app/services/collectible_exporter.rb:65` — `type_specific` (`case` on class).
- `app/views/collectibles/_form.html.erb:25` — `is_a?` chain.
- `app/views/collectibles/_import_fields.html.erb:18` — `is_a?` chain.

Each branch body wants to be a polymorphic method (`#subtitle`,
`#export_attributes`) or a per-type partial resolved by `to_partial_path`. *Fix:*
Replace Conditional with Polymorphism. **Highest-leverage structural fix:**
dissolves four sites and makes adding a fourth collectible type a single new
class. (Severity Medium — a maintainability smell, not a defect; leverage is High.)

**CC4. N+1 queries fired from templates (theme).** Traced from the views, not the
loaders:
- `app/views/profiles/_profile_row.html.erb:12` — `collectible_counts(profile)`
  (`collectibles_helper.rb:6`) runs `user.collectibles.group(:type).count` **once
  per row**. Rendered for every collection on `collections#index` (paginated 15)
  and on the three homepage lists (`@recent`, `@followed`, `@shared`). The
  all-collections page is ~16 queries; the homepage more.
- `app/views/collectibles/_collectible.html.erb:24` and
  `collectibles/show.html.erb:36` — `collectible.labels.ordered` issues a fresh
  query per card, **defeating** `ProfilesController#show`'s `.includes(:labels)`
  (`profiles_controller.rb:35`). Calling the `ordered` scope on an already-loaded
  association re-queries; the eager-load is silently wasted. `labels.any?` uses
  the loaded set, so only `.ordered` is at fault.
- `app/views/settings/labels/index.html.erb:40` — `label.collectibles.size`,
  one COUNT per label row.
- `app/views/collectibles/_import_fields.html.erb:72` —
  `current_user.labels.ordered.select {…}` re-queries the label set for **every**
  imported item on the review screen.

*Fix:* pre-compute per-page counts in the controller
(`Collectible.where(user_id: ids).group(:user_id, :type).count`), sort loaded
labels in Ruby (`collectible.labels.sort_by { |l| l.name.downcase }`), add a
`counter_cache` or one grouped count for label item counts, and hoist the
importer's label set into a local outside the loop.

**CC5. Fat `CollectiblesController`.** `app/controllers/collectibles_controller.rb`
(201 lines) bolts a three-step bulk-import use case
(`import`/`import_template`/`import_review`/`import_create` +
`import_format`/`infer_format`/`import_content`/`import_items_params`) onto CRUD,
and pushes STI construction and authorization detail into the HTTP layer
(`build_collectible`, `applicable_label_ids`). *Fix:* extract an
`ImportsController` (or a `CollectibleImport` interactor owning review→create),
and move `build_collectible`/`applicable_label_ids` onto a builder or the model.

**CC6. `CollectibleSearch` is a fat query object.**
`app/queries/collectible_search.rb` (248 lines) mixes token→SQL mapping, sort
resolution, custom-order construction, and the board-game player-bound algebra
(`match_players`, `match_player_field`, `player_bounds`). The player-overlap math
is a cohesive sub-concept. Several methods exceed the ~5-line guide. *Fix:*
extract a `PlayerBounds` value object; consider a small table/strategy for the
`is:` flag mapping (`apply_flag`).

**CC7. Link-visibility show/hide inversion is scattered across three places.**
`ApplicationController#viewer_link_keys` (`application_controller.rb:20`) decides
which links a viewer sees, `User#visible_link_keys` computes the set,
`SettingsController#settings_params` stores the *complement* (`hidden_link_keys`),
and `settings/show.html.erb:31` re-inverts it to render "links to show". The
show↔hide inversion happening in three files is connascence of algorithm and
easy to get subtly wrong. *Fix:* one object owning "which links does viewer V see
on owner O's profile". (Dissolved by the CC1 `ViewerPreferences` extraction.)

**CC8. Duplicated rosters and clause builders (connascence of meaning).**
- `CollectibleSearch::TYPE_ALIASES` (`collectible_search.rb:87`) and
  `CollectibleImporter::TYPE_ALIASES` (`collectible_importer.rb:14`) are
  near-identical alias maps that must stay in sync.
- The NULL-safe negation clause `"(col IS NULL OR NOT (col op n))"` is copied
  across `match_players`/`match_player_field` (`collectible_search.rb:170,187`)
  and `match_type_count` (`collection_search.rb:123`).
- The sort vocabulary (`SORTS`, `DEFAULT_OPTIONS`, `SORT_FIELDS`) and the
  stringly-typed `"custom-\d+"` key format are re-stated across the query object,
  `User`'s validators, `CustomSort`, and the sorting views.

*Fix:* hoist the alias map to one constant (e.g. on `Collectible`), extract the
numeric/negation clause builder into the `QuerySearch` base, and make the
custom-sort key a value/method rather than a shared string convention.

**CC9. LIKE wildcards in user input are not escaped — injection-safe but wrong.**
`app/queries/query_search.rb:45` (`match_like`), `:58` (`match_any_like`),
`app/queries/collectible_search.rb:226` (`match_label`). The value is wrapped
directly: `like = "%#{value}%"`. The query is parameterised (no SQL injection),
but `%` and `_` in the value act as LIKE metacharacters: `title:50%` becomes
`LIKE '%50%%'` and matches titles that merely start with `50`; `a_c` matches
`abc`. It also lets a query of many `%` force expensive scans. *Fix:* escape
`%`/`_` (and the escape char) and add `ESCAPE` to each LIKE, via one shared
helper so all three sites agree. *(Severity split: pass A rated Low, pass B rated
High for the abuse angle; reconciled to Medium — a genuine correctness bug across
every LIKE search, but bounded impact.)*

### Low

**CC10. Check-then-act races on unique indexes.** `assign_username`'s
`while User.exists?` loop (`user.rb:139`), `follows#create`'s `find_or_create_by`
(`follows_controller.rb:11`), and `profile_accesses#create`
(`profile_accesses_controller.rb:15`) all SELECT-then-INSERT. The unique indexes
are the real guard, but a lost race raises an unhandled `RecordNotUnique` (500)
rather than retrying. Low at the expected volume. *Fix:* rescue
`ActiveRecord::RecordNotUnique` and retry / treat as success.

**CC11. GET requests mutate stored preferences.** `profiles_controller.rb:26,60`
and `collections_controller.rb:7,24` persist `collection_view` /
`collectibles_sort` / `collections_sort` via `update_columns` during a GET. A GET
should be safe/idempotent; a prefetch or crawler hitting `?sort=` silently
rewrites the user's stored preference. Values are whitelisted, so it isn't a
security hole, but the write-on-read is a design smell (and the `update_columns`
deliberately skips validation and `updated_at` — documented and acceptable *given*
the whitelisting, but it couples correctness to that upstream check). *Fix:*
persist preferences only via the explicit settings forms, or a non-GET.

**CC12. `Pagination` runs `COUNT` eagerly in its constructor.**
`app/models/pagination.rb:11`. Construction has a query side effect and computes
`@total`/`@page` before `records` is called, so building a `Pagination` you never
render still hits the DB. Benign here (the CSV/JSON export paths correctly bypass
pagination). *Fix (optional):* memoise `total`/`pages` lazily.

**CC13. `numeric_bounds` accepts an unbounded integer width.**
`app/queries/query_search.rb:72`. `\d+` parses a 40-digit number and casts it;
harmless with SQLite integers but worth a sane cap.

---

## Security (separate pass over the same code)

**SEC1. Content Security Policy is entirely commented out (Medium).**
`config/initializers/content_security_policy.rb` ships with the whole policy
block commented; no CSP header is sent (OWASP A05, security misconfiguration).
The app is self-hosted CSS with no inline JS beyond the generated QR SVG, so a
strict `default-src :self` is nearly free. *Fix:* enable a real policy.

**SEC2. `force_ssl` is commented out in production (Low).**
`config/environments/production.rb:28` (also `assume_ssl` :25). Cookies and 2FA
codes could travel in cleartext if deployed without TLS termination enforcing
HTTPS. This is the stock Rails default for a fresh app, hence Low, but it should
be switched on before any real deployment.

**SEC3. Account-lookup form reveals whether an account exists (Low).**
`settings/profile_accesses_controller.rb:10` responds "No user found with that
email or username", letting a signed-in user probe which emails/usernames exist
(CWE-204 enumeration). Usernames are already public via profile URLs, but the
*email* side leaks non-public data. *Fix:* respond identically regardless, or
match on username only.

**SEC4. First login after registration is single-factor (informational).**
`app/controllers/users/sessions_controller.rb:5` signs the user in fully when
`otp_required_for_login` is true but `consumed_timestep` is nil (2FA not yet set
up); `ApplicationController#ensure_2fa_setup` then forces the setup page. This is
a deliberate forced-enrolment design, not an auth bypass — confirm it's intended.

**Credits (falsified before writing):**
- **No IDOR.** Owner-scoped resources are loaded through the association —
  `current_user.collectibles.find`, `current_user.labels.find`,
  `current_user.share_links.find`, `current_user.granted_accesses.find` — and
  `require_own_profile` guards the username-nested owner actions. Checked every
  `find`/`find_by!` in the controllers; none loads a mutable resource by bare id.
- **Tokens are CSPRNG.** `ShareLink#assign_token` uses
  `SecureRandom.urlsafe_base64(16)` (`share_link.rb:17`), and the `active` scope
  (`:8`) enforces expiry at query time. Confirmed the `visible_to?` token path
  (`user.rb:109`) requires an *active* link.
- **SQL is parameterised.** The only string-interpolated SQL is in ORDER BY /
  HAVING (`count_order`, `match_type_count`, the numeric clause builders); every
  interpolated operand is an integer (`.to_i`) or a whitelisted constant, not raw
  user input. Verified each site. (The LIKE issue in CC9 is a *wildcard* leak,
  not injection.)
- **Param filtering is sound.** `label_ids`/`collectible_types`/`shown_link_keys`
  are intersected against server-side allowlists (`applicable_label_ids`,
  `Collectible::TYPES`, `LINK_KEYS`) after `permit`, so a forged id can't attach
  a label to a wrong type or across users. `filter_parameter_logging` covers
  otp/secret/token/email.

---

## Theme aggregation (across-files, same problem)

1. **Type dispatch not delegated to the STI subclasses** (CC3) — four sites
   re-implement per-type branching the subclasses could own. Single
   highest-leverage structural lever.
2. **Eager-load promises defeated / queries hiding in templates → N+1** (CC4) —
   count/order/size computed per row, per card, per label, per import item.
3. **Presentation & authorization logic accreting on `User`** (CC1, CC7) — one
   `ViewerPreferences` + `ProfileVisibility` extraction dissolves the God Class,
   the inverted dependency, and the link-inversion scatter.
4. **Injection-safe but semantically wrong / duplicated query primitives** (CC9,
   CC8) — the DSL grew site-by-site without a shared, escaped matching primitive,
   so the LIKE-wildcard bug and the clause/alias duplication share a root.
5. **God Classes accreting responsibility** (CC1, CC2) — `User`, `Collectible`.
6. **Check-then-act races** (CC10) — three SELECT-then-INSERT sites unguarded
   against the unique index.

## Subject × dimension grid (within-file, different problems)

| Subject | Distinct dimensions | Severity |
|---|---|---|
| `app/models/user.rb` | SRP/God Class (CC1), inverted dependency (CC1), roster/connascence (CC8), link-inversion (CC7) — **4** | **High (CC1)** |
| `app/models/collectible.rb` | SRP (CC2), type-dispatch source (CC3), link-catalogue roster (CC2) — **3** | **High (CC2)** |
| `app/queries/collectible_search.rb` | fat object (CC6), roster/clause duplication (CC8), LIKE wildcard (CC9) — **3** | **Medium** (escalation noted; no single-file defect is High) |
| `app/views/collectibles/_collectible.html.erb` | N+1 (CC4), type-dispatch consumer (CC3), + heading skip (UI) — **2 code** | Medium |
| `app/controllers/collectibles_controller.rb` | fat controller (CC5), STI-in-HTTP-layer (CC5/CC3) — **2** | Medium |

**Convergence interpretation.** `user.rb` (4 axes) and `collectible.rb` (3) cross
the 3-dimension floor and carry their own High. `CollectibleSearch` also reaches
three dimensions, but they are three *separable* concerns (extract `PlayerBounds`,
share the clause builder, escape the LIKE) rather than one tangled cohesion
failure, so it sits at Medium with the escalation recorded rather than a fabricated
High — the evidence for staying under the floor is that each dimension has an
independent, local fix (`file:line` cited above), not a "feels cohesive" judgement.

## Leverage-ordered fix list (by findings dissolved, not by cost)

1. **Polymorphise STI dispatch** (CC3) — dissolves 4 sites; makes a new type one
   class. Medium cost.
2. **Kill the template N+1s** (CC4) — controller-side grouped counts + drop the
   `.ordered` scope on loaded associations + hoist the importer label set. Medium
   cost, large runtime win.
3. **Extract `ViewerPreferences` + `ProfileVisibility` from `User`** (CC1, CC7,
   part of CC8) — the structural anchor; also unwinds the inverted dependency and
   slims the settings controllers. Higher cost.
4. **Extract a shared escaped `like_pattern` + numeric-clause primitive** (CC9,
   CC8) — one helper fixes correctness at three sites and removes the duplication.
   Low cost.
5. **Extract an imports controller / `PlayerBounds`** (CC5, CC6) — slims the two
   fattest units. Medium cost.
6. **Enable CSP and `force_ssl`** (SEC1, SEC2). Low cost.
7. **Rescue the unique-index races; make preference writes non-GET; cap numeric
   width; lookup-existence parity** (CC10, CC11, CC13, SEC3). Small each.
