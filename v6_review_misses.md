# What v6 missed

A cross-check of the v6 code-craft and ui-craft reports against every earlier
review (v1 `design_review.md` / `ui_review.md`; v2 `code_craft_review.md` /
`ui_craft_review.md`; v3 `craft-review-findings.md` + `craft-review-summary.md`,
the 69-finding multi-agent pass; v4 `v4_code_review.md` / `v4_ui_review.md`;
v5 `code_craft_review_v5.md` / `ui_craft_review_v5.md`).

Only misses that are **real and still present in the code** are listed. Prior
findings that later verification showed to be wrong or overstated, that are pure
"missing tests" (excluded by request), or that v6 actually covered, are omitted.
Each entry carries a **root-cause tag** (see legend) so the list feeds the
"make this more deterministic" discussion.

## Root-cause legend

- **RC1 — credit not falsified.** A "what already works" claim asserted without
  checking its own counterexamples/siblings. (The irony: the skill's own
  "check the siblings" rule was applied to findings but not to credits.)
- **RC2 — file enumerated but not analysed.** A file/flow in scope was listed
  (or read) but never actually held against the checklist.
- **RC3 — parallel-list pattern not sought.** The "same roster of
  fields/columns/keys re-listed in N places" duplication wasn't hunted as a
  named pattern.
- **RC4 — smell sweep stopped early.** A smell was reported for its first/worst
  instance without enumerating every instance across the scope.
- **RC5 — correctness/security checklist too narrow.** The pass covered SQL
  injection but not information-disclosure / check-ordering / race classes.
- **RC6 — depth calibration.** The long low-severity tail was dropped; v6 read
  as a headline set where v3 was exhaustive.

---

## Credit contradictions (v6 said the opposite of a prior finding)

**X1. Credited `find_or_create_by` as idempotent; it is not race-safe.**
*(code; v3 C11, v5 Theme 7 — Medium)* — `follows_controller.rb:11`. v6's
"what already works" praised it. It is SELECT-then-INSERT: a concurrent
double-submit raises an unhandled `ActiveRecord::RecordNotUnique` → 500, and the
code comment overclaims. The unique index protects the data, not the request.
Root cause: **RC1**.

**X2. Credited confirmation pages / "every mutation is `button_to`"; three
destructive actions have no confirmation.** *(ui; v3 U13, v4 #8, v5 Theme 6 —
Medium)* — delete-custom-sort (`sorting/show.html.erb:42`), remove-access and
revoke-share-link (`visibility/show.html.erb:47,84`) fire immediately, no
confirm, no undo, styled as plain `.button-as-link`. v6 credited the
confirm-delete pattern without checking these siblings. Root cause: **RC1**.

---

## Code-craft misses

### High (in ≥1 prior review)

**C-a. `ProfilesController#show` is a fat controller.** *(v1, v3 C1, v5 — High/Med)*
`profiles_controller.rb:4-53` — ~9 ivars, inline valid-sort resolution, preference
persistence, three-format `respond_to`. Every prior review flags it; v6 flagged
`CollectiblesController` (M3) but not this. Root cause: **RC4**.

**C-b. The collectible field roster is duplicated across ~10 sites.** *(v4 #1 — High)*
The attribute set (`system`, `min/max_players`, `author`, and the six booleans)
is re-listed in `Collectible::OPTIONAL_FIELDS`, `CollectibleExporter` (headers +
`common` + `type_specific`), `CollectibleImporter` (`KEY_MAP`, `BOOLEAN_ATTRS`),
`collectible_params` **and** `import_items_params` (near-identical duplicates of
each other), both form partials, and `collectible_traits`. v6 caught the *type
switch* (H2) but not the *roster* / the two parallel strong-params lists.
Root cause: **RC3**.

**C-c. Private-profile forbidden fallback duplicated across two controllers.**
*(v1, v3 C10 — High/Med)* `profiles_controller.rb:8-13` and
`collectibles_controller.rb:152-157` both do `visible_to?` → `store_location_for`
→ render `private_profile` `:forbidden`, coupled through a shared template
contract. Extract a `before_action`. Root cause: **RC4**.

### Medium

**C-d. `RootController#index` is a fat controller.** *(v1, v3 C8 — Med)*
`root_controller.rb:4-33` — five queries, six ivars, "newest + random other"
domain logic in the HTTP layer. Root cause: **RC4**.

**C-e. Controller feature-envy / misplaced domain logic (a cluster).** *(v1, v3 C18/C21 — Med)*
- `CustomSortsController#build_criteria` / `#matrix_from_criteria` — the
  rank-conflict + matrix↔criteria algorithm lives in the controller
  (`custom_sorts_controller.rb:56-78`).
- `ShareLinksController` owns `EXPIRY_OPTIONS` + expiry math (the view needs the
  options too) (`share_links_controller.rb:5-16`).
- `profile_accesses_controller.rb:6-8` normalises the identifier twice inline;
  wants a `User.find_by_identifier`.
- `applicable_label_ids` is Feature Envy on `User`/`Label`, duplicated between
  `create` and `build_collectible` (v2 #5, v5 Theme 5).
Root cause: **RC4** / general envy sweep incomplete.

**C-f. Correctness/security: two information-disclosure leaks.** *(v5 — Low, but security-adjacent)*
- `set_collectible` runs `collectibles.find` **before** `visible_to?`, so a
  private collection returns 404 for a missing id and 403 for an existing one —
  id enumeration (`collectibles_controller.rb:146-157`).
- The profile-access form says "No user found…" vs a success naming the user —
  account enumeration (`profile_accesses_controller.rb:6-11`).
v6's correctness/security pass covered SQL injection only. Root cause: **RC5**.

**C-g. `search_links` / `LINK_DEFINITIONS` primitive obsession.** *(v1 — High, softened here)*
`collectible.rb:96` does CGI-escape + intersect + select/format/map/sort over an
array of hashes; a `SearchLink` value object was suggested. Real but a judgement
call. Root cause: **RC6**.

### Low / smells

**C-h. NULL-safe negation clause + id-subquery negation idiom duplicated 4× each.**
*(v2 #6, v3 C20/C28, v5 — Low/Med)* `match_players` / `match_player_field` /
`match_type_count`, and the `negated ? where.not(id:) : where(id:)` idiom in four
places. v6 noted this in analysis but omitted it from the report. Root cause: **RC6**.

**C-i. `only_applicable_fields_set` primitive obsession / dense predicate.**
*(v1 — High, v4 #9 — Low)* `collectible.rb:84` —
`[true,false].include?(value) ? value == true : value.present?`. Root cause: **RC6**.

**C-j. `assign_username` long method + benign TOCTOU race.** *(v1, v2 #7, v5 — Med/Low)*
`user.rb:132-144` — extract a generator; note the index is the real guarantor.
Root cause: **RC6**.

**C-k. `Label#prune_disallowed_collectibles` destructive `after_update` callback.**
*(v1 — Med)* `label.rb:13,37` — a `destroy_all` cascade hidden in a callback.
Root cause: **RC6**.

**C-l. `to_csv` header/row coupled by position (connascence of position).**
*(v1, v3 C31 — Low)* `collectible_exporter.rb:6-40` — 16-element row must stay
index-aligned with `CSV_HEADERS` by hand. Root cause: **RC6**.

**C-m. Duplicate `custom_sorts` queries per page load.** *(v3 C24 — Low)*
`profiles#show` calls `custom_sort_orders` and `sort_options` (which calls
`custom_sorts.ordered`) — two queries for the same rows. Root cause: **RC6**.

**C-n. `COUNT_SORTS` re-encodes the type set a third time.** *(v3 C37 — Low)*
`collection_search.rb:37` — sub-item of the `TYPE_ALIASES` duplication v6 did
flag. Root cause: **RC3**.

**C-o. Smaller items v6 didn't list.** *(various — Low/trivial)* `criteria_are_unique`
loads-and-scans in Ruby with no DB backstop (v3 C26/C34); CSV/JSON export
materialises the whole collection (v3 C25); create-action DB race with no rescue
for ProfileAccess/Label/CustomSort (v3 C33); `player_count` presentation logic on
the model (v1); importer `normalise` per-attribute repetition (v1); empty
`RootHelper` dead code (v1); `Collectible` reopening `public` mid-class (v4 #9);
`Pagination` running `count` in its constructor (v4); SQLite-only SQL portability
(`RANDOM()`, `DISTINCT`+`ORDER BY`) (v5). Root cause: **RC6**.

---

## UI-craft misses

### High (in ≥1 prior review)

**U-a. Links distinguished by colour alone; monochrome themes set `--brand == --text`.**
*(v4 #1, v5 Theme 4 — High)* `a { color: var(--brand) }` with underline only on
`:hover`; in `monochrome_light`/`monochrome_dark`, `--brand` equals `--text`
(`#1a1a1a` / `#ededed`), so inline links are indistinguishable from body text
(WCAG 1.4.1). Confirmed still present. v6 missed it entirely. Root cause: **RC2**
(the stylesheet's per-theme link behaviour wasn't swept) + **RC4** (colour-only
state was checked for the view toggle but not for links).

**U-b. 2FA setup QR has no text alternative and no manual-entry key.**
*(v3 U1 — High; "the only finding that fully blocks a task")* `setup/show.html.erb:5-7` —
raw SVG, no `role`/name, no plaintext secret fallback, so a non-scanning user
cannot complete mandatory 2FA (WCAG 1.1.1). v6 read the view but didn't analyse
it. Root cause: **RC2**.

### Medium

**U-c. 2FA pages have no unique `<title>`.** *(v3 U7 — Med)* Both fall back to
"Collection" (WCAG 2.4.2). Root cause: **RC2**.

**U-d. Settings subnav missing on drill-down pages.** *(v3 U12 — Med)*
labels/edit, labels/confirm_delete, custom_sorts/new|edit render no `settings/nav`
and no breadcrumb — section orientation lost. Root cause: **RC4** (the subnav's
presence was checked on index pages, not its siblings).

**U-e. Search is power-user-first; syntax lives mainly in the placeholder.**
*(v2 #5/#6 — Med)* The primary filter affordance is a query language; no
one-click/faceted controls for common filters (type, completed). The placeholder
carries the only always-visible syntax and shouldn't carry instructions. v6
credited the `<details>` help but didn't raise the usability concern.
Root cause: **RC6**.

### Low

**U-f. Focus-visible severity is contested.** *(v2 #1, v3 U2 — High; v1/v4/v5 — Low)*
v6 treated "no `:focus-visible`, browser default preserved" as an acceptable
credit/enhancement. v4/v5/v1 agree it's Low; but **v2 and v3 rated it High**
(whole-scope AA gap, worsened by `overflow:hidden` clipping the ring on the view
toggle and `--brand==--text` monochrome). v6 leaned lenient without flagging the
disagreement. Root cause: **RC1** (credit not stress-tested).

**U-g. Repeated "Edit"/"Delete" row links lack per-row context.** *(v3 U17, v5 — Low)*
Labels and custom-sort lists — "Edit, Delete, Edit, Delete…" with no
visually-hidden item name (WCAG 2.4.4 best practice / `accessible-code.md`'s
"several Edit buttons in a table"). Root cause: **RC4**.

**U-h. "Following" toggle names its state, not its action.** *(v1 — Low)*
`_follow_button.html.erb:3` — accessible name is "Following"; the intent (that it
unfollows) lives only in `title`. Root cause: **RC6**.

**U-i. Export links "CSV" / "JSON" are bare out of context.** *(v1, v3 U16 — Low)*
`profiles/show.html.erb:47-49` — "Export" isn't part of either link's accessible
name. Root cause: **RC6**.

**U-j. 2FA form-quality cluster.** *(v3 U21/U22/U26/U28 — Low)* OTP field lacks
`inputmode="numeric"`; "OTP" label is jargon vs the plain-language prose above it;
no cancel/exit path; forms skip the app's `.stack`/`.field`/`.actions` styling.
Root cause: **RC2** (the whole 2FA flow was under-swept).

**U-k. Content/markup polish v6 didn't list.** *(various — Low)* Hint text not
tied via `aria-describedby` (v2 #6, v3 U20); search-help / composer tables lack
`<caption>` and `scope="col"` (v3 U18/U19); player min/max no cross-validation
(v3 U23); `autofocus` on the title field can disorient SR users (v2 #10, v4);
mixed straight/curly quotes in empty-state copy (v2, v4); **PWA manifest**
placeholders (`theme_color: "red"`, `description: "Collection."`) — v6 never
opened `manifest.json.erb` (v3 U29/U31). Root cause: **RC2** / **RC6**.

---

## Tally of why things were missed

| Root cause | Code | UI | Total |
|---|---|---|---|
| RC1 credit not falsified | 1 (X1) | 2 (X2, U-f) | 3 |
| RC2 file enumerated not analysed | — | 5 (U-a, U-b, U-c, U-j, U-k) | 5 |
| RC3 parallel-list pattern not sought | 2 (C-b, C-n) | — | 2 |
| RC4 smell sweep stopped early | 4 (C-a, C-c, C-d, C-e) | 3 (U-a, U-d, U-g) | 7 |
| RC5 correctness/security too narrow | 1 (C-f) | — | 1 |
| RC6 depth calibration (long tail) | 8 (C-g…C-o) | 3 (U-e, U-h, U-i) | 11 |

The two most *fixable* clusters are **RC4** (sweep stopped at the first
instance — a discipline problem the skill already half-addresses) and **RC1**
(credits asserted without falsification — a gap the skill doesn't address at
all). **RC2** and **RC6** are coverage/depth and point at the single-pass vs
fan-out tradeoff.
