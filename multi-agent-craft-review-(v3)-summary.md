# Code and UI craft review: `collection`

*Multi-agent code-craft / ui-craft review — 87 agents, ~2.2M tokens, 69 findings confirmed after adversarial verification, clustered into 8 themes.*

## Verdict

A well-structured Rails prototype with genuinely good bones: STI collectibles with polymorphic `applicable_fields`, a clean `QuerySearch` grammar/parser split, sensible pagination, and visibility rules already DB-backed by unique indexes. The problems aren't sprawl — they're a handful of **recurring patterns**, each repeated across several files. Two clusters dominate: an **untested domain layer sitting behind a 100% coverage gate that gives false assurance**, and **accessibility gaps that block or degrade assistive-tech users** (one a hard blocker on the 2FA setup flow).

**Severity (verified):** 5 High · 26 Medium · 38 Low
**Lens split:** 38 code-craft / 31 ui-craft
**Zero correctness or security defects.**

---

## What already works (credit due)

- **No correctness or security findings** — no SQLi, broken access control, or XSS. Raw-SQL clause assembly in `CollectibleSearch` uses bound parameters correctly.
- **Data integrity defended at the DB** — `follows`, `labels`, `profile_accesses`, `custom_sorts` all carry unique indexes matching their model validations, so the race conditions below degrade to a 500, never to duplicate data.
- **Search parser cleanly separated** into a pure, dependency-free AST (`query_search/parser.rb`) — the right seam.
- **Real accessibility baseline** — semantic landmarks, associated `<label>`s, `aria-label`/`aria-current` on pagination, `rel="noopener"` on external links. The gaps are places a known-good pattern wasn't propagated, not ignorance of it.
- **Focus styles are never *removed*** (`outline:none` appears nowhere) — the focus finding is a missing enhancement, not a suppression.

---

## Themes, ranked by impact

### Theme 1 — A 100% coverage gate over an almost-entirely untested domain layer *(the headline risk)*

CI advertises `minimum_coverage line: 100, branch: 100` but measured coverage is **~17%**, and the gate never evaluates because the suite currently exits red. A green badge here would actively mislead.

- **[High]** Gate gives false assurance — `spec/rails_helper.rb:3-7` + `.github/workflows/ci.yml`
- **[High]** Entire query layer untested — the most branch-heavy code in the app (NULL-safe negation, player-bound arithmetic, regex parsing)
- **[Med]** Import/export services, pagination page-math, `CustomSort` validation, and core models (`User#visible_to?` is an access-control decision) all untested
- **[Low]** Non-deterministic seams inlined (`RANDOM()`, `.sample`, `Time`/`Date.current`) will make future specs flaky

### Theme 2 — Accessibility: perceivability & task blockers *(WCAG A/AA)*

- **[High]** 2FA QR code has no text alternative and no manual key — `two_factor_authentication/setup/show.html.erb:5-7`. A screen-reader user (or anyone who can't scan) **cannot complete 2FA setup at all**. The secret is already in the controller; render it as selectable text. *(WCAG 1.1.1)*
- **[High]** No visible focus indicator anywhere in the stylesheet — `application.css`. Whole-scope failure across every control and all seven themes. *(WCAG 2.4.7)*
- **[Med]** Card partial hardcodes `<h3>` skipping `<h2>` (breaks heading order on `profiles/show`); flash messages aren't live regions; 2FA pages share a non-unique `<title>`

### Theme 3 — Accessibility: forms & orientation

One root cause: errors and state are shown **visually** but not wired up **programmatically**.

- **[Med]** Error summaries not focusable, not linked to fields, no `role` — repeats across 6 form templates (extract one shared partial)
- **[Med]** Field errors lack `aria-invalid`/`aria-describedby`; nav landmarks share no distinct names; no skip link / targetable `<main>`
- **[Med]** "Current item" shown by CSS class only, not `aria-current` (pagination already does this right — copy it)

### Theme 4 — Usability: orientation, consistency, destructive-action safety *(Nielsen / Krug / Norman)*

- **[Med]** Destructive actions inconsistent — collectibles/labels get a confirm page, but delete-custom-sort, remove-access, and revoke-share-link fire immediately from `button_to` with no confirm and no undo, styled as plain text not `.button--danger`
- **[Med]** Primary nav never marks the current section (the settings subnav *does* — internal inconsistency); settings subnav vanishes on drill-down pages
- **[Low]** 2FA screens are second-class (no cancel path, unstyled, "OTP" jargon); PWA manifest ships scaffold placeholders (`theme_color: "red"`, `description: "Collection."`)

### Theme 5 — Duplicated type knowledge & a leaky exporter *(Replace Conditional with Polymorphism / Open-Closed / DRY)*

Adding a fourth collectible type today means editing multiple files.

- **[Med]** Exporter type switch — `collectible_exporter.rb:64-86`. `type_specific` is a `case ... when VideoGame/BoardGame/Book` whose branches exactly duplicate each subclass's `applicable_fields`. Replace with `collectible.applicable_fields.index_with { |f| collectible.public_send(f) }` and the exporter stops knowing the hierarchy.
- **[Med]** `TYPE_ALIASES` duplicated across `collectible_search.rb:87-94` and `collectible_importer.rb:14-18`, with a third consumer reaching *laterally* into the query object's constant. Give it one home on `Collectible`.
- **[Low]** `COUNT_SORTS` re-encodes the type set a third time; CSV headers coupled to the row array by position (Connascence of Position)

### Theme 6 — Fat controllers & misplaced domain logic *(Metz rule 4 / Long Method / Feature Envy)*

- **[High]** `ProfilesController#show` — ~49 lines, 8-9 ivars, inline sort/preference resolution. Extract a `CollectionView` presenter.
- **[Med]** `RootController#index` — five queries, six ivars, "newest + random other" domain logic in the HTTP layer; private-profile forbidden fallback duplicated across two controllers
- **[Low]** `build_collectible` mixes param coercion / class resolution / label filtering; viewer-preference `update_columns` duplicated; `CollectibleSearch` is a Large Class owning both query engine and sort catalogue

### Theme 7 — Reliability: check-then-act races *(idempotency / unique-constraint races)*

- **[Med]** `find_or_create_by` follow isn't race-safe despite a comment claiming idempotency — `follows_controller.rb:11`. Use `create_or_find_by` and fix the comment.
- **[Low]** Create actions rely on in-Ruby uniqueness with no rescue (a shared `rescue_from` in a settings base controller covers all three). *Note: the ShareLink case was flagged then dismissed as a false positive — its token is `SecureRandom`, so a double-submit can't collide.*

### Theme 8 — Performance *(all Low, all correctly scoped as future safeguards)*

Personal collections are small, so none is urgent:

- CSV/JSON export materializes the whole collection in memory
- Duplicate `custom_sorts` queries per page load
- `criteria_are_unique` loads all sorts and compares in Ruby

---

## Coverage note

**Covered:** query layer, services, models, all controllers, every view template, the stylesheet, CI config.
**Not separately audited:** JavaScript/Stimulus (essentially none), Devise internals, gem/dependency currency.

---

## If you do five things

1. **Make the coverage gate honest, then fill the base** — lower the threshold to the true number or add the missing specs, but don't ship a red 100% gate that lies. Unblocks every other testing finding.
2. **Fix the 2FA QR blocker** — render the base32 secret as selectable text and name the SVG. The only finding that *fully blocks a task*.
3. **Add one global `:focus-visible` style** — one rule closes a whole-scope AA failure.
4. **Replace the exporter type switch with `applicable_fields`** and give `TYPE_ALIASES` one home on `Collectible` — new types become "add a subclass," not "edit three files."
5. **Make destructive actions consistent and confirmed**, and **mark the current section in primary nav** — removes the sharpest "did I just delete that?" and "where am I?" edges.
