# Code-craft review — Collection (v11)

**Lens** code craft (correctness + security run as separate passes).
**Scope** `app/`, `lib/`, `config/`. **Excluded** tests (prototype branch, per
brief), `db/migrate` beyond indexes, front-end JS (none of substance).
**Depth** exhaustive. **Execution** inline, **2 independent passes** (my own pass
+ one fresh critic agent), diffed and reconciled against the code.
**Date** 2026-08-13. **Commit** `0a2078c` (branch `prototype`).

Sidecar: `code_craft_review_v11.coverage.md` (censuses, per-template N+1 trace,
dimension searches). Every attestation below points at it.

## Coverage caveat

A review samples a larger space than any one pass can cover, so gaps are likely —
including high-severity ones. Two independent passes were run and merged here,
which raises coverage above a single pass but does not make it complete. Treat the
absence of a finding as "not surfaced", not "confirmed clean". A third fresh pass
remains the most reliable way to raise coverage further.

This is unusually clean prototype code: thin controllers, a genuinely
well-factored `QuerySearch` base/subclass split, owner-scoped loading on every
mutation, and request-level memoisation that pre-empts several N+1s. The findings
cluster around four roots: STI behaviour that leaked out of the models into
helpers/exporter/views (T1); view-layer N+1s where an aggregate or association
scope defeats the loader (T2); reveal-before-authorize response oracles (T3); and
duplicated domain knowledge across layers (T4).

## Findings index

| ID | Severity | Effort | Dimension | Location | Title | Status |
|----|----------|--------|-----------|----------|-------|--------|
| C-01 | High | Large | God Class / SRP (Metz) | user.rb | `User` is a God Object | open |
| C-03 | High | Small | N+1 from view (Fowler/perf) | collectibles_helper.rb:5 + _profile_row.erb:12 | Per-collection grouped count | open |
| C-04 | High | Small | N+1: scope defeats preload | _collectible.erb:24, show.erb:36 | `labels.ordered` re-queries per row | open |
| C-02 | Medium | Medium | Repeated Switch (Fowler) | _form.erb, _import_fields.erb, collectibles_helper.rb, collectible_exporter.rb | STI type-switch ×4 | open |
| C-05 | Medium | Small | N+1 from view | labels/index.erb:40 | `label.collectibles.size` per row | open |
| C-06 | Medium | Small | Duplicated Code / Connascence | collectible_search.rb:87, collectible_importer.rb:14 | `TYPE_ALIASES` duplicated & drifted | open |
| C-07 | Medium | Small | Access control (OWASP A01/CWE-203) | collectibles_controller.rb:146-157 | Collectible existence oracle (404 vs 403) | open |
| C-08 | Medium | Small | Enumeration (OWASP A07/CWE-204) | profile_accesses_controller.rb:5-22 | User-enumeration + name disclosure | open |
| C-09 | Medium | Small | Injection (OWASP A03 / CSV) | collectible_exporter.rb:16-40 | CSV formula injection | open |
| C-10 | Medium | Small | Connascence of Algorithm | user.rb:89-112 | Visibility rule encoded twice | open |
| C-11 | Medium | Medium | Divergent Change / fat controller | collectibles_controller.rb:51-142 | Import pipeline in resource controller | open |
| C-15 | Medium | Small | Misconfig (OWASP A05) | content_security_policy.rb | No CSP shipped | open |
| C-12 | Low | Medium | Divergent Change | collectible.rb:5-104 | Model owns link-URL formatting | open |
| C-13 | Low | Small | LIKE-wildcard correctness | query_search.rb:45-67, collectible_search.rb:226 | `%`/`_` unescaped in LIKE | open |
| C-14 | Low | Small | Injection surface | collection_search.rb:67-73 | Type interpolated into raw SQL | open |
| C-16 | Low | Small | Misconfig (OWASP A05) | production.rb:24-66 | SSL/HSTS/hosts commented | open |
| C-17 | Low | Small | Auth invariant / connascence | sessions_controller.rb:5, application_controller.rb:27 | 2FA gate spread across two files | open |
| C-18 | Low | Small | Redundant query | sorting/show.erb:30-32, root_controller.rb:19-33 | Repeated/needless queries | open |
| C-19 | Low | Small | Primitive Obsession | collectible.rb:84-90 | Field-set predicate juggling | open |
| C-20 | Low | Small | Cohesion / Feature Envy | application_controller.rb:12-38 | Base controller holds 3 concerns | open |

## Findings

### High

#### C-01 · `User` is a God Object
**Severity** High · **Effort** Large · **Confidence** High
**Dimension** God Class / Single Responsibility (Metz; Fowler Divergent Change)
**Locations**
- app/models/user.rb:1-8 (`devise` auth)
- app/models/user.rb:132-144 (`assign_username`), :77-83 (`to_param`, `name`)
- app/models/user.rb:15-36, 98-100 (social graph, `following?`)
- app/models/user.rb:89-95, 104-112 (`visible_to_viewer`, `visible_to?`)
- app/models/user.rb:56-75, 116-129 (sort/link preferences + 3 validators)
**Problem** Five-plus app-authored axes on one class — auth, identity, social
graph, visibility policy, and view/sort preferences — each with its own reason to
change. It is the subject-grid hotspot (converges with C-10, C-20, and the C-03
count query it hosts via `collectibles`). Describing it needs several "ands",
which is the God Object tell, not the class's length.
**Fix** Extract collaborators: a `CollectionVisibility` policy object owning
`visible_to?` + `visible_to_viewer` together (dissolves C-10), and a
`SortPreferences` / `LinkPreferences` value object for the dropdown/link logic
(also home for `viewer_link_keys`, C-20), leaving `User` as identity + auth.
Composition over accretion.
**Verify** `User`'s public-method count and the count of distinct foreign
constants it references (`CollectibleSearch::…`, `CollectionSearch::…`,
`Collectible::LINK_KEYS`) both drop; each extracted concern has one reason to
change.
**Related** Theme T4; subject user.rb (4 dims). #2 on the fix list.
**Status** open

#### C-03 · N+1: per-collection grouped count on three homepage lists and the index
**Severity** High · **Effort** Small · **Confidence** High
**Dimension** N+1 triggered from the view layer (Fowler; performance)
**Locations**
- app/helpers/collectibles_helper.rb:5-13 (`collectible_counts` → `user.collectibles.group(:type).count`)
- app/views/profiles/_profile_row.html.erb:12 (calls it per row)
- app/views/collections/index.html.erb:15-17 (renders the row, paginated 15)
- app/views/root/_collection_list.html.erb:4-6 (renders it for `@recent`, `@followed`, `@shared` — 3 lists on the homepage)
**Problem** Every collection row fires its own `GROUP BY type` COUNT. The homepage
renders three such lists plus the index paginates 15 rows, so a busy page runs
15+ extra queries. It can't be fixed with `includes` (it's an aggregate) and no
controller precomputes it.
**Fix** Compute per-user type counts in one query up front —
`Collectible.where(user_id: ids).group(:user_id, :type).count` in the controller,
passed to the partial as a hash — or a counter cache.
**Verify** With N collections on a page, the query log shows one grouped count,
not N.
**Related** Theme T2; subjects collectibles_helper.rb, _profile_row.erb. #1 on the fix list.
**Status** open

#### C-04 · N+1: `labels.ordered` in the card partial defeats `includes(:labels)`
**Severity** High · **Effort** Small · **Confidence** High
**Dimension** N+1 — association scope invoked on an already-loaded association
(performance; the canonical "eager-load defeated in the template" case)
**Locations**
- app/views/collectibles/_collectible.html.erb:22-24 (`labels.any?` then `labels.ordered.each`)
- app/views/collectibles/show.html.erb:34-36 (same)
- app/views/collectibles/_import_fields.html.erb:72, _form.html.erb:67 (`current_user.labels.ordered` re-run per item)
**Problem** `ProfilesController#show` does `@search.results.includes(:labels)`
(profiles_controller.rb:35), but the card partial calls `collectible.labels.ordered`
— an association *scope* (`order(:name)`) that issues a fresh query per card,
bypassing the preload. The eager-load reads correct at the controller and is
silently defeated in the view. In `_import_fields`, `current_user.labels.ordered`
re-runs for every reviewed item.
**Fix** Sort in Ruby on the loaded association
(`collectible.labels.sort_by { |l| l.name.downcase }`) so the preload is used, or
hoist `current_user.labels.ordered` out of the loop into one local. Never call an
association scope inside a per-row loop.
**Verify** Query log on a cards page shows one `labels` load, not one per card;
`grep -rn 'labels.ordered' app/views` returns no per-row contexts.
**Related** Theme T2; subject _collectible.erb. #1 on the fix list.
**Status** open

### Medium

#### C-02 · Repeated STI type-switch instead of polymorphism
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** Switch Statements / Replace Conditional with Polymorphism (Fowler);
Duck Typing (Metz)
**Locations**
- app/helpers/collectibles_helper.rb:38-47 (`collectible_subtitle` — `when VideoGame/BoardGame/Book`)
- app/services/collectible_exporter.rb:64-86 (`type_specific` — same three-way switch)
- app/views/collectibles/_form.html.erb:25-65 (`is_a?` chain)
- app/views/collectibles/_import_fields.html.erb:18-69 (`is_a?` chain)
**Problem** The same "what kind of collectible is this" dispatch is written four
times, though the STI subclasses already exist (they own `applicable_fields` /
`applicable_link_keys`, but not their presentation/serialisation counterparts).
Each new type or field change is Shotgun Surgery across a helper, a service, and
two templates.
**Fix** Give each subclass a `subtitle` / `export_attributes` method (and a
`form_fields` descriptor the templates iterate). The exporter's `type_specific`
becomes `collectible.export_attributes`.
**Verify** `grep -rnE 'when VideoGame|is_a\?\(VideoGame' app` returns only the
subclass definitions, not call sites.
**Related** Theme T1; subjects collectibles_helper.rb, collectible_exporter.rb. #3 on the fix list.
**Status** open

#### C-05 · N+1: `label.collectibles.size` per label row
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** N+1 from the view (performance)
**Locations**
- app/views/settings/labels/index.html.erb:40 (`label.collectibles.size`)
- app/controllers/settings/labels_controller.rb:7 (loads labels with no count preload)
**Problem** `.size` on an unloaded `has_many :through` fires a COUNT per label; a
user with many labels gets one query per row.
**Fix** Load counts once — a counter cache, or
`left_joins(:collectible_labels).group(:id).select('labels.*, COUNT(...) AS c')`.
**Verify** Query log shows one count/load for the label list, not one per label.
**Related** Theme T2. #1 on the fix list.
**Status** open

#### C-06 · `TYPE_ALIASES` roster duplicated across two files (already drifted)
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Duplicated Code / DRY (Fowler; Pragmatic Programmer); Connascence of Value
**Locations**
- app/queries/collectible_search.rb:87-94 (`TYPE_ALIASES`)
- app/services/collectible_importer.rb:14-18 (`TYPE_ALIASES`)
- app/queries/collection_search.rb:135 (reuses the *search* copy, not the importer's)
**Problem** Two independent alias tables encode the same knowledge and have
already diverged in shape; `CollectionSearch` reaches into `CollectibleSearch`'s
copy. A new alias must be added in two places or search and import silently differ.
**Fix** One authoritative alias map (e.g. on `Collectible` alongside `TYPES`),
referenced by both search and importer.
**Verify** `grep -rn 'TYPE_ALIASES =' app` returns a single definition.
**Related** Theme T4. #4 on the fix list.
**Status** open

#### C-07 · Existence oracle: private collectible reveals whether an id exists (404 vs 403)
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Broken access control — reveal-before-authorize (OWASP A01; CWE-203)
**Locations**
- app/controllers/collectibles_controller.rb:146-157 (`set_collectible` — `@profile.collectibles.find(params[:id])` runs *before* `visible_to?`)
**Problem** For a private collection, a non-viewer requesting an existing
collectible id gets the 403 `private_profile` page, but a non-existent id raises
`RecordNotFound` (404). The response differs on hit vs miss, so an attacker can
enumerate which collectible ids exist in a collection they can't see.
**Fix** Check `@profile.visible_to?(current_user, token:)` and render the 403
page *before* calling `.find`; only look up the collectible once access is
confirmed (fail-safe defaults).
**Verify** For a private collection, an existing and a non-existing id return the
same 403 response to a non-viewer.
**Related** Theme T3. #4 on the fix list.
**Status** open

#### C-08 · User-enumeration + name disclosure on the "grant access" lookup
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Identification failures — enumeration oracle (OWASP A07; CWE-204)
**Locations**
- app/controllers/settings/profile_accesses_controller.rb:5-22
**Problem** Looking someone up by email-or-username returns "No user found with
that email or username." on a miss versus "#{viewer.name} can now view your
collection." (echoing the target's display name) on a hit. Any signed-in user can
probe whether an arbitrary email is registered and learn its account name.
Secondary: the `OR` match lower-cases both arms, so a username stored with capitals
won't match (minor correctness).
**Fix** Return an identical, neutral confirmation regardless of hit/miss ("If that
account exists, they now have access") and don't echo the looked-up name; keep the
two lookup arms case-consistent with how each column is stored.
**Verify** Response and status are identical for a registered vs unregistered
identifier.
**Related** Theme T3. #4 on the fix list.
**Status** open

#### C-09 · CSV formula injection in the export
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Injection — CSV/formula injection (OWASP A03; CWE-1236)
**Locations**
- app/services/collectible_exporter.rb:16-40 (`to_csv` writes `title`, `system`, `author`, `notes`, label names raw)
**Problem** User-controlled fields are written to CSV verbatim. A title like
`=HYPERLINK("http://evil","click")` or `=cmd|…` executes as a formula when the
exported file is opened in Excel/Sheets. The victim is whoever opens the export
(the owner, or a recipient of a shared export).
**Fix** Prefix any value beginning with `= + - @` (and tab/CR) with a single
quote, or wrap such cells, before writing — the standard CSV-injection
neutralisation. Apply in `to_csv` for every user-sourced column.
**Verify** Exporting a collectible titled `=1+1` yields a cell that opens as text,
not `2`.
**Related** Theme T3 (adjacent — untrusted data crossing a boundary). #6 on the fix list.
**Status** open

#### C-10 · Visibility rule encoded twice — connascence of algorithm
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Duplicated knowledge / Connascence of Algorithm (Pragmatic DRY; Page-Jones)
**Locations**
- app/models/user.rb:89-95 (`self.visible_to_viewer` — set/scope form)
- app/models/user.rb:104-112 (`visible_to?` — single-record predicate)
**Problem** The same policy (public OR self OR shared-via-ProfileAccess OR
share-token) is expressed two ways that must stay in lockstep — but the scope
omits the share-token branch (it can't know a token), so "collections you can see"
and "can you see this collection" already disagree for token holders.
**Fix** Consolidate into a `CollectionVisibility` policy object owning both forms
(pairs with C-01); at minimum cross-reference them and document the token
asymmetry.
**Verify** One place defines the branches; a sharing-rule change touches a single method.
**Related** Theme T4; subject user.rb. #2 on the fix list.
**Status** open

#### C-11 · Import pipeline lives in the resource controller (Divergent Change)
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** Divergent Change / fat controller (Fowler; Metz)
**Locations**
- app/controllers/collectibles_controller.rb:51-142 (`import`, `import_review`, `import_create`, `import_format`, `infer_format`, `import_content`, `import_items_params`)
**Problem** Beyond CRUD the controller owns format inference (extension sniffing),
content extraction, a bespoke nested-params permit, and the 3-step review/create
orchestration — a second responsibility with its own reasons to change bolted onto
the resource controller. `infer_format`/`import_content` are Feature Envy over `params`.
**Fix** Extract a `CollectibleImport` form/command object taking the raw params
and owning format inference, content extraction, and the permitted-attribute
roster; the controller calls it and renders.
**Verify** Import methods no longer reference `params[:file]`/`params[:data_format]`
directly; `grep -c 'def ' collectibles_controller.rb` drops.
**Related** Subject collectibles_controller.rb (2 dims, with C-07). #5 on the fix list.
**Status** open

#### C-15 · No Content Security Policy shipped
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Security misconfiguration (OWASP A05)
**Locations**
- config/initializers/content_security_policy.rb:1-29 (entirely commented generator stub)
- app/views/layouts/application.html.erb:10 (`csp_meta_tag` with no policy behind it)
- app/controllers/two_factor_authentication/setup_controller.rb:27 (`…as_svg.html_safe` inline SVG)
**Problem** The app renders inline SVG (`html_safe`) and user-supplied fields
(titles, notes, labels, display names) throughout, with no CSP as defence-in-depth
against XSS. The initializer is the untouched generator stub.
**Fix** Define a real policy (`default-src :self`, image/style as needed,
`object-src :none`) and confirm the QR SVG passes under it.
**Verify** Production responses carry a `Content-Security-Policy` header.
**Related** Theme T5. #7 on the fix list.
**Status** open

### Low

#### C-12 · `Collectible` model owns external-link URL formatting
**Severity** Low · **Effort** Medium · **Confidence** Medium
**Dimension** Divergent Change; Information Hiding (Fowler; Ousterhout)
**Locations**
- app/models/collectible.rb:5-16 (`LINK_DEFINITIONS`), :94-104 (`search_links` — `CGI.escape` + `format` + sort)
**Problem** URL-templating/formatting of external search links is presentation
logic on the persistence model; it changes for a link-catalogue reason unrelated
to collectible domain rules.
**Fix** Extract a `SearchLinks` value object owning the catalogue and formatting;
`Collectible#search_links` delegates.
**Verify** `grep -n 'format(\|CGI.escape' app/models/collectible.rb` returns nothing.
**Related** Theme T1; subject collectible.rb. #3 on the fix list.
**Status** open

#### C-13 · LIKE searches don't escape `%`/`_` wildcards
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Correctness in a security-shaped line (the "parameterised yet still wrong" LIKE trap)
**Locations**
- app/queries/query_search.rb:45-52 (`match_like`), :58-67 (`match_any_like`)
- app/queries/collectible_search.rb:226 (`match_label` — `"%#{value}%"`)
**Problem** Values are bound parameters (injection-safe), but `%` and `_` inside a
search term act as SQL wildcards: `title:100_000` matches `100X000`; a lone `%`
matches everything. A correctness surprise, not a security hole.
**Fix** Escape `%`, `_`, and the escape char before wrapping, and add `ESCAPE`, or
use `sanitize_sql_like`.
**Verify** A search for a literal `_` returns only rows containing `_`.
**Related** #7 on the fix list.
**Status** open

#### C-14 · Type interpolated into raw SQL in the count subquery
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Injection surface / secure design (OWASP A03)
**Locations**
- app/queries/collection_search.rb:67-73 (`count_order` — `collectibles.type = '#{type}'`)
**Problem** `type` is string-interpolated into `Arel.sql`. Safe today (always a
whitelisted `COUNT_SORTS` value) but an injection sink one careless caller away,
and a broken-window pattern.
**Fix** Use a bound parameter / `sanitize_sql_array`, or express the count via an
Arel/`.where(type:).group` construct with no string interpolation.
**Verify** `grep -n "'#{" app/queries/collection_search.rb` returns nothing.
**Related** #7 on the fix list.
**Status** open

#### C-16 · Production SSL/HSTS and host-authorization left commented
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Security misconfiguration (OWASP A05)
**Locations**
- config/environments/production.rb:24-31 (`assume_ssl`, `force_ssl`, `ssl_options`), :59-66 (`config.hosts`)
**Problem** As written, production does not force HTTPS, set HSTS, mark cookies
secure, or protect against DNS-rebinding/Host-header attacks. May be deliberate
(SSL terminated elsewhere) but should be a conscious decision.
**Fix** Enable `force_ssl`/`assume_ssl` behind the real proxy and set
`config.hosts`, or record why not.
**Verify** Production responses carry `Strict-Transport-Security`; cookies `Secure`.
**Related** Theme T5. #7 on the fix list.
**Status** open

#### C-17 · 2FA enforcement invariant spread across two controllers
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Secure design / reliability of an auth invariant (OWASP A07; Design by Contract)
**Locations**
- app/controllers/users/sessions_controller.rb:5 (`otp_required_for_login && consumed_timestep.present?`)
- app/controllers/application_controller.rb:27-34 (`ensure_2fa_setup` — challenges when `consumed_timestep.blank?`)
**Problem** The "can this user reach protected pages with 2FA half-set-up" invariant
rests on two controllers independently agreeing about `consumed_timestep`, with no
single assertion. Coherent today, fragile connascence on an auth-critical flag.
**Fix** Centralise the decision in one `User` predicate (`two_factor_pending?` /
`two_factor_active?`) used by both sites; document the invariant. No behaviour change.
**Verify** `grep -rn 'consumed_timestep' app/controllers` returns only via that predicate.
**Related** Theme T4. #7 on the fix list.
**Status** open

#### C-18 · Repeated / needless queries (custom sorts twice; homepage 5 queries)
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Redundant query / query patterns (performance)
**Locations**
- app/views/settings/sorting/show.html.erb:30,32 (`custom_sorts.ordered` evaluated twice)
- app/controllers/root_controller.rb:19-33 (5 sequential queries; `where.not(id: @newest_collectible)` relies on `IS NOT NULL` in the empty case)
**Problem** `custom_sorts.ordered.any?` then `.each` runs the query twice. The
homepage fires 5 sequential queries and the random-pick line's correctness rides
on a coincidence of the empty case (not a live bug — re-traced in the sidecar).
**Fix** Assign the sorts to a local; guard the random pick explicitly
(`… if @newest_collectible`).
**Verify** One `custom_sorts` query for the page; the nil case reads explicitly.
**Related** Theme T2. #1 on the fix list.
**Status** open

#### C-19 · `only_applicable_fields_set` primitive juggling
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Primitive Obsession / clarity (Fowler)
**Locations**
- app/models/collectible.rb:84-90 (`set = [true, false].include?(value) ? value == true : value.present?`)
**Problem** Inlines "is this optional field meaningfully set" with a
boolean-vs-other special case; subtle (a `false` boolean counts as unset).
**Fix** Extract a named `field_set?(value)` predicate stating the rule.
**Verify** The validation reads as one intent-named predicate.
**Related** Subject collectible.rb. 
**Status** open

#### C-20 · `ApplicationController` holds three unrelated concerns
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Cohesion / Feature Envy (Metz; Fowler)
**Locations**
- app/controllers/application_controller.rb:12-38 (`paginate`, `viewer_link_keys`, `ensure_2fa_setup`)
**Problem** Pagination plumbing, link-visibility *domain policy*, and the 2FA gate
are three concerns on the base class. `viewer_link_keys` knows
`hide_links_on_others?`/`visible_link_keys` — Feature Envy over `User`.
**Fix** Move `viewer_link_keys` onto `User`/the link-preference object (pairs with
C-01); keep `paginate` and the 2FA gate as concerns if the base grows. Low
priority while small.
**Verify** `ApplicationController` references no `User` preference methods directly.
**Related** Theme T4; subject user.rb (target). #2 on the fix list.
**Status** open

## Themes

### T1 · STI behaviour that leaked out of the models
**Members** C-02, C-12 (and the alias half of C-06). **Root** subclasses own
their fields/links but not their presentation, serialisation, or alias knowledge,
so type-specific behaviour is re-derived by `case`/`is_a?` in a helper, the
exporter, and two templates. **Leverage** pushing per-type behaviour down
(polymorphic `subtitle`/`export_attributes`/`form_fields`) removes four switch
sites and the drifted roster at once.

### T2 · View-layer N+1s where an aggregate or scope defeats the loader
**Members** C-03, C-04, C-05, C-18. **Root** per-row I/O hidden in templates — a
grouped `.count`, an association `.ordered` scope, a `.size` on a `:through`, a
doubly-evaluated relation — invisible from the controller, which looks correct.
**Leverage** one discipline ("never call an aggregate or association scope inside
a per-row loop; precompute in the controller") dissolves all four.

### T3 · Reveal-before-authorize / oracle responses
**Members** C-07, C-08 (adjacent: C-09). **Root** a lookup that speaks before
authorization does: `.find` before `visible_to?`, and a grant form that answers
differently on user hit/miss. **Leverage** authorize (or neutralise the response)
before the lookup speaks — two flows, one fix shape.

### T4 · Duplicated domain knowledge across layers
**Members** C-06, C-10, C-17 (and C-01/C-20 as the structural home). **Root** the
same fact (type aliases; the visibility rule; the 2FA-state predicate) written in
two places and beginning to drift. Connascence of value/algorithm across module
boundaries — worst because the coupled points are far apart. **Leverage**
extracting the policy/registry objects off `User` gives each fact one home.

### T5 · Generator-stub security config never filled in
**Members** C-15, C-16. **Root** CSP and production SSL/host settings are the
commented-out Rails defaults. Defensible for a prototype; a conscious decision is
owed before any real deploy.

## Subject grid

| Subject | Dimensions (finding IDs) | # | Severity | Interpretation |
|---------|--------------------------|---|----------|----------------|
| user.rb | C-01, C-10, C-20(target), + hosts C-03 query | 3+ | **High** | God Object: auth + identity + graph + visibility + preferences |
| collectible.rb | C-02, C-12, C-19 | 3 | Medium | STI base also carrying link formatting + a hand-rolled predicate; fix C-02/C-12 together |
| collectibles_controller.rb | C-11, C-07 | 2 | Medium | resource CRUD + a whole import pipeline; the read path also leaks existence |
| collectibles_helper.rb | C-02, C-03 | 2 | Medium | a type switch and an N+1 count in the same presentation helper |
| _collectible.html.erb | C-02(form sibling), C-04 | 2 | High | shared card partial: N+1 label load |
| collection_search.rb | C-06, C-14 | 2 | Medium | duplicated alias table + raw-SQL count |

**Convergence rule** a subject at 3+ distinct dimensions gets its own finding at
High or higher. `user.rb` (C-01, High) satisfies it — the floor is held on
responsibility count, not lowered by a "normal Rails model" impression.
`collectible.rb` sits at exactly 3 but each axis is genuinely small (a link list,
a validator, a formatter) and it is a legitimate STI base; the convergence is why
C-02/C-12/C-19 should be fixed together, and it is captured by C-12, so it is not
separately escalated to High — the evidence for holding it at Medium is the small
per-axis surface, not a cohesion feeling.

## Leverage-ordered fix list

1. **Precompute per-row aggregates in controllers; ban scopes-in-loops** → dissolves C-03, C-04, C-05, C-18 (4). Effort Small. *Cheapest high-impact win.*
2. **Extract `CollectionVisibility` + preference objects off `User`** → dissolves C-10, materially reduces C-01, moves C-20's `viewer_link_keys`, homes C-17's predicate (≈4). Effort Large. *The structural anchor.*
3. **Push per-type behaviour onto the STI subclasses + one alias registry** → dissolves C-02, C-12, C-06, shrinks C-19 (≈3.5). Effort Medium.
4. **Authorize-before-lookup / neutral responses** → dissolves C-07, C-08 (2). Effort Small.
5. **Extract the import pipeline into a command object** → dissolves C-11 (1). Effort Medium.
6. **Neutralise CSV formula injection in the exporter** → dissolves C-09 (1). Effort Small.
7. **Ship CSP + production SSL/hosts; escape LIKE wildcards; parameterise the count subquery** → dissolves C-15, C-16, C-13, C-14 (4). Effort Small each.

## Credits

Each falsified before writing, scoped to what was checked.

- **Owner-scoped loading is consistent on every mutation.** Falsified by listing
  every write path: collectibles edit/update/destroy, labels, custom_sorts,
  profile_accesses, share_links all load via `current_user.*.find` — no
  `Model.find(params[:id])` on a mutating action. Holds for all five layers; the
  one reveal gap (C-07) is on the *read* path, not a mutation.
- **`QuerySearch` base/subclass split is a genuinely good abstraction.** Falsified
  by checking both subclasses honour the `apply`/ordering contract and share the
  parser (`CollectibleSearch`, `CollectionSearch` both implement `apply`, reuse
  `Parser`/`match_like`/`numeric_bounds`). No Refused Bequest; the base's
  id-subquery AND/OR evaluation is cleanly composable. Holds.
- **Follow is idempotent against a race.** Falsified per "second concurrent call":
  `find_or_create_by` (follows_controller.rb:11) backed by the unique index
  `index_follows_on_follower_id_and_followed_id` (schema) plus a model uniqueness
  validation and self-follow guard. Can't duplicate. Holds.
- **Request-level memoisation avoids N+1 for follow/shared tags** — scoped to
  tags. Falsified from the *view*: `_profile_row` → `collection_tags` →
  memoised `Set`s in application_helper.rb:4-23 (loaded once). Confirmed no
  per-row query for tags; the surviving per-row query (C-03 counts) is a
  different call, so the credit is tags-only.
- **Share-link expiry is enforced at the auth boundary, not just displayed.**
  `visible_to?` calls `share_links.active.exists?(token:)` (user.rb:109) and
  `ShareLink.active` filters `expires_at > now`. An expired token fails
  visibility. Holds.
- **Tokens use a CSPRNG.** `ShareLink#assign_token` →
  `SecureRandom.urlsafe_base64(16)` (128-bit), not `rand`. Holds (OWASP A02).

**Coverage gaps** `db/migrate/*` reviewed for indexes/integrity only, not a full
data-model audit; `lib/tasks/*.rake` and the PWA service-worker JS not deeply
reviewed. The app was not run, so N+1 findings are traced by reading templates
against loaders (per protocol), not measured against a query log.
