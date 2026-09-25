# Code-craft review — Collection (v12)

**Lens** Code craft (correctness, design, security, performance, reliability).
**Scope** `app/`, `lib/`, security-relevant `config/`. **Excluded** tests (prototype
branch, per instruction), UI/accessibility (see `ui_craft_review_v12.md`), Devise
gem internals. **Depth** Exhaustive. **Execution** Inline, 2 independent passes
(my inline sweep + one fresh critic agent, diffed and reconciled). **Date**
2026-08-14. **Commit** `0a2078c`.

## Coverage caveat

A review samples a larger space; this one is thorough but not complete, and gaps
remain — including possibly high-severity ones. Two independent passes were run
and reconciled, which widens coverage beyond a single pass, but the surest way to
raise it further is another fresh pass. N+1 findings were traced statically from
templates and loaders, not against a live query log. Coverage scaffolding is in
`code_craft_review_v12.coverage.md`.

## Findings index

| ID | Severity | Effort | Dimension | Location(s) | Title | Status |
|----|----------|--------|-----------|-------------|-------|--------|
| C-02 | High | Large | SRP / God Class (Metz, Riel) | user.rb | `User` is a God Object | open |
| C-01 | Medium | Small | LIKE-wildcard trap (correctness) | query_search.rb, collectible_search.rb | Unescaped `%`/`_` in every text search | open |
| C-03 | Medium | Small | N+1 in template (Fowler; performance) | _collectible.html.erb:24 | `labels.ordered` defeats the eager-load | open |
| C-04 | Medium | Medium | N+1 in template (performance) | collectibles_helper.rb:5, _profile_row.html.erb:12 | Grouped count per collection row | open |
| C-05 | Medium | Medium | N+1 in template (performance) | labels/index.html.erb:40, _import_fields.html.erb:72 | Count/roster query per row | open |
| C-06 | Medium | Medium | Repeated Switch / Polymorphism (Fowler, GoF) | 4 sites | Type switch on collectible subclass | open |
| C-07 | Medium | Medium | Duplicated roster / Data Clumps (Fowler) | ~11 files | Optional-field roster restated everywhere | open |
| C-08 | Medium | Medium | Divergent Change / Large Class (Fowler) | collectible_search.rb | Query object doubles as sort catalogue | open |
| C-09 | Medium | Medium | Dependency direction (solid.md) | user.rb, custom_sort.rb, 2 controllers | Models reach up into query-layer constants | open |
| C-10 | Medium | Small | Security misconfig / fail-safe defaults (OWASP A05) | content_security_policy.rb | CSP disabled | open |
| C-11 | Low | Small | Info disclosure (OWASP A07, CWE-204) | profile_accesses_controller.rb:6 | Account-enumeration oracle | open |
| C-12 | Low | Small | Defensive boundary (Code Complete) | root_controller.rb:21 | `where.not(id: nil)` correct only by coincidence | open |
| C-13 | Low | n/a | Injection-safe raw SQL (on record) | query_search.rb:72, collection_search.rb:67 | Inlined-but-cast SQL fragments | open |
| C-14 | Low | Small | Duplicated method (Fowler) | collectible.rb:61,66 | `type_label` as class + instance method | open |
| C-15 | Low | Small | N+1 / duplicate query | sorting/show.html.erb:30,32 | `.ordered` relation built twice | open |
| C-16 | Low | Small | Deploy hardening (prototype) | environments/production.rb | `force_ssl`/HSTS/host-auth commented out | open |

## Findings

#### C-02 · `User` is a God Object
**Severity** High · **Effort** Large · **Confidence** High
**Dimension** Single Responsibility / God Class (Metz, Riel; Fowler Divergent Change)
**Locations**
- app/models/user.rb (whole class, 145 lines)
**Problem** `User` changes for five independent app-authored reasons:
authentication/2FA (Devise + `otp_*`), the social graph (`follows_given/received`,
`following?`), profile visibility and access control (`visible_to?`,
`visible_to_viewer`, `allowlisted_viewers`, share-token checks), presentation
preferences (`sort_options`, `custom_sort_orders`, `visible_link_keys`, the three
sort-validation methods), and username generation (`assign_username`). Five
change-axes on one class is the definition of a God Object; the authorization
logic in particular is buried among preference plumbing, which is exactly where
you least want it for security review. This is the subject-convergence finding
(3+ distinct dimensions on one subject → High floor).
**Fix** Extract a `CollectionVisibility`/authorization policy object (owns
`visible_to?`, `visible_to_viewer`, the access/token checks) and a
`ViewerPreferences` object (owns sort/view/link selection and their validations).
Leave `User` as identity + associations.
**Verify** `user.rb` drops below ~3 app-authored responsibility axes; the
authorization methods live in one policy object a security reviewer can read in
isolation.
**Related** Theme T3; subject user.rb (with C-09). #6 on the fix list.
**Status** open

#### C-01 · Unescaped LIKE wildcards in every text search
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** LIKE-wildcard trap — correctness bug in injection-safe code (the canonical case in `craft-reviewing` protocol step 4)
**Locations**
- app/queries/query_search.rb:46,50 (`match_like`)
- app/queries/query_search.rb:59,64 (`match_any_like`)
- app/queries/collectible_search.rb:226 (`match_label`)
**Problem** All text filters build `"%#{value}%"` and bind it with `LIKE ?`, so
they are injection-*safe* but never call `sanitize_sql_like`. A user searching
`title:100%`, `system:a_b`, or free-text containing `%`/`_` gets wildcard
matching instead of a literal substring; a lone `%` matches every row. The
feature silently returns wrong results, and parameterisation masks it.
**Fix** Wrap the interpolated value in `sanitize_sql_like(value)` before
building the pattern, in the two `QuerySearch` helpers and `match_label`.
**Verify** `grep -rn 'sanitize_sql_like' app/queries` returns 3 hits; searching
`50%` matches only titles containing "50%".
**Related** Subject collectible_search.rb / query_search.rb. #1 on the fix list.
**Status** open

#### C-03 · `labels.ordered` re-queries per card, defeating the eager-load
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Behaviour hiding in templates / N+1 (Fowler; `performance.md`)
**Locations**
- app/views/collectibles/_collectible.html.erb:24 (`collectible.labels.ordered.each`)
- app/views/collectibles/show.html.erb:36 (single record → only 1 extra query, low there)
**Problem** `profiles#show` preloads with `.includes(:labels)`
(profiles_controller.rb:35), and line 22 (`labels.any?`) uses that preload — but
line 24 calls `.ordered`, which applies `ORDER BY name` that ActiveRecord cannot
serve from the loaded association, firing a fresh `SELECT` per card. At 15 cards
a page that is 15 avoidable queries.
**Fix** Order in Ruby on the loaded association (`collectible.labels.sort_by
{ _1.name.downcase }`), or eager-load an already-ordered association.
**Verify** Query log for the cards view shows one `collectible_labels` query, not
one per card.
**Related** Theme T1. #4 on the fix list.
**Status** open

#### C-04 · Grouped count query per collection row
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** N+1 / behaviour hiding in templates (`performance.md`)
**Locations**
- app/helpers/collectibles_helper.rb:5 (`user.collectibles.group(:type).count`)
- app/views/profiles/_profile_row.html.erb:12 (called per row)
**Problem** `collectible_counts` runs a grouped count for every collection row,
rendered on the paginated collections index (15/page) and the root page's
`@recent`/`@followed`/`@shared` lists — an N+1 that grows with the list.
**Fix** Load the per-type counts for the whole page in one grouped query keyed by
`user_id` (`Collectible.where(user_id: ids).group(:user_id, :type).count`) and
look each row up in memory; or add type counter caches.
**Verify** Query log shows one grouped count for the list, not one per row.
**Related** Theme T1. #4 on the fix list.
**Status** open

#### C-05 · Count/roster query per row on labels and import-review
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** N+1 (`performance.md`)
**Locations**
- app/views/settings/labels/index.html.erb:40 (`label.collectibles.size` per label)
- app/views/collectibles/_import_fields.html.erb:72 (`current_user.labels.ordered` per imported item)
**Problem** The labels index fires a `COUNT` per label (no counter cache); the
import-review page reloads the identical label roster once per reviewed item. Both
scale with row count.
**Fix** Add a `collectibles_count` counter cache (or one grouped count) for the
labels list; hoist the applicable-labels lookup out of the per-item loop in
`review.html.erb` and pass it in.
**Verify** Query log: one count query on the labels page; one labels query on the
import-review page regardless of item count.
**Related** Theme T1. #4 on the fix list.
**Status** open

#### C-06 · Repeated type switch on collectible subclass
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** Switch Statements / Replace Conditional with Polymorphism (Fowler, GoF); Open/Closed (Meyer)
**Locations**
- app/services/collectible_exporter.rb:64-85 (`type_specific`)
- app/helpers/collectibles_helper.rb:37-47 (`collectible_subtitle`)
- app/views/collectibles/_form.html.erb:25-65 (`is_a?` cascade)
- app/views/collectibles/_import_fields.html.erb:18-69 (`is_a?` cascade)
**Problem** The same `VideoGame / BoardGame / Book` dispatch recurs in four
places, though the subclasses already exist and already answer `applicable_fields`
/ `applicable_link_keys`. Adding a fourth type means editing all four sites
(Shotgun Surgery) for knowledge the object could answer itself.
**Fix** Give each subclass the behaviour: a `subtitle`, a `serialisable_attributes`
(driving the exporter), and a declarative field descriptor the form/import
partials iterate. Delete the switches.
**Verify** `grep -rn 'is_a?(VideoGame\|BoardGame\|Book)\|when VideoGame' app`
returns 0; a stub fourth subclass needs no edits at these sites.
**Related** Theme T2; subjects exporter.rb, collectibles_helper.rb. #2 on the fix list.
**Status** open

#### C-07 · Optional-field roster restated across ~11 files
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** Duplicated roster / Data Clumps (Fowler); connascence of name across boundaries
**Locations**
- app/models/collectible.rb:25 (`OPTIONAL_FIELDS`)
- app/controllers/collectibles_controller.rb:135-140 and 194-199 (two identical permit lists)
- app/services/collectible_exporter.rb:6-10 (headers) and 51-85
- app/services/collectible_importer.rb:21-30 (`KEY_MAP`)
- app/views: _form, _import_fields, _search_help, _search_form
**Problem** The collectible attribute set is re-declared as permit lists, CSV
headers, an import key map, and view fields across ~11 files, kept in sync only by
convention. The two controller `permit(...)` lists are byte-identical and will
drift. A new optional column means a coordinated edit in ten-plus places.
**Fix** Derive the shared roster from one source (`OPTIONAL_FIELDS` plus the
common fields) and build the permit lists, headers, and key map from it; give each
subclass its own applicable subset (dovetails with C-06).
**Verify** Adding a column touches one declaration; `grep` for the new name
appears only in the derived sites.
**Related** Theme T2; subject collectibles_controller.rb. #2 on the fix list.
**Status** open

#### C-08 · `CollectibleSearch` doubles as the sort catalogue
**Severity** Medium · **Effort** Medium · **Confidence** Medium
**Dimension** Divergent Change / Large Class (Fowler); SRP
**Locations**
- app/queries/collectible_search.rb (248 lines — the largest app file)
**Problem** Besides its real job (token→SQL mapping in `apply`/`match_*`), the
class owns the dropdown sort catalogue (`SORTS`, `DEFAULT_OPTIONS`, `SORT_FIELDS`,
`default_option`) and the custom-sort criteria↔SQL translation (`custom_order`).
Those two concerns are consumed by `User`, `CustomSort`, and two controllers, so
the query object is also a shared constants bag — two–three change-axes.
**Fix** Extract a `SortCatalogue` value object holding the sort constants and
`custom_order`; both the query object and the models depend on it (resolves C-09).
**Verify** `collectible_search.rb` holds only token-mapping; sort constants live
in one neutral object.
**Related** Theme T3; subject collectible_search.rb (with C-01). #3 on the fix list.
**Status** open

#### C-09 · Models reach up into query-layer constants
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** Dependency direction / connascence of name across boundaries (`solid.md`, `reviewing.md`)
**Locations**
- app/models/user.rb:48,65,117 (`CollectionSearch::SORTS`, `CollectibleSearch::SORTS`/`DEFAULT_OPTIONS`)
- app/models/custom_sort.rb:33,50,67,71 (`CollectibleSearch::SORT_FIELDS`/`SORTS`/`DIRECTIONS`)
- app/controllers/profiles_controller.rb:23,30; collections_controller.rb:6
**Problem** Domain models depend on presentation/query-layer constants for their
own validation and defaults — the stable layer coupled to a more volatile one.
The sort vocabulary should live in a neutral place both layers depend on.
**Fix** Move the sort vocabulary into the `SortCatalogue` from C-08; models and
queries both depend on it, not on each other.
**Verify** `grep -rn 'CollectibleSearch::\|CollectionSearch::' app/models` returns
0 (models reference the neutral catalogue instead).
**Related** Theme T3; subjects user.rb, custom_sort.rb. #3 on the fix list.
**Status** open

#### C-10 · Content Security Policy disabled
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Security misconfiguration (OWASP A05); fail-safe defaults (Saltzer & Schroeder)
**Locations**
- config/initializers/content_security_policy.rb (entirely commented out)
**Problem** No CSP header ships. The app renders user-controlled strings (titles,
notes, display/label names) throughout, with autoescaping as the *only* XSS
defence and no defence-in-depth. The `html_safe` SVG at setup_controller.rb:27
(gem-generated, safe today) would also be backstopped by a policy.
**Fix** Enable at least `default-src :self` with `object-src :none` and an
explicit `script-src`/`style-src`; tighten from there.
**Verify** Response carries a `Content-Security-Policy` header; an inline
`<script>` injected into a note is blocked in the browser console.
**Related** Theme T4. #5 on the fix list.
**Status** open

#### C-11 · Account-enumeration oracle on the access-grant lookup
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Identification failures / information disclosure (OWASP A07, CWE-204)
**Locations**
- app/controllers/settings/profile_accesses_controller.rb:6-11
**Problem** The grant form answers "No user found with that email or username" vs
a success message, letting any signed-in user probe whether a given email/username
has an account. Secondary latent trap in the same query: it matches `username = ?`
against a *lowercased* identifier, so an uppercase username would never match by
username (safe in practice only because usernames are validated lowercase at
user.rb:46).
**Fix** Return a generic "If that person has an account, they now have access"
regardless of hit/miss; make the username comparison consistent with how usernames
are stored.
**Verify** Response text is identical for a real and a fake identifier.
**Related** Theme T4. #5 on the fix list.
**Status** open

#### C-12 · `where.not(id: @newest_collectible)` correct only by coincidence
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Defensive boundary / clarity (Code Complete)
**Locations**
- app/controllers/root_controller.rb:21
**Problem** When the collection is empty `@newest_collectible` is nil, so
`where.not(id: nil)` generates `id IS NOT NULL` — which would pick any row, and is
harmless only because `own` is itself empty then. The line works by the accident
that both derive from the same empty scope, and relies on implicit id extraction
from an AR object; a maintainer editing either line reintroduces a bug.
**Fix** `own.where.not(id: @newest_collectible&.id)` guarded on
`@newest_collectible.present?`.
**Verify** With a one-item collection, `@random_collectible` is nil; with two, it
differs from `@newest_collectible`.
**Related** —
**Status** open

#### C-13 · Injection-safe inlined SQL fragments (on record)
**Severity** Low · **Effort** n/a · **Confidence** High
**Dimension** Raw SQL construction (security — verified safe)
**Locations**
- app/queries/query_search.rb:72-79 (`numeric_bounds`, integer-cast + fixed operators)
- app/queries/collection_search.rb:67 (`count_order`, whitelisted `type`)
**Problem** These build SQL fragments by interpolation. Verified safe today —
values are `.to_i`-cast integers or an allowlisted STI type, operators are a fixed
set. Recorded so the pattern stays deliberate if extended.
**Fix** None required; keep the integer cast / allowlist if these grow, and
prefer Arel/bindings for any non-scalar addition.
**Verify** No user string reaches these fragments un-cast.
**Related** —
**Status** open

#### C-14 · `type_label` as both class and instance method
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Duplicated method surface (Fowler)
**Locations**
- app/models/collectible.rb:61 (class), :66 (instance delegating to class)
**Problem** Two entry points for the same value; callers mix them. The instance
pass-through is acceptable but adds surface.
**Fix** Keep one if the other has no distinct callers; otherwise leave with a note.
**Verify** Callers use a single form.
**Related** —
**Status** open

#### C-15 · `custom_sorts.ordered` relation built twice
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Duplicate query (performance, minor)
**Locations**
- app/views/settings/sorting/show.html.erb:30 (`.ordered.any?`), :32 (`.ordered.each`)
**Problem** Two fresh relations → two queries where one loaded collection would do.
**Fix** Assign `sorts = @user.custom_sorts.ordered.to_a` once; use `.any?`/`.each`
on the array.
**Verify** One `custom_sorts` query on the sorting page.
**Related** Theme T1.
**Status** open

#### C-16 · Production SSL/HSTS/host-auth left commented
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Deploy hardening (prototype default)
**Locations**
- config/environments/production.rb:25,28,31,60-66
**Problem** `assume_ssl`, `force_ssl` (HSTS + secure cookies), and
`config.hosts` DNS-rebinding protection are commented out (stock Rails). Expected
for a prototype, but must be enabled before any real deployment.
**Fix** Enable `force_ssl` and host authorization in production before deploy.
**Verify** Response carries `Strict-Transport-Security`; requests with a foreign
`Host` are rejected.
**Related** Theme T4.
**Status** open

## Themes

### T1 · N+1 behaviour hidden in views
**Members** C-03, C-04, C-05, C-15. **Root** per-row queries fired from templates
(a `.ordered` that defeats a preload, a grouped count per row, a re-loaded roster)
— invisible from the controller's loader.
**Leverage** Loading the per-row data once per page (ordered-in-Ruby, one grouped
count, hoisted roster) dissolves all four.

### T2 · Collectible shape duplicated instead of owned by the model
**Members** C-06, C-07. **Root** per-type knowledge and the attribute roster live
in switches, permit lists, headers and views rather than on the subclasses.
**Leverage** A declarative per-subclass field descriptor drives the form, import,
exporter, and permit lists — dissolving the switch and the duplicated roster
together.

### T3 · Sort/visibility vocabulary lives in the query layer; models reach up for it
**Members** C-08, C-09, C-02. **Root** the sort catalogue and (for C-02) the
visibility policy are entangled with classes that should only depend on them.
**Leverage** Extracting a neutral `SortCatalogue` and a visibility policy object
fixes the dependency direction (C-09), shrinks the query object (C-08), and
removes a responsibility axis from `User` (C-02).

### T4 · Security defaults left open
**Members** C-10, C-11, C-16. **Root** default-open configuration and an
information-leaking message — fail-safe-defaults not yet applied.
**Leverage** A short hardening pass (CSP header, generic grant response, enable
`force_ssl`/host-auth) closes all three before deployment.

## Subject grid

| Subject | Dimensions (finding IDs) | # | Severity | Interpretation |
|---------|--------------------------|---|----------|----------------|
| user.rb | C-02, C-09 | 2 | High | God Class: auth + social graph + visibility/authz + preferences + username (5 axes) — the authz logic wants isolating |
| collectible_search.rb | C-01, C-08 | 2 | Medium | Query object also acting as sort catalogue + custom-sort translator |
| collectibles_controller.rb | C-06 (feeds), C-07 | 2 | Medium | Two identical permit rosters; per-type field knowledge it shouldn't own |
| exporter.rb / collectibles_helper.rb | C-06 | 1 | Medium | Type switches that want polymorphism |
| _collectible / _profile_row / labels·index | C-03, C-04, C-05 | 1 each | Medium | One theme (N+1), three subjects |

Convergence rule: a subject at 3+ distinct dimensions gets its own finding at High
or higher. Only `user.rb` reaches it (5 app-authored responsibility axes) → C-02
at High; no subject was downgraded by a cohesion impression.

## Leverage-ordered fix list

1. `sanitize_sql_like` in the two `QuerySearch` helpers + `match_label` →
   dissolves C-01 (1) across ~6 call sites. Effort Small.
2. Per-subclass field descriptor + shared roster (form/import/exporter/permits) →
   dissolves C-06, C-07 (2). Effort Medium.
3. Extract a neutral `SortCatalogue` both models and queries depend on →
   dissolves C-09, dents C-08 and C-02 (1 + partials). Effort Medium.
4. Load per-row data once per page → dissolves C-03, C-04, C-05, C-15 (4).
   Effort Medium.
5. Hardening pass: CSP header, generic grant response, enable `force_ssl` →
   dissolves C-10, C-11, C-16 (3). Effort Small.
6. Extract visibility-policy + preferences objects from `User` → dissolves C-02
   (1), completes #3. Effort Large.

## Credits (each falsified before writing)

- **Authorization is consistently ownership-scoped.** Falsified by enumerating
  every mutating/destructive action (coverage sidecar, high-stakes census): all
  load via `current_user.<assoc>.find` or `require_own_profile`; `collectibles#show`
  loads via `@profile.collectibles.find` then gates on `visible_to?`. No action
  loads by bare `params[:id]` without an owner scope. IDOR-clean.
- **Share-link tokens use a CSPRNG with a unique index.** share_link.rb:17
  `SecureRandom.urlsafe_base64(16)`; schema.rb:94 unique index. Not `rand`.
- **`visible_to?` fails safe (default deny).** user.rb:104-111 returns `false`
  after explicit allow branches; a blank token with no viewer is denied.
- **Follow/access creation is idempotent against races.** `find_or_create_by`
  (follows_controller.rb:11) + unique index (schema.rb:62); profile_accesses
  unique index (:82) + model validation. Self-follow/self-grant blocked by
  validations.
- **Schema indexing matches the query patterns.** Every FK, the visibility
  lookups, and `users.username`/`email`/`collection_updated_at`/`public_profile`,
  `collectibles.type`/`user_id`/`title` are indexed. Only the leading-`%` LIKE
  (C-01) is an unavoidable scan.
- **Sensitive params are filtered.** filter_parameter_logging.rb covers `passw`,
  `otp`, `token`, `secret`, `crypt`, `salt` — OTP attempt, share token, password
  all filtered.
- **The query DSL's AND/OR/negation is composed with id-subqueries** so `.or`
  stays valid across differing branches (query_search.rb:24-35) — read as correct;
  not exhaustively fuzzed against adversarial nesting (recorded as a caveat, a good
  target for the next pass).

---

A second fresh pass is worth running, especially against the query DSL's
`evaluate`/negation correctness under deep nesting and a live query-log
confirmation of the N+1s.
