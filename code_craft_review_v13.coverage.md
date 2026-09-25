# Code-craft review v13 — coverage sidecar

Scaffolding for `code_craft_review_v13.md`. Commit `0a2078c`, branch `prototype`.
Two independent parallel passes (A, B) were run by fresh agents, then reconciled
and verified against the source by the synthesiser. This sidecar records what was
swept and how, so each attestation in the report points at a filled cell.

## 1. Catalogue-load ledger

| Catalogue | Read (evidence) | Single-subject checks it contributed |
|---|---|---|
| refactoring.md | Both passes' ledgers cite it; synthesiser applied Switch Statements, Duplicated Code, Shotgun Surgery, Feature Envy | C-04, C-05, C-07, C-08, C-16 |
| solid.md | Applied for connascence + SRP/dependency direction | C-01, C-06, C-09, connascence framing in T-CODE-3 |
| object-oriented-design.md | Responsibility census procedure applied to every controller/model/service | C-01, C-06 (God-Object gate); search-class downgrade evidence |
| design-patterns.md | Skimmed for Strategy/State/Template Method applicability | Template Method credit; no speculative pattern introduced |
| general-principles.md | DRY / defensiveness applied | C-05, C-08 |
| performance.md | N+1 / view-triggered I/O / indexing / COUNT | C-02, C-03, C-12, C-14, C-15 |
| reliability.md | Idempotency / race / validation-constraint mismatch | C-10, C-11, C-13 |
| security.md | OWASP + Saltzer/Schroeder; correctness-vs-security separation | S-01…S-08 |
| testing.md | n/a: tests explicitly out of scope (prototype branch, per the request) | — |

## 2. Credits ledger (falsification per credit)

| Credit | Falsifying question | Result |
|---|---|---|
| Domain access control careful | List every owner-mutation site; which loads by bare id? | None — all via `current_user.*`. Stands. |
| Mass-assignment intersected with allowlist | Which of the 4 sites fails? | None fail; the *duplication* is C-08. Stands (safety), findings (dup). |
| STI type allowlisted before constantize | Can `:type` reach `constantize` unfiltered? | No — `model_for` gates on `TYPES`. Stands. |
| Share-link token safe | Guessable? expired token accepted? | 128-bit CSPRNG; `active` scope enforces expiry. Stands. |
| Template Method split clean | Is the base actually model-agnostic? | Yes; caveats are S-07/C-07, not structure. Stands (scoped). |
| Log filtering covers sensitive params | Which sensitive param is unfiltered? | otp/token/secret/email all present. Stands. |
| "N+1 avoided via includes(:labels)" | Trace the SQL the *template* fires. | `.ordered` re-queries → **credit rejected**, became C-02. |
| `only_applicable_fields_set` correct? | Does the boolean branch mishandle `false`? | No — correct. Not a defect; C-16 is clarity only. |
| `count_order`/HAVING SQLi? | Can user input reach the interpolation unvalidated? | No today (allowlist/`.to_i`) → not a live vuln; latent risk is S-07. |

## 3. Instance censuses (per whole-scope dimension)

**Responsibility census** (every controller/model/service, app-authored axes;
Devise counts as one framework axis, not an exemption). Roster seeded from
`find app -name '*.rb'`:

Controllers: application(1: pagination/link-keys/2fa-guard — cross-cutting base),
collectibles(**5** → C-06), collections(1), follows(1), profiles(2: visibility +
preference-remembering — borderline, folded into read), root(1), settings(1),
settings/custom_sorts(1), settings/labels(1), settings/profile_accesses(1),
settings/share_links(1), settings/sorting(1), settings/visibility(1),
two_factor_authentication/sessions(1), two_factor_authentication/setup(1),
users/sessions(1). → only `collectibles` crosses the God threshold.

Models: user(**5** → C-01), collectible(2: STI base + field validation),
board_game/book/video_game(1 each — thin STI subclasses), collectible_label(1),
custom_sort(2: persistence + criteria format), follow(1), label(2: persistence +
prune callback), pagination(1), profile_access(1), share_link(1). → only `user`
crosses.

Query objects: query_search(1: AST eval), query_search/parser(1: parsing),
collectible_search(1: collectible mapping), collection_search(1: user mapping). →
each cohesive; duplication *between* them is C-07.

Services: collectible_importer(1: parse), collectible_exporter(1: serialise +
type-switch C-04). → neither a God Object.

**Type-switch census** — `grep -rn "is_a?(VideoGame\|is_a?(BoardGame\|is_a?(Book\|when VideoGame\|when BoardGame\|when Book" app`:
exporter type_specific, helper collectible_subtitle, `_form.html.erb`,
`_import_fields.html.erb` (+ `unless is_a?(Book)`). → C-04. STI `sti_name`/
`sti_class_for`/`model_for` are the *correct* central dispatch, not smells.

**Duplicated-roster census** — each optional attribute searched across scope; the
list (system, author, min/max_players, completed, evergreen, local/online_
multiplayer, cooperative, competitive) recurs in: OPTIONAL_FIELDS, two permit
lists, KEY_MAP, importer casts, exporter CSV+JSON, SORT_FIELDS, traits helper =
8+ sites → C-05. `TYPE_ALIASES` literal search → 2 independent definitions +
1 cross-class reference → folded into C-05.

**LIKE-site census** — `grep -rn "LIKE" app/queries`: match_like, match_any_like
(query_search.rb), match_label (collectible_search.rb) → all bound (no SQLi), all
unescaped wildcards → S-06.

**Raw-SQL interpolation census** — `grep -rn "Arel.sql\|#{.*}.*SQL\|where(\"" app/queries`:
count_order, match_type_count HAVING (collection_search), match_players/
match_player_field (collectible_search) → all safe by upstream allowlist/`.to_i`
→ S-07 (latent, not live).

**View N+1 census** — every template that iterates a collection, per-row call
traced from the template (not the loader): `_collectible` → `labels.ordered`
(re-queries, C-02), `search_links` (pure Ruby, no I/O), `collectible_traits`/
`collectible_subtitle` (loaded attrs, no I/O); `_profile_row` → `collectible_counts`
(grouped COUNT per row, C-03), `collection_tags` (checked — helper over loaded
data); list view `profiles/show` → `type_label` (pure); labels index →
`label.collectibles.size` (COUNT per row, C-03). Import review loops
`current_user.labels.ordered` per item (re-reads per row — folded into C-02's
fix note).

## 4. Coverage matrix (in-scope files)

All 16 controllers, all 12 models + 3 STI subclasses + application_record, all 4
query objects, both services, all 3 helpers, both rake tasks, `routes.rb`,
`application.rb`, `production.rb`, `content_security_policy.rb`,
`filter_parameter_logging.rb`, `devise.rb`, `db/schema.rb` — read in full across
the two passes. Views read for code concerns (N+1, domain logic, type switch):
`_collectible`, `show`, `profiles/show`, `_profile_row`, `_collection_list`,
`root/index`, `collections/index`, `_follow_button`, `_form`, `_import_fields`,
`review`, `labels/index`. Every view grepped for `raw`/`html_safe` (one hit: QR
SVG, noted under S-02) and for per-row I/O.

High-stakes-flow census:

| Flow | Swept against | Result |
|---|---|---|
| Password sign-in | throttling? load-then-authorize? | No throttle → S-01 |
| 2FA setup / challenge | throttle? enforcement before setup? | No throttle → S-01; soft-redirect only → S-08 |
| Collectible destroy | ownership-scoped? | `set_owned_collectible` via `current_user` — safe |
| Collectible show (public/private) | authorize-before-reveal? | `find` before visibility check → S-05 (404/403 oracle) |
| Bulk import create | transactional? idempotent? | Transactional (good); not idempotent → C-13 |
| Grant profile access | enumeration? | Distinct "no user found" → S-04 |
| Follow/unfollow | visibility + non-self + idempotent? | `followable?` + unique index — safe |
| Share-link create/destroy | ownership-scoped? token strength? | `current_user.share_links`; 128-bit CSPRNG — safe |

## 5. Not deeply read (low code-craft risk)

`config/environments/development.rb`, `test.rb`, `config/puma.rb`, `assets.rb`,
`inflections.rb`, `ci.rb`, `boot.rb`, `environment.rb`; migration files
individually (schema.rb used as source of truth); markup-only views (UI reviewer's
scope). `lib/` contains only rake tasks (read) and `.keep` files. No background
jobs, queues, or outbound HTTP in scope, so `reliability.md`'s retry/timeout
machinery mostly doesn't apply — flagging it would be speculative (the one place it
bites is the username race, C-10).

## 6. Self-grill (what it caught)

- Convergence gate: forced C-01 and C-06 to High rather than leaving `User`/
  `CollectiblesController` at the "borderline / normal Rails class" language both
  passes reached for — that language is the flinch the gate exists to override.
- Search-class downgrade: required *evidence* (single responsibility per class,
  facets not axes) rather than a cohesion impression to hold it below the 3+ floor.
- N+1 credit: re-checked from the template, not the controller — the `includes`
  credit failed and became C-02.
- Pass-diff: pass A found rate-limiting (S-01) and the username race/case (C-10/11);
  pass B found Devise `paranoid` (S-03), TYPE_ALIASES triplication (in C-05), and
  missing indexes (C-12). Neither pass alone had the union — evidence for the value
  of the second pass.
