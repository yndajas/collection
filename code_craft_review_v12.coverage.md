# code_craft_review_v12 — coverage sidecar

Scaffolding for the exhaustive inline code-craft pass. Not a deliverable; every
attestation in `code_craft_review_v12.md` points at a cell or pasted command
here. Commit `0a2078c`.

## Scope roster (seeded from a pasted listing)

`find app lib config -type f` (application code). Enumerated, then each marked in
the matrix below.

- Controllers (19): application, collectibles, collections, follows, profiles,
  root, settings, settings/custom_sorts, settings/labels,
  settings/profile_accesses, settings/share_links, settings/sorting,
  settings/visibility, two_factor_authentication/setup,
  two_factor_authentication/sessions, users/sessions.
- Models (15): application_record, board_game, book, collectible,
  collectible_label, custom_sort, follow, label, pagination, profile_access,
  share_link, user, video_game.
- Queries (4): query_search, query_search/parser, collectible_search,
  collection_search.
- Services (2): collectible_importer, collectible_exporter.
- Helpers (3): application_helper, collectibles_helper, root_helper.
- Config (security-relevant): content_security_policy, filter_parameter_logging,
  devise, environments/production, routes, schema.
- `lib/`: `tasks/coverage.rake`, `tasks/cucumber.rake` (tooling), plus `.keep` —
  n/a for correctness/security.

## Per-dimension sweeps (whole-scope, pasted commands)

| Dimension | Command | Result → finding |
|---|---|---|
| LIKE-wildcard / injection | `grep -rn 'LIKE\|sanitize_sql_like' app/queries` | `LIKE ?` in match_like/match_any_like/match_label; **0** `sanitize_sql_like` → C-01 |
| Raw SQL interpolation | `grep -rn 'Arel.sql\|where("\|#{' app/queries app/models` | count_order interpolates whitelisted `type`; numeric_bounds inlines cast ints (safe) → C-13 |
| `html_safe` / raw | `grep -rn 'html_safe\|raw(\|<%==' app/` | 1 hit: setup_controller.rb:27 (gem SVG) → noted M/C-10 backstop |
| Type switches | `grep -rn 'is_a?\|case .*when [A-Z]\|when VideoGame\|when BoardGame\|when Book' app` | exporter, helper, _form, _import_fields → C-06 |
| N+1 in templates | `grep -rn '\.ordered\b\|\.size\|\.count\|_counts' app/views app/helpers` | labels.ordered (_collectible, show), collectible_counts (_profile_row), label.collectibles.size (labels/index), labels.ordered per import row → C-03/04/05 |
| Duplicated roster | per-attribute grep of OPTIONAL_FIELDS names (below) | each optional field in 9–12 files → C-07 |
| Dependency direction | `grep -rn 'CollectibleSearch::\|CollectionSearch::' app/models app/controllers` | user.rb, custom_sort.rb, profiles/collections controllers reach up → C-09 |
| CSP / SSL | `grep -rn 'force_ssl\|content_security_policy' config` | CSP file fully commented; force_ssl commented → C-10, C-16 |
| Authorization scoping | `grep -rn 'current_user\.\|params\[:id\]\|find(' app/controllers` | all mutating actions owner-scoped (credit) |

## Responsibility census (every unit; app-authored axes only)

Controllers — all ≤2 app axes except: **collectibles_controller** (CRUD +
3-step import + label filtering ≈ 2–3; noted, not escalated). Models — all 1
axis except **collectible** (STI base + validation + search-links ≈ 2) and
**user = 5** (auth/2FA, social graph, visibility+authz, preferences, username →
**C-02 High**). Queries — **collectible_search ≈ 2–3** (token mapping + sort
catalogue + custom-sort translation → C-08); collection_search ≈ 2; parser 1.
Services — 1 each (exporter carries the type switch, C-06). No unit besides
`user.rb` reaches the 3-distinct-dimension convergence floor.

## Duplicated-roster census (per name → file count)

`min_players`, `max_players`, `cooperative`, `competitive`, `author`, `system`,
`completed`, `evergreen`, `notes` each appear across collectible.rb
(OPTIONAL_FIELDS), collectibles_controller (two permit lists), importer
(KEY_MAP), exporter (headers + rows), and the form / import-fields / search-help
/ search-form views — 9–12 files per name. The two `permit(...)` lists in the
controller (:135, :194) are the same attribute set verbatim. → C-07.

## High-stakes flow census

| Flow | Swept against | Verdict |
|---|---|---|
| Sign-in + 2FA | otp_user_id server-set; no user-controlled id | no IDOR |
| 2FA setup | current_user only | ok |
| Collectible create/update/destroy | `current_user.collectibles.find` / `require_own_profile` | owner-scoped |
| Profile/collectible show | `@profile.collectibles.find` then `visible_to?` (default-deny) | gated |
| Label/custom_sort/share_link/profile_access destroy | `current_user.<assoc>.find` | owner-scoped |
| Follow create/destroy | `current_user.follows_given` + visible_to? | scoped, idempotent |
| Access-grant lookup | email/username probe | enumeration oracle → C-11 |

## Coverage matrix (rows swept; blank = n/a for that file)

All 43 enumerated app files + 6 config files given a row and marked swept for
correctness, security, refactoring/SRP, coupling, performance. No blank rows.
Query-log not run (static N+1 tracing) — recorded as caveat in the report.

## Self-grill notes

- LIKE credit falsified from the helpers, not just one call site: `%#{value}%`
  in all three helpers, no escape → finding stands.
- N+1 credit falsified from the *template*, not the loader: `includes(:labels)`
  in profiles_controller is defeated by `.ordered` in `_collectible.html.erb:24`.
- Convergence: only `user.rb` at 3+ dimensions → C-02 High; no prose downgrade.
- Every named smell has a pasted census above; none reported from one instance.
