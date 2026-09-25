# Code-craft review — v13

**Lens** Code craft (OOP design, smells, coupling/connascence, patterns,
performance, reliability) plus a separate security sub-pass.
**Scope** All of `app/` and `lib/`, `config/routes.rb`, and security-relevant
`config/`. Views read for code concerns only (view-triggered I/O, domain logic
in templates, type switches). **Excluded:** tests (`spec/`, `features/`) — this
is a prototype branch and their omission is deliberate, so it is not a finding.
**Depth** Exhaustive. **Execution** Inline, two independent parallel passes
(fresh agents), diffed and verified against the source, then synthesised.
**Date** 2026-08-14. **Commit** `0a2078c` (branch `prototype`).

IDs are fresh for this pass (`C-` design/correctness, `S-` security). This is an
unbiased review: no prior review file was consulted.

## Coverage caveat

A review is a sample of a much larger space, and gaps are likely — including
high-severity ones. Two independent passes were run and reconciled, which raises
coverage above a single pass, but "no finding here" never means "verified
correct". The security sub-pass in particular reasons about code, not a running
system; several items (TLS termination, CSP behaviour, rate-limiting at a proxy)
depend on deployment facts not visible in the repo. Another independent pass, or
a run against a live instance with a query log and `axe`, remains the most
reliable way to raise coverage further.

## Findings index

| ID | Severity | Effort | Dimension | Location(s) | Title | Status |
|----|----------|--------|-----------|-------------|-------|--------|
| C-01 | High | Large | SRP / God Object (Metz, Fowler Divergent Change) | user.rb | `User` God Object | open |
| C-06 | High | Large | SRP / God Controller (Metz, Fowler) | collectibles_controller.rb | `CollectiblesController` does five jobs | open |
| S-01 | High | Medium | OWASP A07 (CWE-307) | 2fa + sessions controllers | No brute-force throttling on password or OTP | open |
| C-02 | Medium | Small | Performance — view N+1 (performance.md) | _collectible.html.erb:24, show.html.erb:37 | `labels.ordered` defeats `includes(:labels)` | open |
| C-03 | Medium | Medium | Performance — view N+1 (performance.md) | _profile_row.html.erb:12 | Grouped COUNT per collection row | open |
| C-04 | Medium | Medium | Fowler Switch Statements / Replace Conditional with Polymorphism | 4 sites | STI type switch outside the hierarchy | open |
| C-05 | Medium | Medium | DRY / Shotgun Surgery (Pragmatic, Fowler) | 8+ sites | Collectible attribute roster restated everywhere | open |
| S-02 | Medium | Small | OWASP A05 Security Misconfiguration | production.rb, CSP initializer | Platform hardening (TLS/HSTS/CSP/hosts) disabled | open |
| S-04 | Medium | Small | OWASP A07 (CWE-204) | profile_accesses_controller.rb:10-12 | User-enumeration oracle on access grant | open |
| C-07 | Low | Medium | DRY / Duplicated Code (Fowler) | 2 search classes | Duplication between the two search classes | open |
| C-08 | Low | Small | Pragmatic DRY / connascence of Algorithm | 5 controllers | "Intersect with allowlist" idiom scattered | open |
| C-09 | Low | Medium | Primitive Obsession / connascence of Meaning (solid.md) | 4 sites | Stringly-typed custom-sort criteria | open |
| C-10 | Low | Small | Reliability — check-then-act race | user.rb:132-144 | `assign_username` TOCTOU + O(n) probing | open |
| C-11 | Low | Small | Reliability — validation/constraint mismatch | user.rb:43-46, schema | Case-insensitive username validated, case-sensitive index | open |
| C-12 | Low | Small | Performance — index filtered columns | schema, collectible_search.rb | Missing indexes on range/filter columns | open |
| C-13 | Low | Small | Reliability — idempotency (reliability.md) | collectibles_controller.rb:96-108 | Bulk import not idempotent | open |
| C-14 | Low | Small | Performance / temporal coupling | pagination.rb:8-13 | `Pagination` runs COUNT eagerly in constructor | open |
| C-15 | Low | Small | Performance / readability | root_controller.rb:19-21 | `ORDER BY RANDOM()` full sort to pick one row | open |
| C-16 | Low | Small | Clarity (Fowler) | collectible.rb:84-90 | Dense boolean "is set?" conditional | open |
| S-03 | Low | Small | OWASP A07 (CWE-204) | devise.rb:97 | Devise `paranoid` off — reset enumerates emails | open |
| S-05 | Low | Small | OWASP A01 (CWE-203) | collectibles_controller.rb:146-157 | 404-vs-403 existence oracle on collectible show | open |
| S-06 | Low | Small | OWASP A03 (LIKE metacharacters) | query_search.rb:45-67, collectible_search.rb:226 | Unescaped LIKE wildcards in every text search | open |
| S-07 | Low | Medium | Secure design / connascence of Meaning | 4 query sites | Raw-SQL fragments safe only by upstream convention | open |
| S-08 | Low | Medium | OWASP A07 / fail-safe defaults | application_controller.rb:27-34 | 2FA not enforced before setup completes | open |

## Findings

### High

#### C-01 · `User` is a God Object
**Severity** High · **Effort** Large · **Confidence** High
**Dimension** SRP / Divergent Change (Metz Rule 1; Fowler; `object-oriented-design.md` responsibility census)
**Locations**
- app/models/user.rb (whole file, 145 lines)

**Problem** Beyond the Devise/2FA framework axis, `User` carries four
app-authored responsibilities: identity/username (`to_param`, `name`,
`assign_username`, :77-83, :132-144); the social graph (`follows_given/received`,
`following?`, `followed_collections`, :28-36, :98-100); access-control policy
(`visible_to?`, `visible_to_viewer`, granted/received accesses, share-link check,
:15-23, :89-112); and presentation preferences (themes, views, `sort_options`,
`custom_sort_orders`, `visible_link_keys` and their validations, :38-70).
"Describe it in one sentence without *and*" fails. Both independent passes' subject
grids placed `User` at 3+ distinct dimensions, which is the convergence gate for
High. The concrete harm is Divergent Change — a follow-graph tweak, a new theme,
and a share-link rule all edit one class — and that the security-critical
`visible_to?` lives among sort-dropdown helpers, where a preferences edit can
graze the visibility rule.
**Fix** Extract collaborators as you next touch each axis (per Fowler's
"economics, not aesthetics", not a big-bang rewrite): a `ProfileVisibility` policy
object owning `visible_to?`/`visible_to_viewer`; a preferences value object for
the sort/link/view helpers. `User` is left with identity + associations.
**Verify** After extraction `User` describes in one sentence; the visibility rules
live in one object; `grep -n "def " app/models/user.rb` shows the preference and
visibility clusters gone.
**Related** Themes T-CODE-4; subject `user.rb`. Rolls up C-09, C-10, C-11. #2 on the fix list.
**Status** open

#### C-06 · `CollectiblesController` does five jobs
**Severity** High · **Effort** Large · **Confidence** High
**Dimension** SRP / God Controller; Fowler Divergent Change + Large Class; Metz fat-controller
**Locations**
- app/controllers/collectibles_controller.rb (whole file, 201 lines)

**Problem** Five app-authored responsibility axes converge here (both passes'
grids put it at 3+ distinct dimensions → convergence gate): (1) CRUD on one owned
collectible; (2) public `show` with visibility/token gating and the private-profile
fallback (:146-157); (3) a three-step bulk-import wizard with its own params shape
and transaction (:55-108, :133-142); (4) CSV template export (:62-66); (5) STI
construction and label-applicability filtering (`build_collectible`,
`applicable_label_ids`, :176-191) — domain rules that belong on the model, not the
HTTP layer (Feature Envy toward `Label#applies_to_type?`). `update` re-implements
the label filter inline (:31-33).
**Fix** Extract the import wizard to its own controller (`Collectibles::Imports`)
or an interactor; move `build_collectible`/`applicable_label_ids` onto a factory or
the models; share one permitted-attrs constant between `collectible_params` and
`import_items_params`.
**Verify** The controller describes in one sentence; `grep -c "def applicable_label_ids"`
→ 1; the import actions live elsewhere.
**Related** Themes T-CODE-2, T-CODE-3; subject `collectibles_controller.rb`. Rolls up C-08, C-13, S-05. #3 on the fix list.
**Status** open

#### S-01 · No brute-force throttling on password sign-in or OTP
**Severity** High · **Effort** Medium · **Confidence** High
**Dimension** OWASP A07 Identification & Authentication Failures (CWE-307); Saltzer & Schroeder fail-safe
**Locations**
- app/controllers/two_factor_authentication/sessions_controller.rb:14 (`validate_and_consume_otp!`)
- app/controllers/two_factor_authentication/setup_controller.rb:10
- app/controllers/users/sessions_controller.rb (Devise `create`)
- config/initializers/devise.rb:200-218 (`:lockable` commented out)

**Problem** Verified: `grep -rn "rate_limit\|Rack::Attack" app config Gemfile`
returns nothing, and Devise `:lockable` is commented. The second factor is a
6-digit code (10^6 space); with no attempt cap, lockout, or throttle an attacker
who has (or is guessing) the password can grind the OTP by replaying
`POST /two_factor_authentication/session`. Password sign-in is likewise
unthrottled. This defeats the purpose of the second factor.
**Fix** Add Rails 8 `rate_limit` to the Devise `create` and both 2FA
`create`/`update` actions, keyed by IP and/or `otp_user_id`; and/or enable Devise
`:lockable`. Cap attempts per OTP challenge and expire the `otp_user_id` window.
**Verify** `grep -rn "rate_limit\|Rack::Attack" app config` shows a control on the
three actions; a script sending 100 bad OTPs is blocked (429/lock) before 100.
**Related** Theme T-CODE-5. #4 on the fix list.
**Status** open

### Medium

#### C-02 · `labels.ordered` in row partials defeats the controller's eager load
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Performance — view-triggered N+1 (`performance.md`: a scope invoked on an already-loaded association re-queries)
**Locations**
- app/views/collectibles/_collectible.html.erb:24 (`collectible.labels.ordered.each`)
- app/views/collectibles/show.html.erb:37 (same; single record, so harmless there)
- app/controllers/profiles_controller.rb:35 (`@search.results.includes(:labels)`)
- app/models/label.rb:15 (`scope :ordered, -> { order(:name) }`)

**Problem** Falsified from the template, not the loader (per `rigour.md`): the
controller preloads `labels` *unordered*, but `.ordered` builds a new relation with
`ORDER BY name`, so ActiveRecord ignores the preloaded set and fires one query per
card. On a 15-card page that is 15 wasted queries and the `includes` buys nothing.
`collectible.labels.any?` on the previous line is fine (uses the loaded set); only
`.ordered` re-queries.
**Fix** Sort the already-loaded set in Ruby: `collectible.labels.sort_by { |l| l.name.downcase }`;
or preload an ordered association; or drop `.ordered` if card order does not matter.
**Verify** Render a 15-card page under a query log — one labels query total, not 16.
**Related** Theme T-CODE-1; subjects `_collectible.html.erb`, `show.html.erb`. #1 on the fix list.
**Status** open

#### C-03 · Grouped COUNT per collection row in list views
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** Performance — view-triggered N+1 (`performance.md`)
**Locations**
- app/helpers/collectibles_helper.rb:5-6 (`user.collectibles.group(:type).count`)
- app/views/profiles/_profile_row.html.erb:12 (calls it once per row)
- Rendered per row by app/views/collections/index.html.erb (up to `PER_PAGE = 15`) and app/views/root/_collection_list.html.erb (used three times on the homepage)
- app/views/settings/labels/index.html.erb:41 (`label.collectibles.size` — one COUNT per label row, same shape)

**Problem** Each profile row fires its own `GROUP BY type COUNT(*)`, so the
`/collections` index issues ~15 count queries per page and the homepage one per
collection across three lists. The helper's own docstring ("one grouped count
query per user") confirms the per-row intent.
**Fix** Preload counts once in the controller:
`Collectible.where(user_id: ids).group(:user_id, :type).count`, pass the lookup to
the partial; or add per-type counter caches. `CollectionSearch` already knows the
id set. Same treatment for the labels index.
**Verify** Load `/collections` with 15 rows under a query log — O(1) count queries.
**Related** Theme T-CODE-1; subjects `collectibles_helper.rb`, `_profile_row.html.erb`. #1 on the fix list.
**Status** open

#### C-04 · STI type switch repeated outside the hierarchy
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** Fowler Switch Statements + Duplicated Code; Metz duck typing; Meyer Open/Closed
**Locations**
- app/services/collectible_exporter.rb:64-86 (`type_specific` — `when VideoGame/BoardGame/Book`)
- app/helpers/collectibles_helper.rb:37-47 (`collectible_subtitle` — same `case`)
- app/views/collectibles/_form.html.erb:25-65 (`is_a?` chain + `unless is_a?(Book)`)
- app/views/collectibles/_import_fields.html.erb (parallel `is_a?` chain)

**Problem** The subclasses `VideoGame`/`BoardGame`/`Book` already exist, yet
presentation and serialisation branch on type in four+ places instead of asking
the object. Adding a fourth type means editing every switch — classic Shotgun
Surgery from an incompletely-applied STI hierarchy.
**Fix** Push the type-specific behaviour onto the subclasses: `#export_fields`,
`#subtitle`, and a declarative field spec the form partial iterates
(`applicable_fields` already exists — drive the form off it). The exporter's
`type_specific` becomes `collectible.export_fields`.
**Verify** `grep -rn "is_a?(VideoGame\|is_a?(BoardGame\|is_a?(Book\|when VideoGame" app`
drops to 0; adding a stub fourth subclass needs no edits to these sites.
**Related** Theme T-CODE-2; subjects exporter, helper, form partials. Closely tied to C-05. #5 on the fix list.
**Status** open

#### C-05 · Collectible attribute roster restated across the codebase
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** DRY / Shotgun Surgery (Pragmatic Programmer; Fowler); connascence of Meaning across modules
**Locations** (census of the optional-attribute list + type aliases)
- app/models/collectible.rb:25-28 (`OPTIONAL_FIELDS` — canonical)
- app/controllers/collectibles_controller.rb:194-199 (`collectible_params`) and :135-140 (`import_items_params`) — two near-duplicate permit lists
- app/services/collectible_importer.rb:21-28 (`KEY_MAP`) and :30, :94-104 (cast lists)
- app/services/collectible_exporter.rb:6-9, 20-37 (CSV headers + row) and :51-86 (JSON)
- app/queries/collectible_search.rb:54-63 (`SORT_FIELDS`, subset)
- app/helpers/collectibles_helper.rb:25-34 (traits, subset)
- `TYPE_ALIASES` defined **twice** independently (collectible_search.rb:87-94, collectible_importer.rb:14-18) and referenced cross-class by collection_search.rb:135

**Problem** Adding one attribute (say `publisher`) means coordinated edits in
6-9 places with no compiler to catch a miss, so the importer or exporter silently
drops it. The two `TYPE_ALIASES` copies can (and already slightly do) drift, so
import and search can disagree on what "game" means. This is the codebase's
dominant change-amplifier.
**Fix** Drive the roster from one declaration — a per-attribute descriptor (name,
types that use it, cast) read by strong-params, `KEY_MAP`, the exporter and
`applicable_fields`. Make `Collectible::TYPE_ALIASES` the single source and have
the importer reference it.
**Verify** Add a throwaway attribute in the single source; it round-trips through
import → export untouched elsewhere. `grep -rn "TYPE_ALIASES =" app` → 1 definition.
**Related** Theme T-CODE-3; subjects collectible, controller, importer, exporter. Rolls up C-07, C-08. #6 on the fix list.
**Status** open

#### S-02 · Platform hardening disabled in production config
**Severity** Medium · **Effort** Small · **Confidence** High (facts) / Medium (impact, deployment-dependent)
**Dimension** OWASP A05 Security Misconfiguration (defence-in-depth for A03 XSS, A02 cleartext)
**Locations**
- config/environments/production.rb:25, 28, 31, 60 (`assume_ssl`, `force_ssl`, `ssl_options`, `hosts` all commented)
- config/initializers/content_security_policy.rb (entire policy commented — 0 active lines, verified)

**Problem** No `force_ssl`/HSTS, no Content-Security-Policy, and no host
allowlist. For an app doing auth + 2FA, session and "remember me" cookies can
travel cleartext if TLS is not forced upstream, and there is no CSP backstop for
an XSS foothold (ERB autoescaping is the only XSS defence, and there is one raw
sink — the QR SVG at setup_controller.rb:27). This is deployment-dependent (a
proxy may terminate and force TLS), hence Medium, but nothing in-repo guarantees
it, and CSP absence holds regardless of the proxy. **Before production this is
High.**
**Fix** Set `config.force_ssl = true` (keeping the `/up` exclusion), ship a real
CSP (`default-src :self`, `object-src :none`, nonce'd scripts, no
`unsafe-inline`), and set `config.hosts` to the real domain(s).
**Verify** `curl -sI https://<host>/` returns `Strict-Transport-Security` and
`Content-Security-Policy`; an HTTP request 301s to HTTPS; a foreign `Host` header 403s.
**Related** Theme T-CODE-5.
**Status** open

#### S-04 · User-enumeration oracle when granting profile access
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** OWASP A07 (CWE-204 Response Discrepancy); Saltzer & Schroeder fail securely
**Locations**
- app/controllers/settings/profile_accesses_controller.rb:6-12 (looks up by `LOWER(email) OR username`, then `alert: "No user found with that email or username."`)

**Problem** Verified wording: the distinct "No user found…" alert lets any
signed-in user probe arbitrary emails and usernames and learn which accounts
exist. Because the field accepts *email* — otherwise a filtered log param, i.e.
treated as private — this leaks the userbase's email membership one guess at a
time. (Usernames are public by design, so the email side is the real leak.)
**Fix** Return an indistinguishable outcome — e.g. always "If that person has an
account, they can now view your collection" (no-op on miss) — or accept only
usernames for granting.
**Verify** POST a known-bad and a known-good email; flash/response are identical.
**Related** Theme T-CODE-5; pairs with S-03.
**Status** open

### Low

#### C-07 · Duplication between the two search classes
**Severity** Low · **Effort** Medium · **Confidence** High
**Dimension** DRY / Duplicated Code (Fowler; Pragmatic Programmer)
**Locations**
- app/queries/collection_search.rb:47-49 vs app/queries/collectible_search.rb:107-109 (`results` is byte-identical: `matches.order(order_clause).distinct`)
- collectible_search.rb:104, 117-124 vs collection_search.rb:44, 56-63 (hand-rolled `@sort` allowlist + `order_clause` dispatch)
- collectible_search.rb:127-131 vs collection_search.rb:76-79 (identical `apply` token preamble)

**Problem** The `results` method, the sort-validation, and the token preamble are
each duplicated between the two subclasses of the very base class meant to hold
shared behaviour.
**Fix** Pull `results`, `@sort` validation, and the token preamble up into
`QuerySearch` as template-method scaffolding; subclasses keep only `apply` and
`order_clause`.
**Verify** Both subclasses inherit `results`; the preamble exists once.
**Related** Theme T-CODE-3; subject query classes. Rolls into C-05's single-source theme.
**Status** open

#### C-08 · "Intersect submitted values with an allowlist" idiom scattered
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Pragmatic DRY (knowledge duplication); connascence of Algorithm across modules
**Locations**
- app/controllers/collectibles_controller.rb:188-190 (`applicable_label_ids`) and :31-33 (inline duplicate)
- app/controllers/settings/labels_controller.rb:50 (`collectible_types & TYPES`)
- app/controllers/settings_controller.rb:27-29 (`& LINK_KEYS`)
- app/controllers/settings/sorting_controller.rb:12-13 (`& DEFAULT_OPTIONS`)

**Problem** Five sites implement "keep only submitted values that are in a frozen
allowlist", each slightly differently (some store the complement, some the
intersection). The sanitisation knowledge is scattered.
**Fix** A small shared helper/value object (`Allowlist.intersect` / `.complement`)
or push each onto the model that owns its domain.
**Verify** One definition of the intersect/complement logic.
**Related** Subject `collectibles_controller.rb`; rolls into C-06.
**Status** open

#### C-09 · Stringly-typed custom-sort criteria agreed across four files
**Severity** Low · **Effort** Medium · **Confidence** Medium
**Dimension** Primitive Obsession; connascence of Meaning/Algorithm across boundaries (`solid.md`)
**Locations**
- app/controllers/settings/custom_sorts_controller.rb:56-78 (build/validate)
- app/models/custom_sort.rb:28-74 (five hand-rolled validators + summary + order)
- app/queries/collectible_search.rb:77-85 (`custom_order`, which accepts *both* `"field"` and `:field` keys — a tell that no one owns the shape) and :117-124
- app/models/user.rb:73-74 (`custom_sort_orders`)

**Problem** The `[{ "field" =>, "direction" => }]` shape's meaning (valid fields,
directions, ordering) is agreed by convention across a controller, a model with
five validators, and two query methods. Changing the shape is Shotgun Surgery.
**Fix** A `SortCriteria` value object that parses-and-validates once
(parse-don't-validate) and yields the AR order hash and the summary; the five
`CustomSort` validators collapse into it.
**Verify** One place defines the shape; `custom_order` no longer accepts two key types.
**Related** Subject `custom_sort.rb`, `user.rb`; rolls into C-01.
**Status** open

#### C-10 · `assign_username` has a check-then-act race and O(n) probing
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Reliability — idempotency/uniqueness under concurrency; performance
**Locations**
- app/models/user.rb:132-144

**Problem** `while User.exists?(username: candidate)` is a TOCTOU race: two
concurrent registrations can both pass and then collide on the DB unique index,
which the model does not rescue — so a colliding sign-up 500s instead of retrying.
Each probe is also a round-trip.
**Fix** Rescue `ActiveRecord::RecordNotUnique` and retry with a fresh suffix,
relying on the unique index as the real guard.
**Verify** Concurrent creates from the same email base don't 500.
**Related** Subject `user.rb`; rolls into C-01.
**Status** open

#### C-11 · Username uniqueness is case-insensitive in the model, case-sensitive in the DB
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Reliability — validation/constraint mismatch; connascence of Algorithm (two places must agree on case-folding)
**Locations**
- app/models/user.rb:43-46 (`uniqueness: { case_sensitive: false }`) vs `index_users_on_username` (plain unique)
- app/controllers/settings/profile_accesses_controller.rb:6 (`LOWER(email)` lookup can't use `index_users_on_email`)

**Problem** The app promises case-insensitive uniqueness but the index would
permit "Ynda" alongside "ynda" if the model check were bypassed (import, raw
insert). Separately, the `LOWER(email)` grant lookup can't use the raw-value email
index, so it scans.
**Fix** Store a normalised (lowercased) username or add an expression unique index
on `lower(username)`; add a `lower(email)` index for the grant lookup.
**Verify** Inserting "YNDA" when "ynda" exists is rejected at the DB level.
**Related** Subject `user.rb`; rolls into C-01.
**Status** open

#### C-12 · Missing indexes on filtered/range search columns
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Performance — index filtered columns (`performance.md`)
**Locations**
- `db/schema.rb`: collectibles indexed on `title`, `type`, `user_id` only
- app/queries/collectible_search.rb:187-198 (`min_players`/`max_players` range), :143-157 (`system`/`author`/`notes` LIKE)

**Problem** `LIKE '%x%'` can't use a B-tree index anyway (leading wildcard), so
the substring filters full-scan regardless; the gap that matters is the
`min_players`/`max_players` range filters. Scoped by `user_id` first, so bounded
per collection — hence Low.
**Fix** Index `min_players`/`max_players` if range search is used at scale; for
substring search at scale, a trigram/FTS index (on Postgres) rather than B-tree.
**Verify** `EXPLAIN` a `players:>2` query uses an index once added.
**Related** Theme T-CODE-1; subject query classes.
**Status** open

#### C-13 · Bulk import is not idempotent
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Reliability — idempotency (`reliability.md`)
**Locations**
- app/controllers/collectibles_controller.rb:96-108 (`import_create`)

**Problem** The transaction is correct (all-or-nothing), and parsing rescues
malformed CSV/JSON to `[]` (good). But re-submitting the review form (double-click,
back-then-resubmit) creates duplicate collectibles — no natural key or dedup.
`parse_titles` de-dups within one paste, but nothing prevents re-importing the same
set.
**Fix** Optionally skip titles already present of that type, or rely on
POST-redirect-GET plus a client-side submit disable. Low, since it's a deliberate
create.
**Verify** Submit the same review twice; decide whether dupes are acceptable.
**Related** Subject `collectibles_controller.rb`; rolls into C-06.
**Status** open

#### C-14 · `Pagination` runs COUNT eagerly in the constructor
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Performance; connascence of execution / temporal coupling
**Locations**
- app/models/pagination.rb:8-13 (`@total = scope.count`)

**Problem** Building a `Pagination` always fires a COUNT, even for a caller that
only wants `records`; on the profile page the relation carries `.distinct` and
id-subqueries, so it's a non-trivial `COUNT(DISTINCT …)`. The object can't be
constructed without a DB round-trip.
**Fix** Memoise `total`/`pages` lazily so reading only `.records` pays nothing.
**Verify** Instantiate and read only `.records` — no COUNT fires.
**Related** Subject `pagination.rb`.
**Status** open

#### C-15 · `ORDER BY RANDOM()` sorts the whole collection to pick one row
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Performance — full sort to pick one row; readability
**Locations**
- app/controllers/root_controller.rb:19-21

**Problem** `own.where.not(id: @newest_collectible).order(Arel.sql("RANDOM()")).first`
sorts the full collection to pick one random row — fine at personal scale (the
comment says so), index-defeating as it grows. The `where.not(id: nil-when-empty)`
guard is correct only by accident (empty collection → `.first` is nil anyway).
**Fix** For a random row, `offset(rand(count))` after a cheap count; or keep
RANDOM() and comment the size assumption.
**Verify** n/a (design note).
**Related** Subject `root_controller.rb`.
**Status** open

#### C-16 · Dense "is this field set?" conditional
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Clarity (Fowler — unclear conditional)
**Locations**
- app/models/collectible.rb:84-90 (`set = [true,false].include?(value) ? value == true : value.present?`)

**Problem** The rule ("a boolean counts as set only when true; other types when
present") is correct — the second pass independently confirmed it — but dense, and
couples the validation to column types.
**Fix** Extract a `field_set?(value)` predicate with an intent-revealing name.
**Verify** n/a (clarity).
**Related** Subject `collectible.rb`.
**Status** open

#### S-03 · Devise `paranoid` off — password reset enumerates emails (unauthenticated)
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** OWASP A07 (CWE-204)
**Locations**
- config/initializers/devise.rb:97 (`# config.paranoid = true`, verified commented)

**Problem** With `paranoid` off, the recoverable flow differs on hit vs miss, so
registered emails can be enumerated at the *unauthenticated* boundary — feeding
credential-stuffing lists. Pairs with S-04 for reliable two-endpoint enumeration.
**Fix** `config.paranoid = true`; confirm the reset view shows a generic "if it exists…".
**Verify** Reset requests for an existing and a non-existent email produce
identical responses.
**Related** Theme T-CODE-5; pairs with S-04.
**Status** open

#### S-05 · 404-vs-403 existence oracle on collectible show
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** OWASP A01 Broken Access Control (CWE-203 information exposure through discrepancy)
**Locations**
- app/controllers/collectibles_controller.rb:146-157 (`set_collectible` runs `@profile.collectibles.find(params[:id])` before the visibility check)

**Problem** For a private profile the viewer can't see, a *real* collectible id
renders `private_profile` with 403 while a *missing* id raises `RecordNotFound` →
404. The discrepancy lets an unauthorised viewer enumerate which collectible ids
exist in a private collection. Value is limited (ids are global integers), hence
Low. (Contrast `set_owned_collectible` at :166, which is correctly ownership-scoped
through `current_user`.)
**Fix** Check `@profile.visible_to?` *before* loading the collectible and return a
uniform status/body for present-but-forbidden and absent alike (don't `find` on the
forbidden branch).
**Verify** For a private profile you can't see, a valid and an invalid id return
the same status and body.
**Related** Subject `collectibles_controller.rb`; rolls into C-06.
**Status** open

#### S-06 · Unescaped LIKE wildcards in every text search
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** OWASP A03 (not SQLi — parameterised — but user-controlled LIKE metacharacters); `performance.md` scan cost
**Locations**
- app/queries/query_search.rb:45-52 (`match_like`, `"%#{value}%"`)
- app/queries/query_search.rb:58-67 (`match_any_like`)
- app/queries/collectible_search.rb:226 (`match_label`)

**Problem** `value` goes into the LIKE pattern unescaped. It's bound (no SQLi), but
the user's `%`/`_` act as wildcards: `title:%` matches everything, `_` matches any
char — incorrect matching, and a cheap way to force `LIKE '%%'` full scans on
unindexed `notes`.
**Fix** `ActiveRecord::Base.sanitize_sql_like(value)` before wrapping in `%…%`, with
`ESCAPE '\'` where needed; centralise in the two `QuerySearch` helpers so both
searches inherit it.
**Verify** Searching `title:50%` matches only titles containing "50%".
**Related** Theme T-CODE-3; subject query classes.
**Status** open

#### S-07 · Raw-SQL fragments safe only by upstream convention
**Severity** Low · **Effort** Medium · **Confidence** Medium
**Dimension** Secure design / economy of mechanism; connascence of Meaning across files
**Locations**
- app/queries/collection_search.rb:67-73 (`count_order` interpolates `#{type}`) and :128 (`"COUNT(*) #{op} #{n}"` HAVING)
- app/queries/collectible_search.rb:176-197 (player-bound SQL with interpolated column/op/int)
- app/queries/query_search.rb:72-79 (`numeric_bounds` — the trust anchor)

**Problem** Safe *today* only because every interpolated token is proven upstream
(frozen alias map, fixed operator set, `.to_i`). Both passes falsified the SQLi
reading — it is **not** a live vulnerability. But the safety is an invariant held by
convention across four files, not by the type system: one future caller passing an
unvalidated column into the player-bound builder, or a new sort key reaching
`count_order`, turns it into injection.
**Fix** Build these with Arel / bind parameters where possible (HAVING accepts
binds; the correlated count can be an Arel node), or add an assertion at the point
of interpolation (`raise unless COUNT_SORTS.value?(type)`).
**Verify** No user-derived string reaches a SQL fragment without a bind or an
allowlist assertion at the interpolation site.
**Related** Theme T-CODE-3; subject query classes.
**Status** open

#### S-08 · 2FA not enforced before setup completes
**Severity** Low · **Effort** Medium · **Confidence** Medium
**Dimension** OWASP A07; Saltzer & Schroeder fail-safe defaults
**Locations**
- app/controllers/application_controller.rb:27-34 (`ensure_2fa_setup` — a soft redirect, skipped for devise/setup controllers)
- app/controllers/users/sessions_controller.rb (challenge skipped when `consumed_timestep` nil)

**Problem** A user with `otp_required_for_login` true but `consumed_timestep` nil
(not yet set up) gets a full authenticated session on sign-in, gated only by a soft
redirect to setup — not by authorization. The window between "password verified"
and "2FA configured" is a fully signed-in session. Whether that's acceptable is a
product call, but it means 2FA is not enforced as a hard second factor for
never-set-up users.
**Fix** If 2FA is mandatory, don't establish a full session until setup completes
(a pending/setup scope), or restrict what a not-yet-2FA session may do.
**Verify** A newly registered user without OTP configured cannot reach any
non-setup authenticated action.
**Related** Theme T-CODE-5.
**Status** open

## Themes

### T-CODE-1 · View-triggered N+1
**Members** C-02, C-03 (and C-12 as the index side). **Root** set/aggregate work
done inside a partial that renders once per row — `.ordered` re-querying an
eager-loaded association, and a grouped COUNT per collection. **Leverage** Both are
"do it once in the controller/DB": preloading labels-in-Ruby and a single grouped
count dissolve every per-row query on the two busiest list pages. A controller-only
reading misses both; they are only visible from the template.

### T-CODE-2 · Type dispatch outside the STI hierarchy
**Members** C-04. **Root** the subclasses exist but presentation/serialisation ask
`is_a?`/`case` instead of the object. **Leverage** moving behaviour onto the
subclasses removes every switch at once and makes a fourth type a single-file change.

### T-CODE-3 · Knowledge with no single owner
**Members** C-05, C-07, C-08, C-09, S-06, S-07. **Root** the collectible roster,
the type-alias map, the sort-criteria shape, the allowlist-intersect idiom, and the
LIKE/raw-SQL safety invariants are each agreed by convention across 3-9 files rather
than encapsulated. **Leverage** a single source per concept (one roster descriptor,
one `TYPE_ALIASES`, one `SortCriteria`, one LIKE helper) collapses a whole class of
Shotgun-Surgery and latent-safety findings together.

### T-CODE-4 · Responsibilities accreting on two hubs
**Members** C-01, C-06. **Root** `User` and `CollectiblesController` each collect
4-5 axes; the security-critical `visible_to?` and the import wizard are buried among
unrelated concerns. **Leverage** extracting a visibility policy and an import
controller/factory de-risks the two files most findings converge on.

### T-CODE-5 · Security is strong in the domain, default-off at the platform
**Members** S-01, S-02, S-03, S-04, S-08. **Root** the *domain* access control
(ownership scoping, `visible_to?`, CSPRNG tokens) is careful and correct; the gaps
are platform defaults left off — rate limiting, TLS/CSP/HSTS, enumeration
hardening, hard 2FA enforcement. **Leverage** these are mostly small config edits
with high impact, and cluster naturally into one hardening task before production.

## Subject grid

| Subject | Dimensions (finding IDs) | # | Severity | Interpretation |
|---------|--------------------------|---|----------|----------------|
| user.rb | C-01, C-09, C-10, C-11 | 4 | High | God Object: identity + social graph + visibility policy + preferences (convergence gate) |
| collectibles_controller.rb | C-06, C-08, C-13, S-05 | 4 | High | God Controller: owned CRUD + public show/gating + import wizard + CSV template + STI/label domain logic (convergence gate) |
| query_search.rb / collectible_search.rb / collection_search.rb | C-07, C-12, S-06, S-07 | 4 (collectively) | Low | **Not** a God Object: all four facets serve the single search-building responsibility, so they are cohesive. The finding is the *duplication between* the two subclasses (C-07), not accretion within one. Evidence for the downgrade: each class has one reason to change (its model's query mapping); the raw-SQL/LIKE items are properties of query-building, not separate responsibilities. |
| collectible_exporter.rb / collectibles_helper.rb | C-04, (C-03 in helper) | 2 | Medium | Type-switch presentation logic that wants to live on the subclasses |
| collectible.rb (+ params/importer/exporter roster) | C-05, C-16 | 2 | Medium | The roster's canonical home, but the roster leaks to 8+ sites |
| _collectible.html.erb / show.html.erb | C-02 | 1 | Medium | N+1 from a per-row scope call |
| _profile_row.html.erb / collectibles_helper.rb | C-03 | 1 | Medium | N+1 grouped count per row |
| custom_sort.rb | C-09 | 1 | Low | Five hand-rolled validators for an unowned format |
| pagination.rb | C-14 | 1 | Low | Eager COUNT / temporal coupling |
| root_controller.rb | C-15 | 1 | Low | RANDOM() full sort |
| production.rb / CSP / devise.rb | S-01, S-02, S-03, S-08 | (config) | — | Platform hardening default-off |
| profile_accesses_controller.rb | S-04 | 1 | Medium | Enumeration oracle |

Convergence rule: a subject at 3+ distinct dimensions gets its own finding at High
or higher, naming the responsibilities; prose cannot lower that floor without
evidence. `user.rb` and `collectibles_controller.rb` cross the gate → C-01, C-06 at
High. The search-class cluster is held below the floor with the stated evidence
(single responsibility, facets not axes), not a cohesion impression.

## Leverage-ordered fix list

1. Preload labels (sort in Ruby) and a single grouped count → dissolves C-02, C-03; touches C-12's index side (2-3). Effort Small.
2. Extract a `ProfileVisibility` policy + a preferences object off `User` → dissolves C-01, C-09, C-10, C-11 (4). Effort Large.
3. Split the import wizard out of `CollectiblesController` and move `build_collectible`/`applicable_label_ids` to the model/factory → dissolves C-06, C-08, C-13, S-05 (4). Effort Large.
4. Add `rate_limit` (and/or Devise `:lockable`) to sign-in + both 2FA actions → dissolves S-01 (1). Effort Medium.
5. Single-source the collectible roster + one `TYPE_ALIASES` + push type behaviour onto subclasses → dissolves C-04, C-05, C-07 (3). Effort Medium.
6. Production hardening pass: `force_ssl`, CSP, HSTS, `hosts`, `paranoid = true` → dissolves S-02, S-03 (2). Effort Small.
7. Centralise a `sanitize_sql_like` helper + Arel/bind the raw-SQL fragments → dissolves S-06, S-07 (2). Effort Medium.
8. Neutralise the access-grant enumeration message → dissolves S-04 (1). Effort Small.

## Credits

Each was falsified before being written (per `rigour.md`).

- **Domain access control is genuinely careful.** `User#visible_to?` (user.rb:104-112)
  and `visible_to_viewer` (:89-95) enforce public/owner/shared/token in one place
  with fail-closed defaults; every owner-mutation action loads through
  `current_user.*` (`set_owned_collectible`, all Settings controllers,
  `require_own_profile`). Falsified by listing every mutation site — none loads a
  resource by bare id. Both passes independently confirmed no IDOR.
- **Mass-assignment discipline is thorough.** Every multi-select is intersected
  against a frozen constant (link keys, types, sorts, label ids), verified at
  settings_controller.rb:27, labels_controller.rb:50, sorting_controller.rb:12,
  collectibles_controller.rb:188. (The *duplication* of that idiom is C-08; the
  safety itself holds.)
- **STI/type inputs are allowlisted before `constantize`.** `Collectible.model_for`
  gates on the frozen `TYPES` (collectible.rb:54-58), so no arbitrary class
  instantiation via `:type`. Falsified by tracing the import path — `sti_class_for`
  only ever sees allowlisted names.
- **Share-link tokens are sound.** `SecureRandom.urlsafe_base64(16)` (128-bit CSPRNG,
  share_link.rb:18) with an `active` expiry scope enforced in `visible_to?`.
  Falsified the "guessable/expired" cases.
- **The `QuerySearch` base/subclass split is a clean Template Method.** The parser and
  AND/OR/negation evaluation live once in the base; subclasses supply `apply` +
  ordering. Worth keeping — the caveats are the raw-SQL invariants (S-07) and the
  residual duplication (C-07), not the structure.
- **Log-parameter filtering covers the sensitive set** (`:otp`, `:token`, `:secret`,
  `:email`), verified in filter_parameter_logging.rb — which is *why* S-04's email
  leak matters (email is treated as private elsewhere).
- **Falsified non-credit:** "N+1 avoided via `includes(:labels)`" was *not* claimed —
  C-02 shows `.ordered` defeats it from the template.
- **Falsified non-credit:** `Collectible#only_applicable_fields_set` was checked as a
  suspected bug and found correct (C-16 is clarity only, not a defect).
