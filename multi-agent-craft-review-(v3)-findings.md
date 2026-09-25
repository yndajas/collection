# Code and UI craft review: `.` - all findings

_69 findings, each adversarially verified against the real code. Severity: 5 High / 26 Medium / 38 Low. Lens: 38 code-craft / 31 ui-craft._

Grouped by lens, then ordered by severity. Each entry gives the reviewer's finding (principle, location, description, fix) and the independent verifier's verdict.

---

# Code-craft findings (38)

## C1. ProfilesController#show is a fat controller instantiating many objects

**High** · _object-oriented-design_ · `app/controllers/profiles_controller.rb` - 4-53

> **Principle:** Fat controller (Metz rule 4: a controller should instantiate one object) / Long Method

**Finding.** show carries substantial domain logic (resolving valid sorts from CollectibleSearch::SORTS plus custom orders, remembering preferences, building the search, three-format respond_to) and assigns eight instance variables (@user, @token, @owner, @view, @sort_options, @search, @link_keys, @pagination/@collectibles). The method body well exceeds the 10-line high-severity threshold and the boundary between HTTP and domain is not thin.

**Fix.** Extract a query/presenter object (e.g. a CollectionView or ProfileShow use-case) that takes the user, viewer and params and exposes view, sort_options, search, link_keys, so the controller instantiates one object and reads from it. Move the sort/preference resolution (currently inline) onto that object or the User model.

**Verified** (confirmed, severity High). Confirmed by direct inspection of app/controllers/profiles_controller.rb:4-53. The show action is ~49 lines and assigns 8-9 instance variables (@user, @token, @owner, @view, @sort_options, @search, @link_keys, and @pagination/@collectibles in the HTML branch), far exceeding Metz's one-object-per-controller guideline. It carries genuine domain logic in the HTTP layer: resolving valid_sorts from CollectibleSearch::SORTS.keys + custom_orders.keys (line 23), coercing view/sort params via presence_in, remembering per-viewer preferences (line 26), and assembling CollectibleSearch with a three-level sort fallback (sort || current_user&.collectibles_sort || "updated", lines 31-34), followed by a three-format respond_to with export branching. The location and description are accurate; the method body well exceeds the 10-line high-severity threshold. High severity is right. One minor caveat: some extraction already exists (User#sort_options at user.rb:64 and #custom_sort_orders at user.rb:73), so the controller is not the worst case of fully-inline logic, but the remaining sort-resolution glue, preference persistence, search construction, and ivar sprawl fully substantiate the fat-controller/long-method finding. The proposed fix (a query/presenter object exposing view, sort_options, search, link_keys) is appropriate.

## C2. Entire query layer is untested despite dense branching logic

**High** · _testing_ · `app/queries/collectible_search.rb, app/queries/collection_search.rb, app/queries/query_search.rb, app/queries/query_search/parser.rb` - whole files

> **Principle:** Five-factor testing (Mei): none of verify/regression/document/design/refactor served; test pyramid missing its base (Fowler)

**Finding.** The Gmail-like search stack (parser AST, AND/OR/negation evaluation, numeric_bounds, player_bounds overlap mapping, NULL-safe negation, type/flag resolution) is the most branch-heavy, edge-case-laden code in the app and has zero direct or indirect tests: no spec references CollectibleSearch/CollectionSearch/QuerySearch/Parser, and no request/feature spec exercises a search. These are pure, dependency-light query objects (Parser needs no DB at all) - exactly the classicist unit-test sweet spot at the base of the pyramid - so the absence is pure missing coverage, not a design obstacle. A refactor of the evaluator or the bounds parsing today would be entirely unguarded.

**Fix.** Add unit specs. Test QuerySearch::Parser as a pure function against the AST shapes in its doc comment (precedence, quoting, parentheses, empty-OR pruning, negation). Test numeric_bounds/player_bounds return values directly (incoming queries: assert the value). Test each CollectibleSearch/CollectionSearch #apply branch and negation NULL-safety against a small fixture set (integration-level, one DB touch). Push exhaustive grammar cases down to the parser unit; keep only a couple of end-to-end search assertions higher up.

**Verified** (confirmed, severity High). Confirmed at all four cited paths. app/queries/query_search/parser.rb is a pure, DB-free AST parser with dense precedence/quoting/parenthesis/empty-OR-pruning/negation branching. app/queries/query_search.rb holds generic AND/OR/negation `evaluate`, `numeric_bounds` (regex-based, handles >, >=, <, <=, ranges, bare numbers), and NULL-safe `match_like`/`match_any_like`. app/queries/collectible_search.rb has an 11-branch `apply` case, `player_bounds` overlap mapping with off-by-one arithmetic (n+1/n-1), and raw-SQL NULL-safe negation in `match_players`/`match_player_field`. app/queries/collection_search.rb shares the base with its own has:/count filters. The zero-coverage claim is verified: spec/ contains only requests/ (auth, registration, 2FA), factories/, and helpers - no spec/queries, no feature/system specs. A case-insensitive grep for Search/Parser/search across the whole spec tree returns no matches, so nothing exercises the stack directly or indirectly. This is the most branch-heavy, edge-case-laden code in the app, it is pure and dependency-light (exactly the classicist unit-test base of the pyramid), and any refactor of the evaluator or bounds parsing is currently unguarded - plain missing coverage, not a design obstacle. High severity is correct given the raw SQL string assembly, off-by-one bounds arithmetic, and regex parsing that would silently break under refactoring. The proposed fix is sound and well-stratified; note that numeric_bounds/player_bounds are pure array-returning methods testable with no DB touch at all.

## C3. Coverage gate advertises 100% line/branch but the domain layer has none

**High** · _testing_ · `spec/rails_helper.rb` - 3-7

> **Principle:** Coverage tool giving false assurance; Erratic/misleading gate (test-smell family, Meszaros)

**Finding.** SimpleCov is configured with minimum_coverage line: 100, branch: 100, and CI runs bundle exec rspec (.github/workflows/ci.yml). Yet the specs only cover auth/registration/2FA/root, leaving every query object, both services, Pagination, and all the domain models/controllers unexercised. The 100% gate and the actual coverage cannot both be true: either the CI build is red (the gate is failing and being ignored) or the gate is not actually enforced per run, in which case it gives false assurance that everything is covered. A green badge here would actively mislead the next contributor into thinking the search/import logic is tested.

**Fix.** Reconcile the gate with reality: run the suite and confirm whether the 100% threshold is enforced. If it is failing, either add the missing tests (preferred, see the other findings) or lower the threshold to the true covered percentage so the number is honest. Do not leave a 100% gate that the domain code does not meet - a coverage floor is only useful if it actually blocks.

**Verified** (confirmed, severity High). Verified and correct. spec/rails_helper.rb:3-7 configures SimpleCov's default profile with `minimum_coverage line: 100, branch: 100`, and .github/workflows/ci.yml runs `bundle exec rspec` (plus a separate `bundle exec cucumber`, also gated at `minimum_coverage 100`, which the finding omitted). The .simplecov profile uses `track_files "{app,lib}/**/*.rb"`, so the entire domain layer counts toward coverage: app/queries/collectible_search.rb (248 lines), collection_search.rb, query_search.rb + parser, app/services/collectible_importer.rb (138) and collectible_exporter.rb (87), app/models/pagination.rb, and the domain models/controllers. A grep confirms zero references to any of these in spec/ or features/ — both suites only exercise auth/registration/2FA/home-page. I ran `bundle exec rspec`: measured Line Coverage 17.47% (232/1328), Branch 15.66% (31/198). The gate and reality demonstrably cannot both hold, exactly as claimed. Reality is in fact worse than the finding states: RSpec currently exits 1 due to 3 unrelated spec failures, and SimpleCov prints "Stopped processing SimpleCov as a previous error not related to SimpleCov has been detected" — so the 100% floor never even evaluates when the suite is red, and would block at 17% if it ever went green. This is a real false-assurance / misleading-gate smell that would mislead a contributor into believing the search/import logic is tested. The only nuance: the finding frames it as an either/or (build red OR gate unenforced); in practice both are true at once. Severity High is appropriate — the gate gives false assurance over critical, entirely untested import/export/search logic. Location spec/rails_helper.rb:3-7 is accurate.

## C4. Type switch in exporter should be polymorphic on the collectible subclass

**Medium** · _design-patterns_ · `app/services/collectible_exporter.rb` - 64-86

> **Principle:** Replace Conditional with Polymorphism (Fowler) / avoid a type switch the object can answer itself; a Strategy/Template-Method-style polymorphic method (GoF)

**Finding.** CollectibleExporter#type_specific is a case-on-class switch (when VideoGame / BoardGame / Book) that re-encodes, in a third place, exactly which optional fields each STI type owns. The subclasses already answer this kind of question polymorphically via applicable_fields (Collectible#applicable_fields, overridden in VideoGame/BoardGame/Book), so this switch duplicates that knowledge and must be edited every time a new collectible type is added - the tell-tale sign a type switch wants polymorphism. It is also the same switch shape as any other per-type behaviour, so it will attract siblings.

**Fix.** Give Collectible a polymorphic hook the subclasses implement (or derive it generically from applicable_fields), e.g. def export_attributes; applicable_fields.index_with { |f| public_send(f) }; end, then let the exporter call collectible.export_attributes instead of switching on class. The exporter stops knowing the type hierarchy and new types need no exporter change (Open/Closed via polymorphism).

**Verified** (confirmed, severity Medium). Verified at app/services/collectible_exporter.rb:64-86. `type_specific` is a `case collectible when VideoGame/BoardGame/Book` switch, and its per-branch hash keys exactly duplicate each subclass's `applicable_fields`: VideoGame -> system, local_multiplayer, online_multiplayer, cooperative, competitive (exporter 68-72 == app/models/video_game.rb:7); BoardGame -> min_players, max_players, cooperative, competitive (exporter 76-79 == app/models/board_game.rb:7); Book -> author (exporter 82 == app/models/book.rb:7). Each hash maps every key to the same-named accessor, so the proposed `applicable_fields.index_with { |f| public_send(f) }` hook on Collectible would produce identical output and let the exporter drop the class switch, so a new STI type needs no exporter edit. This is a genuine Replace-Conditional-with-Polymorphism / Open-Closed smell with the polymorphic seam already present in the model (Collectible#applicable_fields overridden per subclass). Severity Medium is correct: it is duplicated type knowledge and an Open/Closed violation, not a correctness bug, and the affected surface is a single small private method. Minor caveat: the separate `to_csv` path (lines 20-37) emits all columns flat and isn't type-gated, so the hook wouldn't restructure that method, but the finding correctly scopes itself to the `as_data`/`type_specific` switch where the smell actually lives.

## C5. Type alias table duplicated across query and importer

**Medium** · _general-principles_ · `app/queries/collectible_search.rb, app/services/collectible_importer.rb` - collectible_search.rb:87-94, collectible_importer.rb:14-18

> **Principle:** DRY (Pragmatic Programmer): one authoritative representation of knowledge

**Finding.** The same knowledge - which query/import words alias to which STI type (game/videogame -> video_game, boardgame -> board_game, etc.) - is encoded twice, once as CollectibleSearch::TYPE_ALIASES and once as CollectibleImporter::TYPE_ALIASES. The copies have already drifted apart (the importer omits the 'video_game'/'board_game' passthrough symmetry and CollectionSearch reaches into CollectibleSearch::TYPE_ALIASES rather than the importer's), so a new type or alias must be remembered in two places.

**Fix.** Give the type-alias mapping a single home (e.g. a constant/method on Collectible, alongside TYPES, or a small Collectible.resolve_type helper) and have both CollectibleSearch and CollectibleImporter consult it. This also removes CollectionSearch's cross-layer reach into CollectibleSearch::TYPE_ALIASES.

**Verified** (confirmed, severity Medium). Verified against the code. The two constants both exist and encode the same knowledge: CollectibleSearch::TYPE_ALIASES (app/queries/collectible_search.rb:87-94) and CollectibleImporter::TYPE_ALIASES (app/services/collectible_importer.rb:14-18). The cited lines are accurate. The cross-layer reach is confirmed: CollectionSearch#resolve_count_type at app/queries/collection_search.rb:135 does CollectibleSearch::TYPE_ALIASES[...] rather than consulting a shared home, so a third consumer already couples to CollectibleSearch's constant. The core DRY problem is real: adding a new type or alias requires remembering two places, and a third file reaches across a layer boundary into a query object's constant.

One factual correction to the finding's drift example: it claims "the importer omits the video_game/board_game passthrough symmetry." That is wrong. The importer DOES include "video_game" => "video_game" (line 15) and "board_game" => "board_game" (line 16); both tables actually have identical key sets (video_game, videogame, game, board_game, boardgame, book). So the two alias maps have NOT drifted in their entries; they are currently duplicates.

However, the consumers HAVE diverged in ways that reinforce the finding's underlying point: on an unrecognised type, CollectibleSearch scopes to .none (unknown type yields no matches, collectible_search.rb:140), whereas CollectibleImporter falls back to @default_type (collectible_importer.rb:109); and CollectionSearch applies .singularize before lookup (collection_search.rb:135) while CollectibleSearch does not. These behavioural differences mean a single shared table wouldn't be a drop-in for all three without preserving each caller's miss/normalisation policy, but they don't invalidate centralising the alias data itself.

Severity Medium is right: it is a maintainability/DRY issue with a real second (and third) copy and a genuine cross-layer coupling, not a correctness bug. The proposed fix (a single home such as a Collectible.resolve_type helper or constant, consulted by both/all consumers) is sound, provided the differing miss-handling and singularize behaviour are handled by the callers rather than folded into the shared table.

## C6. Exporter re-encodes which fields belong to which collectible type

**Medium** · _general-principles_ · `app/services/collectible_exporter.rb` - 64-86

> **Principle:** DRY (Pragmatic Programmer): knowledge duplication; a type switch the object could answer

**Finding.** CollectibleExporter#type_specific is a case on the collectible's class listing which optional fields each type carries (VideoGame -> system/multiplayer, BoardGame -> players, Book -> author). That knowledge is already authoritative on each subclass via applicable_fields (video_game.rb:6, board_game.rb:6, book.rb:6). The two representations can drift: adding a field to a subclass's applicable_fields silently leaves it out of the JSON export.

**Fix.** Derive the type-specific hash from the collectible itself, e.g. iterate applicable_fields and read each via public_send, so the model stays the single source of truth for which fields apply to a type. The exporter then needs no per-class case at all.

**Verified** (confirmed, severity Medium). Verified at app/services/collectible_exporter.rb:64-86: `type_specific` is a `case collectible when VideoGame/BoardGame/Book` that re-lists each type's optional fields, and those lists exactly duplicate the authoritative `applicable_fields` on each subclass (video_game.rb:7 system/local_multiplayer/online_multiplayer/cooperative/competitive; board_game.rb:6 min_players/max_players/cooperative/competitive; book.rb:6 author). This is genuine knowledge duplication (DRY): the model already knows which fields apply to a type, and the exporter re-encodes it. The drift failure mode is real - adding a field to a subclass's `applicable_fields` silently omits it from the JSON export. The proposed fix (iterate `applicable_fields` and `public_send` each) is viable, since those names are readable attributes (the CSV path already calls them directly, e.g. `collectible.system`, `.min_players`). Minor citation nit: `applicable_fields` in video_game.rb is at line 6-8 with the array literal on line 7, not line 6, but board_game.rb:6 and book.rb:6 are exact and the main location is exact. Medium is right: a maintainability smell with a concrete silent-drift risk to export correctness, but no present-day breakage and a small three-type surface - not High, not Low.

## C7. Type switch on collectible class that the object could answer itself

**Medium** · _object-oriented-design_ · `app/services/collectible_exporter.rb` - 64-86

> **Principle:** Repeated Switch / duck typing (Metz: replace type-check conditional with a shared message)

**Finding.** type_specific dispatches on collectible.class (case collectible when VideoGame/BoardGame/Book) to decide which type-specific fields to serialise. This is exactly the 'case obj.class' the models already answer via applicable_fields; the class switch here duplicates knowledge that lives on the STI subclasses, so adding a new collectible type means editing this switch as well as the model.

**Fix.** Ask the collectible what it does instead of what it is: derive the type-specific hash from collectible.applicable_fields (e.g. applicable_fields.index_with { |f| collectible.public_send(f) }), or add a to_export_data / export_fields method to Collectible and override per subclass. That removes the switch and keeps type knowledge on each model.

**Verified** (confirmed, severity Medium). Confirmed at app/services/collectible_exporter.rb:64-86. The private `type_specific` method switches on `case collectible when VideoGame/BoardGame/Book` to pick which type-specific fields to serialise. Each branch's field set is exactly what the corresponding STI subclass already exposes via `applicable_fields`: VideoGame (system, local_multiplayer, online_multiplayer, cooperative, competitive) matches app/models/video_game.rb:6-8; BoardGame (min_players, max_players, cooperative, competitive) matches app/models/board_game.rb:6-8; Book (author) matches app/models/book.rb:6-8. The base Collectible defines `applicable_fields` returning [] (app/models/collectible.rb:76-78), and it is already the authoritative list (used by the `only_applicable_fields_set` validation, collectible.rb:84-89). So the class switch duplicates knowledge that lives on the models: adding a new collectible type means editing this switch as well as the model. This is the Repeated Switch / 'case obj.class' smell Metz warns about. The proposed fix — `applicable_fields.index_with { |f| collectible.public_send(f) }` — is behaviour-preserving (the base class returns [] so unknown types yield {}, matching the existing `else {}`) and removes the switch, keeping type knowledge on each subclass. Medium severity is right: it is a maintainability/shotgun-surgery smell with a clean, low-risk fix, not a correctness or security defect.

## C8. RootController#index builds five separate queries and sets six instance variables

**Medium** · _object-oriented-design_ · `app/controllers/root_controller.rb` - 4-33

> **Principle:** Fat controller (Metz rule 4) / Long Method

**Finding.** index assembles @recent, @newest_collectible, @random_collectible, @link_keys, @followed and @shared, each with its own multi-clause query (including RANDOM() ordering and visibility scoping). The homepage's data-assembly logic lives in the HTTP layer and the method sets six instance variables, past the thin-boundary rule.

**Fix.** Extract a Homepage (or Dashboard) query object that exposes recent, newest_collectible, random_collectible, followed and shared for a given viewer; the controller then instantiates one object and reads from it. The 'newest + random other' pairing in particular is domain logic that belongs on the model/query, not the controller.

**Verified** (confirmed, severity Medium). Citation is exact. app/controllers/root_controller.rb:4-33 is RootController#index. It sets six instance variables: @recent (8), @newest_collectible (20), @random_collectible (21), @link_keys (22), @followed (26), @shared (30). Five of these build their own queries (@link_keys delegates to the viewer_link_keys helper), matching the "five separate queries" claim. The specifics hold: @recent, @followed, and @shared each apply visibility scoping (User.visible_to_viewer / public_profile: false with received_accesses); @random_collectible uses Arel.sql("RANDOM()") ordering (21); and the "newest + random other" pairing (own.order(created_at: :desc).first, then own.where.not(id: @newest_collectible).order(RANDOM()).first) is domain logic living in the HTTP layer, as claimed. This is a genuine fat-controller / thin-boundary violation (Metz's rule of instantiating one object and reading one variable), and the proposed Homepage/Dashboard query object is a reasonable fix. Severity Medium is correct: it is a real maintainability/design smell but not a correctness or security defect, and the method is cohesive and well-commented, so it does not rise to High.

## C9. TYPE_ALIASES constant duplicated across two query/service classes

**Medium** · _refactoring_ · `app/services/collectible_importer.rb` - 14-18

> **Principle:** Duplicated Code (Fowler)

**Finding.** CollectibleImporter::TYPE_ALIASES (lines 14-18) and CollectibleSearch::TYPE_ALIASES (collectible_search.rb:87-94) are near-identical alias maps from type words to STI names, already drifted (the search map includes a videogame variant list the importer orders differently and CollectionSearch#resolve_count_type reaches into CollectibleSearch::TYPE_ALIASES). Three places agree on the same alias vocabulary by copy.

**Fix.** Extract a single canonical alias map (e.g. Collectible.resolve_type_alias or a TYPE_ALIASES constant on Collectible) and have the importer, CollectibleSearch and CollectionSearch call it, removing the duplicated literals.

**Verified** (confirmed, severity Medium). Verified. CollectibleImporter::TYPE_ALIASES exists at app/services/collectible_importer.rb:14-18 and CollectibleSearch::TYPE_ALIASES at app/queries/collectible_search.rb:87-94 (the finding's bare `collectible_search.rb:87-94` resolves correctly; the file lives under app/queries/). Both are near-identical maps of six type words to the same three STI names (video_game, board_game, book). A third site, CollectionSearch#resolve_count_type at app/queries/collection_search.rb:135, reaches into CollectibleSearch::TYPE_ALIASES, so three places agree on the vocabulary and two hold literal copies. This is genuine Duplicated Code (Fowler), plus CollectionSearch's cross-class reach is inappropriate intimacy. One nuance: the claimed drift is only key-ordering (importer lists video_game/videogame/game; search lists videogame/game/video_game) with no behavioural divergence, so the two maps are still functionally identical, the "already drifted" phrasing slightly overstates the risk. Severity Medium is defensible but sits at the high end: the maps are tiny, stable, and semantically in sync, so this could reasonably be Low. The proposed fix (a single canonical map/method on Collectible consumed by all three) is sound.

## C10. Private-profile fallback rendering duplicated between ProfilesController and CollectiblesController

**Medium** · _refactoring_ · `app/controllers/collectibles_controller.rb` - 152-157

> **Principle:** Duplicated Code / Shotgun Surgery (Fowler)

**Finding.** set_collectible (collectibles_controller.rb:152-157) and ProfilesController#show (profiles_controller.rb:8-13) both, on a failed visible_to? check, set @user, call store_location_for(:user, ...) unless signed in, and render the private_profile template with :forbidden. The forbidden-fallback behaviour is copied; changing it (status, stored location, template) means editing both.

**Fix.** Extract a shared before_action/helper (e.g. deny_private_profile(user) in ApplicationController) that performs the store_location and render, and call it from both controllers when visible_to? is false.

**Verified** (confirmed, severity Medium). Verified both cited locations. CollectiblesController#set_collectible (app/controllers/collectibles_controller.rb:152-157) does exactly what the finding claims: after a failed `visible_to?` check it sets `@user = @profile`, calls `store_location_for(:user, request.fullpath) unless user_signed_in?`, then `render "profiles/private_profile", status: :forbidden`. ProfilesController#show (app/controllers/profiles_controller.rb:8-13) performs the same three-part fallback: `store_location_for(:user, request.fullpath) unless user_signed_in?` then `render :private_profile, status: :forbidden`, with `@user` set at line 5. The duplication is genuine and coupled through a shared template contract (CollectiblesController even aliases `@profile` to `@user` at line 154 specifically so the `profiles/private_profile` template works). Changing the forbidden behaviour (status, stored location, or template) requires editing both sites in lockstep, which is the Shotgun Surgery / Duplicated Code smell described. Severity Medium is correct: it is small (3 lines each) and non-buggy, but the cross-controller coupling to a shared template contract makes it more than trivial. Extracting a shared helper on ApplicationController (as proposed) is a reasonable fix.

## C11. find_or_create_by follow is not race-safe despite the idempotency comment

**Medium** · _reliability_ · `app/controllers/follows_controller.rb` - 11

> **Principle:** reliability: idempotency / unique-constraint race (RecordNotUnique)

**Finding.** The comment claims find_or_create_by 'keeps a repeated follow idempotent against the unique index', but find_or_create_by does SELECT-then-INSERT with no handling of a concurrent insert. On a double-clicked or retried POST, both requests find no row, both INSERT, and the loser hits the unique index index_follows_on_follower_id_and_followed_id, raising an unhandled ActiveRecord::RecordNotUnique that returns a 500. The index protects the data but not the request.

**Fix.** Rescue ActiveRecord::RecordNotUnique around the create and treat it as success (the follow now exists), or use create_or_find_by (which relies on the constraint and rescues the race) instead of find_or_create_by. Correct the comment to say the index prevents duplicate rows, not that the operation is race-safe as written.

**Verified** (confirmed, severity Medium). Confirmed at app/controllers/follows_controller.rb:11. The comment (lines 5-6) claims find_or_create_by "keeps a repeated follow idempotent against the unique index." find_or_create_by does a SELECT (find_by) then, on nil, a create INSERT, with no rescue for a concurrent insert. current_user.follows_given uses foreign_key: :follower_id (app/models/user.rb:28-30), and db/schema.rb:62 has the unique index index_follows_on_follower_id_and_followed_id exactly as cited. So on a double-clicked/retried POST, both requests find no row, both INSERT, and the loser raises an unhandled ActiveRecord::RecordNotUnique (uncaught here -> 500). The model's validates :uniqueness (app/models/follow.rb:5) does not close the window either, since it is also a SELECT-based check. The index protects the data but not the request, exactly as claimed. The proposed fix is correct: create_or_find_by (INSERT-first, rescues RecordNotUnique) or an explicit rescue treating RecordNotUnique as success, plus correcting the comment. Severity Medium is defensible but on the boundary: the blast radius is small (a low-frequency follow action, no data corruption since the index holds; worst case a one-off 500 on a race), so Low would also be reasonable. It stays at Medium because the comment actively asserts race-safety that the code does not provide, which misleads future maintainers.

## C12. Type switch in exporter that STI subclasses could answer polymorphically

**Medium** · _solid_ · `app/services/collectible_exporter.rb` - 64-86

> **Principle:** Open/Closed principle (Meyer) / Repeated Switch smell (Fowler)

**Finding.** type_specific branches `case collectible when VideoGame/BoardGame/Book` to pick each type's export fields, even though the STI subclasses already localise their own type-specific behaviour (applicable_fields, applicable_link_keys, player_count). The class is not closed for modification: adding a fourth collectible type forces editing this method rather than just adding a subclass.

**Fix.** Give Collectible a polymorphic `export_attributes` (or reuse `applicable_fields` to build the hash) that each subclass overrides, and have the exporter call `collectible.export_attributes`. This makes a new type a new class, not another `when` branch. The base returns {} for the default.

**Verified** (confirmed, severity Medium). Verified at app/services/collectible_exporter.rb:64-86. The `type_specific` method is exactly a `case collectible when VideoGame/BoardGame/Book` type switch. Each branch's emitted keys are an exact duplicate of the corresponding subclass's `applicable_fields`: VideoGame emits `system, local_multiplayer, online_multiplayer, cooperative, competitive` == `VideoGame#applicable_fields`; BoardGame emits `min_players, max_players, cooperative, competitive` == `BoardGame#applicable_fields`; Book emits `author` == `Book#applicable_fields`. The STI subclasses (app/models/{video_game,board_game,book}.rb) already localise this via `applicable_fields`/`applicable_link_keys` (and Collectible already dispatches on `applicable_fields` in `only_applicable_fields_set`), so the exporter reintroduces the same type dispatch a second time. This is a genuine Open/Closed violation / Repeated Switch: a fourth type forces editing this method rather than just adding a subclass. The proposed fix is directly viable since `applicable_fields` already carries exactly the needed field list (e.g. `collectible.applicable_fields.index_with { |f| collectible.public_send(f) }`, or a polymorphic `export_attributes`). Medium is the right severity: real, mechanical to fix, and carries a concrete per-type maintenance cost, but it is an internal export service rather than core domain logic or a widespread structural problem.

## C13. TYPE_ALIASES map duplicated between search and importer, and depended on upward by CollectionSearch

**Medium** · _solid_ · `app/queries/collectible_search.rb` - 87-94

> **Principle:** Duplication across files + Dependency Inversion / dependency-direction

**Finding.** CollectibleSearch::TYPE_ALIASES and CollectibleImporter::TYPE_ALIASES (collectible_importer.rb:14-18) are two near-identical alias maps that have already drifted (the importer omits `book`-free entries differently and lacks the same ordering), so a new alias must be added in two places to stay correct. Separately, CollectionSearch#resolve_count_type reaches up into CollectibleSearch::TYPE_ALIASES (collection_search.rb:135), coupling one query object to another query object's constant rather than to a shared abstraction.

**Fix.** Move the canonical alias map onto the domain (e.g. Collectible.resolve_type(word) / Collectible::TYPE_ALIASES, alongside the existing TYPES constant it already owns) and have CollectibleSearch, CollectionSearch, and CollectibleImporter all resolve through that single source. This removes the duplication and points every consumer at the model rather than at a sibling query class.

**Verified** (confirmed, severity Medium). Citations verified. CollectibleSearch::TYPE_ALIASES (app/queries/collectible_search.rb:87-94) and CollectibleImporter::TYPE_ALIASES (app/services/collectible_importer.rb:14-18) are genuinely duplicated maps, and CollectionSearch#resolve_count_type (app/queries/collection_search.rb:135) reaches into CollectibleSearch::TYPE_ALIASES, coupling one query object to a sibling query class's constant rather than a shared abstraction. Both the duplication (connascence of value across files; a new alias needs adding in two places) and the lateral/inverted dependency direction are real, and the proposed fix is well-founded: Collectible already owns a TYPES constant (app/models/collectible.rb:21), so the model is a natural single home for the alias map that all three consumers (CollectibleSearch, CollectionSearch, CollectibleImporter) could resolve through. One sub-claim is inaccurate: the finding says the two maps "have already drifted" with the importer omitting entries differently. They have NOT drifted semantically. Both maps contain the identical six keys (video_game/videogame/game -> video_game, board_game/boardgame -> board_game, book -> book) mapping to the identical three values; both include book. The only difference is cosmetic line grouping and entry ordering, which has no behavioral effect. So there is drift RISK, not present drift. This overstatement doesn't negate the core finding but does slightly reduce urgency. Medium severity is appropriate: a maintainability/duplication smell plus a coupling/dependency-direction issue, with no correctness bug today.

## C14. Import/export services are untested despite format parsing and casting edge cases

**Medium** · _testing_ · `app/services/collectible_importer.rb, app/services/collectible_exporter.rb` - whole files

> **Principle:** Five-factor testing (Mei): verify + document + regression all unserved; test pyramid base missing (Fowler)

**Finding.** CollectibleImporter parses three formats (titles/CSV/JSON), rescues malformed input to [], normalises keys, casts booleans/integers, resolves label ids against the user, and reports unknown_labels; CollectibleExporter serialises to CSV and a type-specific data hash. Both are plain objects with a single injected collaborator (user) - highly testable - yet have no specs and are reached by no request/feature test. Round-trip behaviour (exporter output re-imported), the malformed-CSV/JSON rescue branches, cast_boolean's TRUTHY set, and the unknown-label reporting are all unverified.

**Fix.** Add unit specs for both. For the importer, assert #rows for each format including the malformed-input rescue paths and the unknown_labels side effect (an incoming command with a queryable side effect); build the user with FactoryBot and a couple of labels. For the exporter, assert the CSV header row and a round-trip through the importer. These are fast, DB-light unit tests.

**Verified** (confirmed, severity Medium). Verified against the actual files. Both services exist at the cited paths and the claim is factually exact. CollectibleImporter (app/services/collectible_importer.rb) parses titles/CSV/JSON, rescues CSV::MalformedCSVError and JSON::ParserError to [] (lines 71-73, 86-88), normalises keys (lines 90-92), casts booleans via the TRUTHY set (lines 31, 112-116) and integers (lines 118-120), resolves label ids against @user.labels and records unknown names in unknown_labels (lines 122-137). CollectibleExporter (app/services/collectible_exporter.rb) serialises to CSV with a header row (lines 6-40) and a type-specific as_data hash (lines 43-86). Both are plain objects with a single injected collaborator. A grep of spec/ finds zero references to either service, to_csv, as_data, or unknown_labels; the only specs are authentication/registration/root request specs plus factories, none of which reach the collectibles#export/import or profiles#export actions that use these services. So there is a genuine, complete coverage gap over logic-dense, edge-case-heavy code, and the code is highly testable (only collaborators are a user - a users factory already exists - and an array of collectibles). The proposed fix is proportionate. I downgraded High to Medium: this is missing-test debt, not an active defect - there is no evidence of incorrect behaviour or user-facing breakage, and it is on a prototype branch - so it is well above Low but does not warrant High, which should be reserved for demonstrated bugs or high-risk structural problems.

## C15. Pagination page-math object has no unit tests

**Medium** · _testing_ · `app/models/pagination.rb` - 1-41

> **Principle:** Metz Magic Tricks: incoming-query object tested by asserting return values; test pyramid base (Fowler)

**Finding.** Pagination clamps the requested page into range, computes pages (>=1 even when empty), and builds the #series window with :gap markers ([1,:gap,4,5,6,7,8,:gap,12]). #series has non-trivial boundary logic (around window, dedup, gap insertion) and is a pure function of page/pages - the clearest possible unit-test target - but has no spec and is only ever exercised implicitly through controllers that themselves have no tests. The gap-insertion and clamp boundaries (page 0, page beyond last, single-page, empty scope) are unverified.

**Fix.** Add a unit spec driving #series, #pages, #prev?/#next? and the page clamp across boundaries (empty, single page, first, last, middle, over-range, around variations). Pass a real small relation or a lightweight double exposing #count/#limit/#offset; these are pure return-value assertions.

**Verified** (confirmed, severity Medium). Verified at app/models/pagination.rb:1-41 (file is exactly 41 lines). No spec exists: spec/ contains only factories, helpers, and request specs for auth flows (authentication, registration, root, two_factor_authentication) - there is no spec/models/pagination_spec.rb nor any file referencing Pagination. The class is used only via ApplicationController#paginate (line 13), called from ProfilesController (line 41) and CollectionsController (line 15), neither of which has any controller/request spec, so the page math is never exercised even implicitly. All described logic is present and non-trivial: clamp (line 12 `page.clamp(1, pages)`), pages>=1 when empty (line 22 `return 1 if total.zero?`), and #series with window clamping via max/min (line 34), uniq.sort dedup (line 35), and :gap insertion (line 37) producing the documented [1,:gap,4,...,:gap,12] shape. #series is a pure function of page/pages/around and is the clearest unit-test target; prev?/next? (lines 27-28) are pure predicates. The proposed fix correctly notes the constructor needs a real relation or a double exposing count/limit/offset (records/total/pages/clamp depend on the relation), so only #series is purely page/pages-driven - a minor nuance the fix already accounts for. Severity lowered from High to Medium: the gap is real and cheap to fill on the clearest possible unit-test target, but this is the prototype branch with an intentionally thin suite, and a pagination defect is cosmetic/navigational (no data loss, correctness-of-record, or security impact), so it does not rise to High.

## C16. Custom-sort composition and validation logic is untested

**Medium** · _testing_ · `app/models/custom_sort.rb` - 18-74

> **Principle:** Five-factor testing (Mei): verify + regression unserved; model with rich validations left unpinned

**Finding.** CustomSort has five interacting validations (needs a field, unique fields, known fields, criteria uniqueness against the user's other sorts, and 'must not replicate a built-in' via order_clause.to_a comparison) plus key/summary/display_name derivations. This is model logic with real branching and cross-record checks, entirely untested (no spec references it, no request spec creates one). criteria_do_not_match_builtin's column-order-sensitive comparison in particular is subtle and easy to break silently.

**Fix.** Add a model spec: valid?/errors for each validation branch (empty criteria, duplicate field, unknown field/direction, duplicate-of-another-sort, matches-builtin), and return-value assertions for #key, #summary, #display_name. Build against a real user; these are incoming-query and incoming-command assertions on the model boundary.

**Verified** (confirmed, severity Medium). Verified against app/models/custom_sort.rb. The five validations exist exactly as described: criteria_include_a_field, criteria_have_unique_fields, criteria_reference_known_fields, criteria_are_unique (cross-record check via user.custom_sorts.where.not(id: id), lines 57-62), and criteria_do_not_match_builtin (order-sensitive order_clause.to_a comparison, lines 67-73; the code's own comment on lines 64-66 flags that hash == would ignore column order, confirming the subtlety the finding calls out). The key/summary/display_name derivations (lines 14-35) also exist. The cited range 18-74 covers order_clause, summary, display_name, and all five private validation methods. It is entirely untested: grep across spec/ finds zero references to CustomSort/custom_sort, there is no spec/models directory, no factory for it, and the settings/custom_sorts_controller.rb has no request spec in spec/requests either — so neither a model spec nor a request spec exercises this logic. The proposed fix (per-branch valid?/errors assertions plus return-value assertions for #key/#summary/#display_name, built against a real user) is appropriate. Severity Medium is correct: real branching model logic with a subtle order-sensitive cross-record comparison left wholly unpinned, but on the prototype branch and the failure mode is a silent validation regression rather than a security or data-integrity issue, so not High; the genuine branching and subtlety make it more than Low.

## C17. Core domain models (User, Collectible, Label, Follow, ProfileAccess, ShareLink) have no direct tests

**Medium** · _testing_ · `app/models/user.rb, app/models/collectible.rb, app/models/label.rb, app/models/share_link.rb, app/models/follow.rb, app/models/profile_access.rb, app/models/board_game.rb, app/models/video_game.rb` - whole files

> **Principle:** Five-factor testing (Mei): regression + design-guidance unserved on business rules

**Finding.** Behaviour-bearing model methods carry real rules and branches yet are untested: User#visible_to? (5 branches: public/nil/self/allowlist/token), User.visible_to_viewer, User#assign_username collision loop, User#sort_options empty fallback, and the three custom validators; Collectible#only_applicable_fields_set (boolean-vs-present 'set' logic) and #search_links filtering; Label#prune_disallowed_collectibles after_update; ShareLink#expired?/active scope (time-dependent); the Follow/ProfileAccess self-reference validations; BoardGame#player_count formatting. Only the User factory exists (spec/factories/users.rb); nothing asserts these. visible_to? is an access-control decision, so its untested branches carry security-adjacent regression risk.

**Fix.** Add model specs prioritising the branch-heavy security and rule methods first: User#visible_to? (each branch, including token via a share_link fixture) and .visible_to_viewer, Collectible#only_applicable_fields_set validity per type, Label#prune_disallowed_collectibles as an incoming command (assert the detach side effect), ShareLink#expired?/active with time frozen, and the two self-reference validations. Assert at the model boundary (return values / errors / observable side effects), classicist style.

**Verified** (confirmed, severity Medium). Verified against the cited files. Every method the finding names exists as described and none has a model spec. There is no spec/models/ directory and no test/ directory; the only specs are request specs (spec/requests/*) plus a single factory (spec/factories/users.rb), so nothing asserts these model behaviours directly.

Confirmed present and untested:
- app/models/user.rb: visible_to? (5 branches: public L105, nil-and-blank-token L106, self L107, allowlist L108, active-token L109); self.visible_to_viewer (L89-95); assign_username collision loop (L132-144); sort_options empty fallback `.presence || [...]` (L64-70); three custom validators collectibles_sort_is_known/hidden_default_sorts_are_known/hidden_link_keys_are_known (L116-130).
- app/models/collectible.rb: only_applicable_fields_set boolean-vs-present 'set' logic (L84-90); search_links `only:` filtering (L96-104).
- app/models/label.rb: prune_disallowed_collectibles after_update guarded by saved_change_to_collectible_types? (L13, 37-45).
- app/models/share_link.rb: expired? and active scope, both time-dependent (L8-12).
- app/models/follow.rb and profile_access.rb: self-reference validations (follower_is_not_followed, owner_is_not_viewer).
- app/models/board_game.rb: player_count formatting (L10-17).

The visible_to? access-control gate is correctly flagged as security-adjacent regression risk. Severity Medium is right: real, exhaustively confirmed coverage gap on branch-heavy rule methods, but no concrete defect demonstrated and this is a prototype branch with some indirect request-spec coverage, so not High; more than Low because an access-control decision method is among the untested branches. Minor caveat: app/models/book.rb (a third Collectible STI type) is also untested and only implied by the finding, which if anything strengthens it. The "whole files" location is appropriate for an absence-of-tests finding.

## C18. Business logic embedded in controllers has no unit-testable seam

**Medium** · _testing_ · `app/controllers/settings/custom_sorts_controller.rb, app/controllers/collectibles_controller.rb` - custom_sorts_controller.rb:56-78; collectibles_controller.rb:112-142,176-191

> **Principle:** GOOS 'listen to the tests' (Freeman/Pryce): design-guidance factor - logic reachable only through the full request stack

**Finding.** Non-trivial algorithms live as private controller methods with no object of their own: CustomSortsController#build_criteria/#matrix_from_criteria (rank-conflict detection, matrix<->criteria transform) and CollectiblesController#import_format/#infer_format/#build_collectible/#applicable_label_ids. Because they are private controller methods, the only way to test them is a full request spec - the higher, slower, more coupled level - when the logic is pure enough to be a fast unit. That these have no tests at all compounds it, but the design (logic trapped in the controller) is itself the test-pain signal Metz/GOOS describe.

**Fix.** Extract the transforms into plain objects (e.g. a SortCriteriaComposer taking the matrix, returning criteria + errors; fold format inference and label filtering into CollectibleImporter or a small helper) and unit-test those directly. Leave the controller as a thin request-spec-covered shell. If extraction is out of scope now, at minimum add request specs for the create/update flows so the branches are exercised.

**Verified** (confirmed, severity Medium). Verified against both files; citation is accurate. custom_sorts_controller.rb:56-78 contains private methods build_criteria (rank-conflict detection via tally, 56-72) and matrix_from_criteria (bidirectional matrix<->criteria transform, 74-78) — both pure functions over hashes and the CollectibleSearch::SORT_FIELDS constant, trivially unit-testable if extracted. collectibles_controller.rb:112-142 holds import_format/infer_format (format inference: infer_format is pure logic on a filename string) and :176-191 holds build_collectible/applicable_label_ids (label allowlisting; couples only to current_user, a small injectable seam). All are private controller methods reachable only through the full request stack, exactly the GOOS/Metz test-pain signal described. I confirmed zero coverage: the only specs are spec/requests/{authentication,root,registration}_spec.rb and two_factor_authentication/*; grep for custom_sort|import_review|import_create|build_criteria|infer_format across spec/ returns nothing, and there are no model or unit specs. So the branches (rank conflicts, format fallback, label filtering) are entirely unexercised. The proposed fix is feasible and well-targeted: a CollectibleImporter model already exists (app/models/collectible_importer.rb, used at line 73) to absorb format inference, and CustomSort already parses criteria (custom_sort.rb:30,50), a natural home for a SortCriteriaComposer. Severity Medium is correct: this is a design/testability smell (a refactor), not a correctness or security defect, so it does not reach High; but the total absence of tests over non-trivial branching logic keeps it above Low.

## C19. Duplicated per-key token dispatch across the two search subclasses is not yet worth a Strategy

**Low** · _design-patterns_ · `app/queries/collection_search.rb` - 75-110

> **Principle:** Strategy (GoF) considered and deliberately declined - forcing it here would be Speculative Generality (Fowler); noted only because the case dispatch is duplicated across two files

**Finding.** Both CollectibleSearch#apply and CollectionSearch#apply (plus their apply_flag helpers) dispatch on a closed token key/flag set with a case statement. GoF Strategy or a key->handler registry is the textbook cure for a switch on a varying selector, but the selector set here is small, closed and grammar-defined, and each branch is a one-line relation transform, so a Strategy registry would add indirection without removing a present problem (YAGNI/KISS). The only real smell is that the two apply/apply_flag structures are near-identical siblings in different files; if a third search subclass appears, revisit extracting a shared token-dispatch table then, not now.

**Fix.** Leave the case statements as-is for now (the simplest thing that works). Only if a third QuerySearch subclass lands, extract the shared negation/subquery-composition pattern (the repeated "negated ? scope.where.not(id: matching) : scope.where(id: matching)") into a QuerySearch helper - that is the concrete duplication, not the dispatch itself.

**Verified** (confirmed, severity Low). Citation is accurate: collection_search.rb:75-110 is exactly CollectionSearch#apply (75-95) and #apply_flag (99-110). The claim holds on inspection. Both subclasses dispatch on a closed, grammar-defined key/flag set with a case statement (CollectibleSearch#apply 126-163 and #apply_flag 230-247; CollectionSearch#apply 81-94 and #apply_flag 99-110), and both share the same skeleton (extract key/value/negated, `return scope if value.blank?`, an `is` -> apply_flag branch). So the near-identical-siblings observation is genuine. The finding's design judgement is sound: a Strategy/registry over a small closed set of one-line relation transforms would add indirection without removing a present problem (correct YAGNI/KISS reasoning; declining Strategy is right, not a defect). The finding also correctly pinpoints the one piece of concrete duplication that IS extractable - the id-subquery negation idiom `negated ? scope.where.not(id: X) : scope.where(id: X)` - which recurs four times (collection_search.rb:109,118,130 and collectible_search.rb:227) and is not yet hoisted into the QuerySearch base. Minor overstatement that every branch is a one-liner (CollectibleSearch's `type` at 135-141 and `multiplayer` at 239-241 span several lines), but that doesn't undermine the finding. Low severity is correct: this is an explicit defer-until-a-third-subclass note with no present defect or behavioural risk.

## C20. Numeric-bounds SQL clause construction duplicated in two match methods

**Low** · _general-principles_ · `app/queries/collectible_search.rb` - 170-198

> **Principle:** DRY (Pragmatic Programmer): duplicated logic

**Finding.** match_players and match_player_field build their WHERE clauses with the same structure - positive branch joins 'col op n' with ' AND ', negated branch wraps each as '(col IS NULL OR NOT (col op n))' joined with ' OR '. The NULL-safe negation idiom is the load-bearing knowledge and it is written out twice, so a fix to the negation semantics must be made in both.

**Fix.** Extract a private helper that takes [[column, op, n], ...] plus a negated flag and returns the scope, and call it from both methods (match_players passes its overlap-mapped bounds, match_player_field passes its direct-column bounds).

**Verified** (confirmed, severity Low). Confirmed at app/queries/collectible_search.rb:170-198. Both match_players (170-182) and match_player_field (187-198) build WHERE clauses with identical structure: the positive branch joins "col op n" fragments with " AND ", and the negated branch wraps each fragment as "(col IS NULL OR NOT (col op n))" joined with " OR ". The NULL-safe negation idiom is written out verbatim in both (lines 176 and 192), so a change to the negation semantics must be made in two places. The only difference is the bound shape: match_players iterates [col, op, n] triples from player_bounds, while match_player_field iterates [op, n] pairs against a fixed column - which the proposed extraction accommodates by having match_player_field map its pairs to triples. Low severity is correct: real but small (two call sites, string assembly only, no correctness defect), and the fix is a modest private-helper extraction.

## C21. Identifier lookup value normalised twice in the same expression

**Low** · _general-principles_ · `app/controllers/settings/profile_accesses_controller.rb` - 6-8

> **Principle:** DRY (Pragmatic Programmer): local duplication

**Finding.** params[:identifier].to_s.downcase.strip is computed twice as the two bind values for the email/username lookup. If the normalisation ever changes (e.g. also stripping internal whitespace) both copies must be kept in step.

**Fix.** Assign the normalised value to a local (e.g. identifier = params[:identifier].to_s.downcase.strip) and pass it as both bind parameters.

**Verified** (confirmed, severity Low). Confirmed at app/controllers/settings/profile_accesses_controller.rb:6-8. The expression `params[:identifier].to_s.downcase.strip` is computed identically on both line 7 and line 8 as the two bind values for the `LOWER(email) = ? OR username = ?` lookup. This is genuine local duplication (DRY): if the normalisation rule changes, both copies must be kept in step, and there is a latent inconsistency risk. The proposed fix (extract to a local `identifier` and pass it as both binds) is correct and appropriate. Severity Low is right: it is a maintainability/readability nit in a single short method with no correctness or security impact today. Worth noting the two copies are already identical, so there is no current bug — only future-change risk — which supports Low rather than anything higher.

## C22. build_collectible mixes param coercion, class resolution and label filtering

**Low** · _object-oriented-design_ · `app/controllers/collectibles_controller.rb` - 176-191

> **Principle:** Long Method / Single Responsibility (Metz: method under 5 lines)

**Finding.** build_collectible normalises ActionController::Parameters, dups, resolves the STI class from the type param, conditionally rewrites label_ids via applicable_label_ids, then instantiates and assigns the user. It does several things at more than one level of abstraction and exceeds the 5-line guideline; applicable_label_ids and the type-to-class resolution are distinct responsibilities that also recur in #update.

**Fix.** Move the 'build a collectible of the right type for this user, keeping only applicable label ids' logic onto the domain (e.g. a Collectible.build_for(user, attributes) factory or the User model), so both create/import and update share it and the controller method drops to a couple of lines.

**Verified** (confirmed, severity Low). Verified against app/controllers/collectibles_controller.rb. build_collectible (method body lines 176-184; the cited 176-191 range also spans applicable_label_ids, which the finding explicitly discusses, so it's defensible) does exactly what's claimed: normalises ActionController::Parameters (177), dups (178), resolves the STI class from the type param via Collectible.model_for || requested_type (179), conditionally rewrites label_ids through applicable_label_ids (180-182), then instantiates and assigns the user (183). That's 8 lines over the 5-line guideline, spanning several abstraction levels. The recurrence claim also checks out: #update (30-33) duplicates the same conditional applicable_label_ids label-filtering logic, so the domain rule "a label can only attach to a type it applies to" lives in the controller and is repeated. The proposed extraction to a domain factory (e.g. Collectible.build_for / User) is a legitimate DRY/SRP fix. Severity Low is correct: this is a maintainability/design concern, not a live correctness or security defect (the invariant is currently enforced correctly in both call sites); the only risk is future drift, which keeps it below Medium.

## C23. CollectibleSearch has grown several responsibilities (search, sort catalogue, custom-order translation)

**Low** · _object-oriented-design_ · `app/queries/collectible_search.rb` - 30-248

> **Principle:** Large Class / Single Responsibility (Metz: class under 100 lines, one reason to change)

**Finding.** Beyond applying the query grammar, this class owns SORTS, DEFAULT_OPTIONS, SORT_FIELDS, DIRECTIONS, default_option and custom_order (the stored-criteria-to-ORDER-BY translation used by CustomSort and User). It is the query engine and the canonical sort catalogue at once, so it changes for two reasons and is a magnet for cross-file dependencies. Much of the length is comments, but the responsibility count, not the raw lines, is the issue.

**Fix.** Consider splitting the sort catalogue and custom-order translation (SORT_FIELDS, DIRECTIONS, custom_order, default_option) into a dedicated SortCatalogue/CollectibleSort value object that CustomSort, User and CollectibleSearch all depend on, leaving CollectibleSearch focused on turning a parsed query into filtered rows.

**Verified** (confirmed, severity Low). Verified against app/queries/collectible_search.rb (lines 30-248 cited accurately) plus its dependents. The class genuinely holds two distinct responsibilities: (1) the query engine — the `apply` token-mapping case statement, player-bound/numeric-bound SQL, label and free-text matching (lines 126-247); and (2) the canonical sort catalogue and stored-criteria translation — SORTS (31), DEFAULT_OPTIONS (44), SORT_FIELDS (54), DIRECTIONS (65), self.default_option (71) and self.custom_order (77). These change for two different reasons (query grammar vs sort options), matching the SRP concern as described.

The cross-file-magnet claim is confirmed concretely. External code reaches into the sort internals: custom_sort.rb calls CollectibleSearch.custom_order (19) and references CollectibleSearch::SORT_FIELDS (30, 50), ::DIRECTIONS (51) and ::SORTS (71); user.rb uses ::DEFAULT_OPTIONS (65, 123), .default_option (69) and ::SORTS (117); plus profiles/custom_sorts/sorting controllers and two views. CustomSort in particular exhibits feature envy on CollectibleSearch's sort constants. The proposed SortCatalogue/value-object extraction is a reasonable fix that would localise this coupling.

The finding is honestly framed (it explicitly notes much of the length is comments and that the responsibility count, not raw lines, is the issue), so it does not overreach on the Metz 100-line heuristic. Severity Low is correct: this is a real but non-urgent organisational smell against stable constants, with no correctness or security impact and existing test coverage; it does not warrant Medium.

## C24. Duplicate custom_sorts queries when rendering a collection

**Low** · _performance_ · `app/controllers/profiles_controller.rb` - 22,29

> **Principle:** N+1 / repeated query (Fowler: performance as design; Rails query patterns)

**Finding.** #show calls current_user.custom_sort_orders (line 22, loads the custom_sorts association) and current_user.sort_options (line 29, which calls custom_sorts.ordered - a separate ordered relation, so a second query). Both fetch the same rows, so the same user's custom sorts are read from the database twice per page load.

**Fix.** Load the user's custom sorts once (e.g. memoise `current_user.custom_sorts.ordered.to_a` or `current_user.custom_sorts.load`) and derive both the orders map and the dropdown options from that single in-memory collection, rather than issuing two queries.

**Verified** (confirmed, severity Low). Confirmed real at the cited location. ProfilesController#show line 22 calls current_user.custom_sort_orders (User#custom_sort_orders, user.rb:74) which iterates the bare custom_sorts association, and line 29 calls current_user.sort_options (User#sort_options, user.rb:68) which iterates custom_sorts.ordered. Because .ordered applies order(:name) (custom_sort.rb:11), it is a distinct relation that ActiveRecord cannot serve from the association's loaded cache, so it issues a second SQL query. Nothing eager-loads custom_sorts (no includes/preload found), so the same user's custom_sorts rows are genuinely read twice per page load. Two minor caveats: both calls are guarded by current_user&., so this only affects signed-in viewers; and the claim describes the mechanism via the model internals correctly even though it attributes the queries to the controller line numbers. Severity Low is correct: the cost is a fixed 2-vs-1 pair of small indexed lookups on a single user's rows, not a true N+1 that scales with collection size. The proposed fix (load custom_sorts once and derive both the orders map and dropdown options in memory, sorting by name in Ruby) is sound.

## C25. CSV/JSON export materialises the whole collection in memory

**Low** · _performance_ · `app/controllers/profiles_controller.rb` - 44-51

> **Principle:** Loading huge collections into memory (performance.md: use find_each / stream large results)

**Finding.** The csv and json formats build the full result set as a single in-memory string/array via CollectibleExporter (CSV.generate over the whole relation, or .map to an array) and send_data it whole. The exports deliberately skip pagination, so memory and response time grow linearly with collection size and there is no streaming or batching bound.

**Fix.** For the export paths, iterate with find_each/in_batches and stream the response (e.g. an enumerator-backed streaming body) rather than loading every collectible and building the entire payload in memory. Given personal collections are typically small this is a design safeguard rather than an urgent fix, so keep it simple until the size warrants it.

**Verified** (confirmed, severity Low). Verified at app/controllers/profiles_controller.rb:44-51. The csv format calls `send_data CollectibleExporter.new(collectibles).to_csv` and the json format calls `render json: CollectibleExporter.new(collectibles).as_data`, both sending the full set (the line-39 comment confirms exports deliberately skip pagination, unlike the paginated HTML path). In app/services/collectible_exporter.rb, `to_csv` (lines 16-40) uses `CSV.generate` over `@collectibles.each` to build one in-memory string, and `as_data` (lines 43-47) uses `.map` to build a full in-memory array. No `find_each`/`in_batches`/streaming is used, so memory and response time grow linearly with collection size, exactly as claimed. Severity Low is correct: the proposed fix itself notes personal collections are typically small, so this is a design safeguard rather than an urgent fix. (Minor mitigation: the controller passes a relation with `includes(:labels)`, so the `labels.map(&:name)` calls are eager-loaded and not an N+1; this does not affect the core memory-materialisation claim.)

## C26. criteria_are_unique loads all a user's custom sorts and compares in Ruby

**Low** · _performance_ · `app/models/custom_sort.rb` - 60

> **Principle:** Set work in Ruby instead of the database (performance.md: do set work in the DB)

**Finding.** Validation loads every other custom_sort for the user (user.custom_sorts.where.not(id: id)) and scans them in Ruby with .any? comparing serialised criteria. This runs on every save. The data volume is tiny (a handful of custom sorts per user), so the cost is negligible, but it is Ruby-side set work that a scoped existence check could avoid.

**Fix.** Acceptable as-is given the tiny cardinality; if it ever mattered, compare against a canonicalised criteria representation stored on the row and use a database uniqueness check (e.g. a unique index on user_id + normalised criteria) instead of loading and looping.

**Verified** (confirmed, severity Low). Confirmed at app/models/custom_sort.rb:60. The `criteria_are_unique` validation runs `user.custom_sorts.where.not(id: id).any? { |other| other.criteria == criteria }`. Because `.any?` is passed a block, ActiveRecord loads every one of the user's other custom_sorts into Ruby and iterates, comparing the serialised `criteria` in Ruby rather than in the database. This runs on every save (it's registered via `validate :criteria_are_unique` on line 8). The description matches the code exactly: Ruby-side set work a scoped existence check could avoid. Low severity is correct: a user has only a handful of custom sorts (loading them is cheap, no pagination or N+1 across records), and the criteria are stored as a serialised column not trivially indexable, so the practical cost is negligible and the proposed fix (canonicalised column + unique index) would be over-engineering at this cardinality. The finding itself acknowledges this, so it reads as a note rather than an actionable defect. Real but genuinely Low.

## C27. Type switch in exporter duplicates each collectible's own field knowledge

**Low** · _refactoring_ · `app/services/collectible_exporter.rb` - 64-86

> **Principle:** Switch Statements / Replace Conditional with Polymorphism (Fowler)

**Finding.** type_specific switches on the collectible's class (when VideoGame/BoardGame/Book) to pick which columns to emit, yet each subclass already declares applicable_fields. The mapping is a second, drifting source of truth for which fields belong to which type (e.g. BoardGame here omits the system column, VideoGame omits min/max_players), duplicating what the STI hierarchy already answers.

**Fix.** Drive the type-specific hash from collectible.applicable_fields (Replace Conditional with Polymorphism), e.g. collectible.applicable_fields.index_with { |f| collectible.public_send(f) }, so exporter output follows the model instead of restating it.

**Verified** (confirmed, severity Low). Confirmed at app/services/collectible_exporter.rb:64-86. The `type_specific` method switches on the collectible's class (`when VideoGame/BoardGame/Book`) and hard-codes, per branch, which optional columns to emit. Each STI subclass already declares this via `applicable_fields` (app/models/video_game.rb:6-8, board_game.rb:6-8, book.rb:6-8), so the exporter is a second, hand-maintained source of truth for the same type-to-fields mapping. That is a genuine Switch Statements / Replace Conditional with Polymorphism smell, and the proposed fix `collectible.applicable_fields.index_with { |f| collectible.public_send(f) }` is behavior-preserving: I diffed all three branches against each subclass's `applicable_fields` and they match exactly (VideoGame: system, local_multiplayer, online_multiplayer, cooperative, competitive; BoardGame: min_players, max_players, cooperative, competitive; Book: author).\n\nTwo reasons I downgrade to Low. First, the finding's concrete drift examples are wrong: it cites \"BoardGame here omits the system column\" and \"VideoGame omits min/max_players\" as evidence of a drifting source of truth, but those are cases where the exporter correctly agrees with the models (`system` belongs to VideoGame, not BoardGame; min/max_players belong to BoardGame, not VideoGame). There is currently zero divergence between the two sources, so the harm is entirely latent (future edits to a subclass's fields not mirrored here), not an active bug. Second, the affected surface is narrow and untested: only `as_data` uses `type_specific`; `to_csv` flattens every column unconditionally, and there are no specs for CollectibleExporter. Real structural duplication, exact citation, but latent risk on a low-criticality path with an overstated \"drift\" narrative make Low the right severity rather than Medium.

## C28. Negated/positive clause-building duplicated between two player matchers

**Low** · _refactoring_ · `app/queries/collectible_search.rb` - 170-198

> **Principle:** Duplicated Code (Fowler)

**Finding.** match_players and match_player_field share the same shape: build a bounds list, then in the negated branch wrap each as "(col IS NULL OR NOT (col op n))" joined by OR and in the positive branch join "col op n" by AND. Only the bound tuple arity differs, so the NULL-safe clause assembly is written twice.

**Fix.** Extract a helper, e.g. numeric_clause(scope, bounds_as_col_op_n, negated:), and have player_bounds and the min/max path both produce [col, op, n] tuples the helper consumes.

**Verified** (confirmed, severity Low). Verified against app/queries/collectible_search.rb:170-198. match_players (170-182) and match_player_field (187-198) both build a bounds list, then in the negated branch map each bound to "(collectibles.COL IS NULL OR NOT (collectibles.COL op n))" joined by " OR ", and in the positive branch map to "collectibles.COL op n" joined by " AND ". The only difference is tuple arity: match_players uses [col, op, n] (column varies per bound, produced by player_bounds), while match_player_field uses [op, n] with a fixed `column` arg. A grep for "IS NULL OR NOT" confirms exactly two occurrences (lines 176 and 192), so the NULL-safe clause assembly is genuinely written twice — a real instance of Fowler's Duplicated Code. The proposed fix is sound: player_bounds already yields [col, op, n] tuples, and the min/max path can map its [op, n] bounds to [column, op, n], letting both feed a shared numeric_clause(scope, tuples, negated:) helper. Severity Low is correct: it's a ~4-line structural duplication across two adjacent private methods, no correctness impact; the main cost is connascence of algorithm (the negation SQL shape must change in lockstep at both sites), which is a maintainability nit rather than a defect.

## C29. "Remember viewer preference via update_columns" pattern duplicated across controllers

**Low** · _refactoring_ · `app/controllers/profiles_controller.rb` - 60-65

> **Principle:** Duplicated Code / Shotgun Surgery (Fowler)

**Finding.** remember_collection_preferences (profiles_controller.rb:60-65) and remember_collections_sort (collections_controller.rb:24-28) implement the same guarded update_columns idiom (only persist changed, whitelisted values without bumping updated_at). The rationale comment is copied in both. A change to how preferences are persisted is scattered across two controllers.

**Fix.** Move the persistence to a single User method (e.g. User#remember_preferences(changes) that filters to actually-changed columns and uses update_columns), so both controllers call one place. This also relocates the model-touching logic off the controllers onto the model (Feature Envy).

**Verified** (confirmed, severity Low). Verified at the cited lines. profiles_controller.rb:60-65 (remember_collection_preferences) and collections_controller.rb:24-28 (remember_collections_sort) both implement the same guarded update_columns idiom: only persist a whitelisted preference when present and changed, using update_columns to skip validation and avoid bumping updated_at. The persistence contract (why update_columns is used) is duplicated across two controllers, so a change to how preferences persist would require editing both — a genuine Duplicated Code / Shotgun Surgery smell. No User method currently centralises this, so the proposed User#remember_preferences fix is applicable and also relieves the controllers' Feature Envy of model persistence internals. One inaccuracy: the claim that "the rationale comment is copied in both" is overstated — the comments (profiles 57-59, collections 21-23) express the same rationale but are not verbatim; the collections one additionally mentions collection_updated_at. This detail is imprecise but does not undermine the substance. Low severity is correct: two tiny methods, low churn, conceptual rather than literal duplication, no correctness risk.

## C30. "Store the complement of the shown set" logic repeated in three settings paths

**Low** · _refactoring_ · `app/controllers/settings_controller.rb` - 26-29

> **Principle:** Duplicated Code (Fowler)

**Finding.** The same invert-a-checkbox-set idiom (take the ticked "shown" values intersected with an allowlist, store the allowlist-minus-shown complement as the hidden set) appears in SettingsController#settings_params (26-29, hidden_link_keys), Settings::SortingController#update (12-13, hidden_default_sorts) and structurally again in the labels allowlist filter (labels_controller.rb:50). Each hand-rolls Array(...) & ALLOWED and the subtraction.

**Fix.** Extract a small helper such as hidden_complement(param, allowed:) (in ApplicationController or a concern) that returns allowed - (Array(param) & allowed); call it from all three, so the shown-to-hidden inversion lives in one place.

**Verified** (confirmed, severity Low). Partially confirmed, but overstated. The core shown-to-hidden inversion idiom (shown = Array(param) & ALLOWED; store ALLOWED - shown as the hidden set) genuinely repeats in exactly TWO places: SettingsController#settings_params (settings_controller.rb:27-28, hidden_link_keys) and Settings::SortingController#update (settings/sorting_controller.rb:12-13, hidden_default_sorts). These two are near-identical and the proposed helper `hidden_complement(param, allowed:) = allowed - (Array(param) & allowed)` fits both cleanly.

The claim of a THIRD occurrence is inaccurate. The labels site is at app/controllers/settings/labels_controller.rb:50 (not labels_controller.rb:50 as cited), and it only does `Array(permitted[:collectible_types]) & Collectible::TYPES` - a plain allowlist intersection with NO complement subtraction. It stores the intersection itself, not allowlist-minus-selection, so it is a different operation. The proposed helper would NOT apply there, and "call it from all three" is wrong. The finding hedges ("structurally again", "labels allowlist filter"), but the shared code is only the `Array(x) & ALLOWED` sanitization fragment, not the inversion.

Severity should be Low, not Medium: the true duplication is two occurrences of a 2-line idiom (Fowler's Rule of Three not met for the full pattern), low risk, and the extraction is a minor tidy-up rather than a structural concern. One citation path is also wrong. Real but minor and mis-scoped.

## C31. CSV header list and row array coupled by position

**Low** · _refactoring_ · `app/services/collectible_exporter.rb` - 6-40

> **Principle:** Connascence of Position / Data Clump (Fowler)

**Finding.** CSV_HEADERS (16 entries) and the per-row array in to_csv must stay index-aligned by hand; a header inserted or reordered without matching the row silently mislabels a column. The two lists are the strongest form of positional connascence, made worse by their distance in the file.

**Fix.** Define the export as an ordered mapping of header => extractor (e.g. an array of [header, ->(c){...}] pairs, or an ordered hash), then derive both CSV_HEADERS and each row from it so header and value can never drift.

**Verified** (confirmed, severity Low). Confirmed at app/services/collectible_exporter.rb. CSV_HEADERS (lines 6-10) lists 16 headers, and the per-row array in to_csv (lines 20-37) emits 16 values in the exact same positional order. The two are aligned only by index and by hand, and sit ~10 lines apart, so inserting or reordering a header without a matching change to the row array would silently mislabel a column. This is genuine Connascence of Position (positional coupling between the header list and the value list), exactly as described. The proposed fix (an ordered header => extractor mapping from which both CSV_HEADERS and each row are derived) is a sound, standard remedy that removes the drift risk. Severity Low is appropriate: the coupling is real and a maintainability hazard, but it is confined to one small (16-field), cohesive service, is a smell rather than a correctness bug, and carries low blast radius in this prototype.

## C32. as_data assembles per-item hashes with a type switch instead of the exporter row model

**Low** · _refactoring_ · `app/services/collectible_exporter.rb` - 43-86

> **Principle:** Divergent Change (Fowler)

**Finding.** to_csv and as_data are two independent serialisations that must both change when a collectible field is added, and as_data's type_specific is the same class switch flagged above. The exporter changes for two reasons (CSV shape and JSON shape) that duplicate the field-to-type knowledge.

**Fix.** Once field selection is driven by applicable_fields (see the type-switch finding), express both CSV and JSON from that single per-collectible field map so adding a field touches one place.

**Verified** (confirmed, severity Low). Confirmed at app/services/collectible_exporter.rb:43-86. `as_data` (lines 43-47) builds per-item hashes via `common` + `type_specific`, and `type_specific` (lines 64-86) is a `case collectible when VideoGame/BoardGame/Book` class switch, matching the "same class switch flagged above" reference. The Divergent Change diagnosis holds: `to_csv` (lines 16-40) is a separate, independent serialisation that hard-codes the full flat field list, so adding a collectible field forces edits in both `to_csv` and `as_data`/`type_specific`, and the field-to-type knowledge is duplicated across the two shapes (e.g. `cooperative`/`competitive` appear in both VideoGame and BoardGame branches plus the CSV row). The proposed fix (drive both from one per-collectible field map) is coherent. Severity Low is right: the duplication is real but confined to one ~87-line class with both serialisations co-located; it is a maintainability risk (forgetting to update one path), not a correctness or structural defect.

## C33. Create actions rely on in-Ruby uniqueness validation with no rescue for the DB-index race

**Low** · _reliability_ · `app/controllers/settings/profile_accesses_controller.rb` - 15-21

> **Principle:** reliability: idempotency / unique-constraint race (RecordNotUnique)

**Finding.** ProfileAccess (here), Label (labels_controller.rb:12-14), CustomSort (custom_sorts_controller.rb:12-18) and ShareLink (share_links_controller.rb:14-22) all build+save and handle the ordinary duplicate via the model uniqueness validation returning false. But the validation is a SELECT-then-INSERT check; a concurrent double-submit slips past it and hits the unique index (e.g. index_profile_accesses_on_owner_id_and_viewer_id), raising an unhandled RecordNotUnique 500. Lower severity than the follow case because a duplicate is already reported gracefully in the common (non-concurrent) path.

**Fix.** Rescue ActiveRecord::RecordNotUnique in these create actions and render the same 'already exists' feedback the validation produces, so the concurrent-submit path degrades to a friendly message rather than a 500. A shared rescue_from in a settings base controller would cover all four.

**Verified** (confirmed, severity Low). Verified at app/controllers/settings/profile_accesses_controller.rb:15-21: `current_user.granted_accesses.build(viewer:)` then `access.save` with no rescue. ProfileAccess has `validates :viewer_id, uniqueness: { scope: :owner_id }` (a SELECT-then-INSERT check) backed by unique DB index `index_profile_accesses_on_owner_id_and_viewer_id` (db/schema.rb:82). A concurrent double-submit can pass the validation and hit the index, raising an unhandled ActiveRecord::RecordNotUnique 500. Confirmed the same real pattern for Label (labels_controller.rb create action lines 11-20; validation `uniqueness: { scope: :user_id, case_sensitive: false }` + unique index `index_labels_on_user_id_and_name`, schema:73) and CustomSort (custom_sorts_controller.rb:12-18; name uniqueness scope user_id + unique index index_custom_sorts_on_user_id_and_name, schema:52). ApplicationController has no rescue_from, so a shared settings-base rescue_from would indeed be a clean fix. One correction: the ShareLink claim is WRONG. share_links_controller.rb:14-22 does build+save with no rescue, and there is a unique index on token (schema:94), but the token is a random SecureRandom.urlsafe_base64(16) assigned in a before_validation, not derived from user input. A concurrent double-submit generates two DIFFERENT tokens, so it will not collide on the unique index; RecordNotUnique here would require an astronomically unlikely SecureRandom repeat, not a double-submit. So the race genuinely applies to 3 of the 4 controllers, and the primary cited location is accurate. Severity Low is right: the duplicate is already reported gracefully in the non-concurrent path, the window is a narrow concurrent double-submit, and the worst outcome is a 500 rather than data corruption or an access-control issue (this is prototype code).

## C34. Custom-sort duplicate-criteria rule has no database backstop

**Low** · _reliability_ · `app/models/custom_sort.rb` - 57-61

> **Principle:** reliability: idempotency (unique constraint as last line of defence)

**Finding.** criteria_are_unique enforces 'no two of a user's custom sorts share the same criteria' by loading siblings and comparing in Ruby. Unlike the name/label/access/follow uniqueness rules, there is no unique index on the criteria, so this is a pure check-then-act with no last line of defence: two concurrent creates with identical criteria both pass the Ruby check and both persist, producing the exact duplicate the rule exists to prevent. The effect is cosmetic (a duplicated dropdown option), so severity is low.

**Fix.** If the invariant matters, back it with a unique index on a normalised representation of criteria (e.g. a generated/serialised column) so the database rejects the race; otherwise document that the rule is best-effort and not concurrency-safe. Given the benign impact, accepting it with a comment is a reasonable alternative to adding the index.

**Verified** (confirmed, severity Low). Confirmed at app/models/custom_sort.rb:57-61. `criteria_are_unique` is a pure check-then-act: `user.custom_sorts.where.not(id: id).any? { |other| other.criteria == criteria }` loads siblings and compares in Ruby, with no database backstop. The schema (db/schema.rb) confirms the comparison: `custom_sorts` has a unique index only on `[user_id, name]`, while the sibling uniqueness rules the finding cites are all DB-backed — `labels` unique `[user_id, name]`, `follows` unique `[follower_id, followed_id]`, `profile_accesses` unique `[owner_id, viewer_id]`. So criteria uniqueness is the lone rule without a unique index, and two concurrent creates with identical criteria could both pass the Ruby check and both persist. Severity Low is right: the impact is a duplicated dropdown option (cosmetic), and because `criteria` is an order-significant JSON array, a normalised unique index is non-trivial, so the proposed accept-with-a-comment alternative is reasonable. The Ruby check still guards the common sequential path, so it is best-effort rather than absent — the finding states this accurately.

## C35. Stringly-typed "custom-N" sort key agreed by convention across three files

**Low** · _solid_ · `app/models/custom_sort.rb` - 14-16

> **Principle:** Connascence of Meaning/Algorithm (Page-Jones), spread across module boundaries

**Finding.** CustomSort#key builds "custom-#{id}"; User#collectibles_sort_is_known independently re-encodes that format as the regex /\Acustom-\d+\z/ (user.rb:117); CollectibleSearch keys off the same string via `@custom_sorts.key?` (collectible_search.rb:114,118). Three separate points must agree on the format, and the coupling is cross-file, so a change to the key scheme silently breaks validation and lookup. This is strong connascence kept non-local.

**Fix.** Centralise the format on CustomSort: expose class-level helpers such as `CustomSort.key_for(id)` and `CustomSort.key?(string)` (or a `custom_key?` predicate), and have the User validation and CollectibleSearch call them instead of re-deriving the pattern. That collapses the coupling to connascence of Name against one owner.

**Verified** (confirmed, severity Low). Verified against the code. The core coupling is real: the "custom-N" sort-key format is literally encoded in two independent places across module boundaries — CustomSort#key builds "custom-#{id}" (app/models/custom_sort.rb:15) and User#collectibles_sort_is_known re-encodes it as the regex /\Acustom-\d+\z/ (app/models/user.rb:117). These must agree, and a change to the key scheme would silently break sort validation. That is genuine connascence of meaning/algorithm kept non-local, and the proposed fix (centralise CustomSort.key_for / CustomSort.key?) is apt.

Two caveats on the claim. First, the "three files must agree on the format" framing overstates CollectibleSearch's role. Its cited lines are correct (app/queries/collectible_search.rb:114 `@custom_sorts.key?(sort)` and :118 `@custom_sorts.key?(@sort)`), but it does not independently re-encode the format — @custom_sorts is a hash whose keys are produced by CustomSort#key via User#custom_sort_orders (user.rb:74). It only does hash membership on already-built keys, so it is coupled to the key string but not to its literal shape. So there is one true owner (CustomSort#key) and one independent re-encoding (the user.rb regex), plus two stale-prone doc comments hardcoding "custom-5" (collectible_search.rb:100, user.rb:72). Second, the CollectibleSearch citation omitted its path (it is app/queries/, not app/, though the line numbers are right).

I lowered severity from Medium to Low: the blast radius is small (a single literal re-encoding beyond the owner, all within one app's models/queries), the key is a stable simple string, and any format-scheme change would fail loudly in the validation test suite rather than corrupt data. The finding is worth fixing but sits at the low end.

## C36. User model depends upward on query-object sort constants

**Low** · _solid_ · `app/models/user.rb` - 48,65-66,117,123

> **Principle:** Dependency direction / Dependency Inversion (stable layer reaching into a higher one)

**Finding.** User validates `collections_sort` against CollectionSearch::SORTS (line 48) and `collectibles_sort` against CollectibleSearch::SORTS (line 117), and sort_options reads CollectibleSearch::DEFAULT_OPTIONS (lines 65-66,123). A persistent domain model (a comparatively stable, low layer) reaches up into query objects (a higher, more volatile layer) for its validity rules, so changes to a query object's sort catalogue ripple into the model. The direction of dependence is inverted from the usual model-is-depended-on layering.

**Fix.** Have the query objects own their sort vocabulary but expose it to the model through a narrow, model-facing seam (e.g. a `Sortable`/`SortCatalogue` value or a method the model calls), or move the closed set of sort keys into the domain layer that both the model and the query object depend on. Even keeping the constants where they are, funnelling access through one intention-revealing method (`CollectibleSearch.valid_sort?(key)`) narrows the role the model depends on (Interface Segregation) instead of it reaching into raw hashes.

**Verified** (confirmed, severity Low). Verified against /Users/yjas/code/github.com/yndajas/collection/app/models/user.rb. Every cited location checks out: line 48 `validates :collections_sort, inclusion: { in: CollectionSearch::SORTS }`; lines 65-66 read `CollectibleSearch::DEFAULT_OPTIONS` in `sort_options`; line 117 references `CollectibleSearch::SORTS.key?(...)` inside the `collectibles_sort_is_known` custom validator; line 123 reads `CollectibleSearch::DEFAULT_OPTIONS.keys` in `hidden_default_sorts_are_known`. I confirmed the constants genuinely live in the query layer: `app/queries/collectible_search.rb` (SORTS:31, DEFAULT_OPTIONS:44) and `app/queries/collection_search.rb` (SORTS:33), both subclasses of `QuerySearch`. So a persisted ActiveRecord model (stable, low layer) does import its validation vocabulary from query objects (higher, more volatile layer), which is the inverted dependency direction the finding describes. The claim is accurate and non-speculative, and the proposed fix (a narrow model-facing seam such as `CollectibleSearch.valid_sort?`, or lifting the shared sort catalogue into a layer both depend on) is sound. The attribution is correct: the collectibles validation is the custom validator at line 117, not the `validates` at line 48 (which is the collections one). Severity Low is right: this is a coupling/dependency-direction observation with no correctness, security, or behavioural impact, and the coupling is compile-time-visible and stable; it does not warrant Medium.

## C37. COUNT_SORTS re-encodes the closed collectible-type set as a separate mapping

**Low** · _solid_ · `app/queries/collection_search.rb` - 37

> **Principle:** Connascence of Value / duplicated closed set (model the domain once)

**Finding.** COUNT_SORTS = { "video_games" => "video_game", ... } hard-codes the three STI type strings a third time (after Collectible::TYPES and the TYPE_ALIASES maps). The valid collectible types are a fixed closed set owned by Collectible, but each new type must be added here too or the "Most <type>" sort silently omits it, coupling this constant by value to the type list elsewhere.

**Fix.** Derive the count-sort keys from the canonical type list (e.g. build them from Collectible::TYPES via pluralize, or from the shared alias resolver) so adding a type extends the sorts automatically, rather than maintaining a parallel literal map.

**Verified** (confirmed, severity Low). Confirmed at app/queries/collection_search.rb:37. COUNT_SORTS = { "video_games" => "video_game", "board_games" => "board_game", "books" => "book" }.freeze re-encodes the closed collectible-type set a third+ time. The canonical set is Collectible::TYPES = %w[video_game board_game book] (app/models/collectible.rb:21); CollectibleSearch::TYPE_ALIASES (collectible_search.rb:87-94) already maps singular/plural aliases to those types. COUNT_SORTS duplicates the same three types by value in a parallel plural-key->singular-value map, so adding a type requires a separate edit here or the "Most <type>" sort silently omits it. This is Connascence of Value over a closed set Collectible owns; the term is applied correctly. The fix is viable: COUNT_SORTS[@sort] is only used at line 57 (count_order(COUNT_SORTS[@sort]) guarded by COUNT_SORTS.key?(@sort)), and resolve_count_type already derives type from TYPE_ALIASES via singularize, so the keys could be built from Collectible::TYPES.map { |t| [t.pluralize, t] } or the alias resolver. Low severity is correct: only 3 stable types, prototype code, failure mode is a missing sort option (not wrong results or a crash), caught immediately on adding a type. Note: SORT_OPTIONS (line 26) also carries the plural keys but needs genuine per-type human labels ("Most video games"), so one edit point survives any fix; COUNT_SORTS is the pure-mechanical duplicate the finding rightly targets.

## C38. Non-deterministic and time-dependent seams sit inline in controllers, resisting isolated tests

**Low** · _testing_ · `app/controllers/root_controller.rb, app/controllers/settings/labels_controller.rb, app/controllers/settings/share_links_controller.rb, app/controllers/profiles_controller.rb` - root_controller.rb:21; labels_controller.rb:8; share_links_controller.rb:16; profiles_controller.rb:46

> **Principle:** F.I.R.S.T. (Repeatable) / Erratic Test risk (Meszaros); double what is non-deterministic (classicist rule)

**Finding.** RootController uses Arel.sql("RANDOM()") to pick @random_collectible, LabelsController seeds a colour with Label::COLOURS.sample, and share-link expiry / export filenames use Time.current / Date.current. When tests are eventually added, these non-deterministic and clock-bound points (randomness, current time/date) will make request specs flaky or force awkward stubbing, because the effect is embedded in the controller rather than behind a seam the test can control. This is the classic 'double what is non-deterministic' case.

**Fix.** Not urgent while these paths are untested, but when adding coverage: freeze time (Rails ActiveSupport::Testing::TimeHelpers / Timecop) for expiry and filename assertions, and assert the random/sample selection by its invariant (e.g. @random_collectible differs from @newest and belongs to the user) rather than a fixed row, or inject the selection so it can be stubbed.

**Verified** (confirmed, severity Low). Citations verified against the actual code, all accurate: root_controller.rb:21 uses `own.where.not(id: @newest_collectible).order(Arel.sql("RANDOM()")).first` (DB randomness); labels_controller.rb:8 uses `current_user.labels.build(colour: Label::COLOURS.sample)` (random pick); share_links_controller.rb:16 uses `Time.current + duration` for `expires_at` (clock-bound); profiles_controller.rb:46 uses `Date.current.iso8601` in the CSV filename (clock-bound). The four non-deterministic/clock-bound seams genuinely sit inline in the controllers as described, so the finding is REAL and its factual basis is sound.

Severity is correctly Low, and the finding itself concedes it is not urgent. Two caveats keep it firmly at the bottom of Low rather than anything higher: (1) it is explicitly forward-looking/latent — there is no current test, flaky or otherwise, so no problem manifests today; and (2) the "resists isolated tests" framing is somewhat overstated. `Time.current`/`Date.current` inline is idiomatic Rails and trivially controlled by first-class tooling (`ActiveSupport::Testing::TimeHelpers` `travel_to`/`freeze_time`), and the random/`sample` picks are assertable by invariant (e.g. `@random_collectible != @newest_collectible` and belongs to the user) with no refactor or injection needed. So these are routine, well-worn testability concerns, not a structural defect. Confirming as real at Low; the proposed fixes are appropriate.

---

# UI-craft findings (31)

## U1. 2FA QR code has no text alternative and no manual key fallback

**High** · _content_ · `app/views/two_factor_authentication/setup/show.html.erb` - 5-7

> **Principle:** WCAG 1.1.1 Non-text Content (Level A)

**Finding.** The setup key is conveyed only as an inline SVG QR code (@qrcode from RQRCode ... as_svg, injected raw). The SVG carries no role="img" and no accessible name, and no plaintext secret is offered as an alternative, so a screen-reader user, or anyone who cannot scan a code with a camera, cannot complete two-factor setup at all. This is a content-perceivability barrier that blocks a whole task.

**Fix.** Also render the provisioning secret as selectable text (e.g. a <code> block with the base32 key and issuer/account) alongside the QR code, introduced by a sentence like "Can't scan? Enter this key manually into your authenticator app:". Give the SVG itself role="img" with an aria-label such as "QR code for two-factor authentication setup", or mark it aria-hidden="true" once the text key is present.

**Verified** (confirmed, severity High). Verified at app/views/two_factor_authentication/setup/show.html.erb:5-7. The div wraps `<%= @qrcode %>`, which the controller (setup_controller.rb:27) builds via `RQRCode::QRCode.new(@provisioning_uri).as_svg(module_size: 4).html_safe` and injects raw. I inspected the actual RQRCode `as_svg` output: it is a bare `<svg>` of `<rect>` elements with no `<title>`, no `role="img"`, and no `aria-label`, so it exposes no accessible name. A grep across the 2FA views found no plaintext secret, no provisioning key, and no "enter manually" fallback; the only instruction is "Scan the following QR code with your authenticator app" (line 3). A screen-reader user, or anyone who cannot scan with a camera, therefore cannot complete 2FA setup at all - a genuine WCAG 1.1.1 Non-text Content (Level A) failure that blocks a whole security-critical task. Severity High is correct: Level A, no workaround, blocks task completion on a security flow. The proposed fix is sound and cheap, since `@provisioning_uri` and `current_user.otp_secret` are already available in the controller: render the base32 key as selectable text and give the SVG an accessible name (or aria-hidden once the text key is present).

## U2. No visible focus indicator defined anywhere in the stylesheet

**High** · _visual-design_ · `app/assets/stylesheets/application.css` - 98-315, whole file

> **Principle:** WCAG 2.4.7 Focus Visible (AA); also 2.4.11 Focus Not Obscured (AA)

**Finding.** The stylesheet restyles links, buttons, .button-as-link, .view-toggle, .tag--link, .search-help summary and form controls but never defines a :focus or :focus-visible style. Keyboard users get only the browser default outline, which is easily lost against the custom fills/borders (e.g. brand buttons, the segmented view-toggle whose overflow:hidden can clip a default outline) and is not reinforced anywhere. This is a whole-scope failure affecting every interactive control on every screen and theme.

**Fix.** Add a global, high-contrast focus style, e.g. :focus-visible { outline: 3px solid var(--brand); outline-offset: 2px; } and verify it is visible in all seven themes (especially monochrome, where brand==text, so use a colour that contrasts with the focused control's own background, and remove overflow:hidden clipping on .view-toggle or add an inner focus style). Follow the GOV.UK focus-state pattern (solid outline plus offset).

**Verified** (confirmed, severity High). Verified against /Users/yjas/code/github.com/yndajas/collection/app/assets/stylesheets/application.css (the only stylesheet — no other .css/.scss exists in app/). grep for "focus" across app/assets/ returns zero matches, and the only "outline" occurrence is a comment on line 53 about tag borders, not a focus rule. So the core claim holds exactly: the file restyles links (line 98), buttons (158-178), .button-as-link (184-194), .view-toggle (310-315), .tag--link (336-341), .search-help > summary (374-381), and form controls (203-229), but never defines any :focus or :focus-visible style anywhere. The mitigating-context claims also check out: .view-toggle sets overflow: hidden (line 310) and fills its active segment with --brand, so the browser default outline on the inner <a> segments can be clipped/lost; and the monochrome themes (471-548) set --brand == --text, which the proposed fix correctly calls out. This is a genuine WCAG 2.4.7 Focus Visible (AA) failure across every interactive control, screen, and theme, with the custom fills and overflow:hidden actively degrading the only fallback (the browser default ring). High severity is right for a whole-scope AA keyboard-accessibility failure. Minor caveats, not material: (1) the cited range :98-315 is slightly under-inclusive since affected controls also appear beyond line 315 (search-help summary 374-381, pagination links 674-681), but the finding explicitly scopes itself to the "whole file", so this is accurate in spirit; (2) the secondary 2.4.11 Focus Not Obscured cite is speculative — there are no sticky/overlay elements in this stylesheet that would obscure a focused control — but the primary 2.4.7 finding fully justifies the High rating on its own.

## U3. No skip-to-main-content link and no targetable main

**Medium** · _accessible-code_ · `app/views/layouts/application.html.erb` - 22-46

> **Principle:** WCAG 2.4.1 Bypass Blocks (A)

**Finding.** The header repeats the full site nav on every page, but there is no skip link and the <main class="site-main"> has no id, so keyboard and screen-reader users must tab through the whole nav on every page to reach content.

**Fix.** Add a visually-hidden-until-focused skip link as the first focusable element in <body> (e.g. <a href="#main-content" class="skip-link">Skip to main content</a>) and give <main> id="main-content" plus tabindex="-1"; add a .skip-link style that becomes visible on :focus.

**Verified** (confirmed, severity Medium). Verified against app/views/layouts/application.html.erb. The citation is accurate: a <nav class="site-nav"> (lines 26-37) repeats 3-4 site links on every page, <main class="site-main"> (line 41) has no id and no tabindex, and a codebase-wide grep for "skip", "skip-link", "main-content", and "#main" across app/ returns nothing, so no skip link or targetable main exists. WCAG 2.4.1 Bypass Blocks (A) is the correct criterion and is failed for keyboard-only users, who lack the ARIA-landmark bypass that the semantic <header>/<nav>/<main> elements do give screen-reader users. The proposed fix (visually-hidden-until-focused skip link as first focusable element, plus id="main-content" and tabindex="-1" on <main>) is the standard, correct remedy. I downgraded severity from High to Medium: the nav is short (only 3-4 links, not a large menu), AT users have landmark navigation as a partial mitigation, and the impact is repeated minor friction for keyboard-only users rather than a hard blocker. It is still a genuine Level A conformance gap worth fixing. Note the cited line range 22-46 is slightly loose (header/nav spans 22-39, main spans 41-46) but covers the relevant markup.

## U4. Multiple nav landmarks share no distinct accessible names

**Medium** · _accessible-code_ · `app/views/layouts/application.html.erb` - 26

> **Principle:** WCAG 1.3.1 Info and Relationships (A) / GOV.UK landmark labelling

**Finding.** The primary site nav (.site-nav) has no aria-label, and other nav landmarks coexist with it on the same page (settings _nav subnav, breadcrumb nav on collectible show, pagination nav). With several unlabelled/duplicately-named <nav> regions, a screen reader's landmark list is ambiguous ('navigation', 'navigation', ...).

**Fix.** Give each nav a unique label: aria-label="Primary" on .site-nav, aria-label="Settings" on the settings subnav, aria-label="Breadcrumb" on the breadcrumb nav. Pagination already has aria-label="Pagination" - use it as the reference.

**Verified** (confirmed, severity Medium). Verified against the actual markup. At app/views/layouts/application.html.erb:26 the primary nav is `<nav class="site-nav">` with no aria-label. The other cited nav landmarks also exist and are unlabelled: settings subnav at app/views/settings/_nav.html.erb:1 (`<nav class="subnav">`, no aria-label) and breadcrumb at app/views/collectibles/show.html.erb:4 (`<nav class="breadcrumb muted">`, no aria-label). Pagination at app/views/application/_pagination.html.erb:3 already has aria-label="Pagination", exactly as the finding states. Because the settings subnav, breadcrumb, and pagination all render inside the same layout that holds .site-nav, real pages carry two or more nav landmarks whose accessible name is just "navigation", so a screen reader's landmark list is ambiguous - a genuine WCAG 1.3.1 (Info and Relationships) issue. The proposed fix (unique aria-label per nav, using the existing pagination label as the reference pattern) is correct. Medium is appropriate: it degrades screen-reader orientation/navigation efficiency but does not block access to any content, since every nav's links remain reachable and their link text is distinguishable.

## U5. Settings subnav marks the current tab visually but not programmatically

**Medium** · _accessible-code_ · `app/views/settings/_nav.html.erb` - 2-5

> **Principle:** WCAG 1.3.1 / name-role-value status parity

**Finding.** The active settings tab gets only a .active CSS class; pagination sets aria-current="page" but this sibling navigation control does not, so a screen-reader user is not told which settings tab is current. This is the same 'state shown but not announced' gap as the view toggle.

**Fix.** Add aria-current="page" to the active link, e.g. pass aria: { current: ("page" if current_page?(settings_path)) } alongside the existing class.

**Verified** (confirmed, severity Medium). Verified at app/views/settings/_nav.html.erb:2-5: all four subnav links use only `class: ("active" if ...)` with no `aria-current`, so the active tab is shown visually but not exposed programmatically. The parity comparison holds: app/views/application/_pagination.html.erb:8 does set `aria-current="page"`, confirming the codebase applies the correct pattern elsewhere and this control does not. This is a genuine name-role-value / info-and-relationships gap (4.1.2 is the more precise criterion than the cited 1.3.1, but 1.3.1 is defensible) leaving screen reader users without a "you are here" cue. The proposed `aria: { current: ("page" if current_page?(...)) }` fix is the correct Rails idiom and matches the pagination approach. Medium is right: orientation is lost for screen reader users, but tab labels and destinations remain perceivable and operable, so it is not a full blocker.

## U6. Card partial hardcodes h3, skipping h2 on the collection page

**Medium** · _accessible-code_ · `app/views/collectibles/_collectible.html.erb` - 6

> **Principle:** WCAG 1.3.1 Info and Relationships (A) / heading order

**Finding.** The card title is an h3. On the homepage it sits under an h2 ('From your collection') and is fine, but on profiles/show the page goes h1 (collection title) straight to the grid of h3 cards with no intervening h2, skipping a heading level.

**Fix.** Either add an h2 (e.g. a visually-hidden 'Collectibles' heading) before the grid in profiles/show.html.erb, or make the card heading level a local passed to the partial so each context uses the correct level.

**Verified** (confirmed, severity Medium). Confirmed at app/views/collectibles/_collectible.html.erb:6 — the card title is a hardcoded `<h3 class="card__title">`. On the homepage (app/views/root/index.html.erb) the partial sits under an `<h2>` ('From your collection', line 21) below the `<h1>` (line 4), so h1 -> h2 -> h3 is correct there, matching the claim. But on the profile page (app/views/profiles/show.html.erb) the page has `<h1>` at line 10 and then renders the card grid at lines 63-68 with no intervening `<h2>`, so the card view goes h1 -> h3, skipping a level. In card view every card is affected. This is a genuine WCAG 1.3.1 Info and Relationships (Level A) heading-order failure on a core content page. The proposed fixes (add a visually-hidden `<h2>` before the grid, or pass the heading level as a local to the partial) are both valid. Severity Medium is right: a Level A violation on a primary page, but headings remain present and the fix is low-cost — not High (does not block content/functionality) and not Low (a real Level A failure, not cosmetic).

## U7. Two-factor pages have no unique title

**Medium** · _accessible-code_ · `app/views/two_factor_authentication/sessions/show.html.erb` - 1

> **Principle:** WCAG 2.4.2 Page Titled (A)

**Finding.** Neither 2FA view sets content_for :title, so both fall back to the layout default <title>Collection</title>, giving the verify and setup pages a non-unique, uninformative browser/tab title (setup/show.html.erb has the same omission).

**Fix.** Add <% content_for :title, "Verify two-factor authentication" %> (and "Set up two-factor authentication" in setup/show.html.erb), matching the h1 as every other page in the app does.

**Verified** (confirmed, severity Medium). Confirmed at the cited locations. app/views/layouts/application.html.erb:4 renders `<title><%= content_for(:title) || "Collection" %></title>`, so any view omitting `content_for :title` falls back to the generic "Collection". Both 2FA views omit it: sessions/show.html.erb (h1 "Verify two-factor authentication") and setup/show.html.erb (h1 "Set up two-factor authentication") contain no `content_for :title`, so both render an identical, non-unique, uninformative browser/tab title. Nearly every other view in the app (settings/*, collectibles/*, profiles/*, collections/index, root/index) does set `content_for :title`, so these two break the established pattern. This is a genuine WCAG 2.4.2 Page Titled (Level A) failure and the proposed fix (adding the content_for lines matching each h1) is correct. Severity Medium is appropriate: it is a Level A criterion affecting two pages, but the on-page h1 still orients users and it is a trivial, non-blocking fix, so it does not warrant High.

## U8. Flash messages are not live regions

**Medium** · _accessible-code_ · `app/views/layouts/application.html.erb` - 42-43

> **Principle:** WCAG 4.1.3 Status Messages (AA) / announcing change

**Finding.** Notice and alert flashes convey the result of an action (item saved, deleted, access granted) after a POST/redirect, but they are plain <p> elements with no role, so a screen reader only encounters them if the user happens to navigate back to the top of main; the outcome is not announced.

**Fix.** Add role="status" to .flash--notice and role="alert" to .flash--alert (or aria-live="polite"/"assertive") so the result of the action is announced.

**Verified** (confirmed, severity Medium). Verified at app/views/layouts/application.html.erb:42-43. Both flash messages render as plain `<p class="flash flash--notice">` and `<p class="flash flash--alert">` with no `role` or `aria-live` attribute; a codebase-wide grep confirms no live-region roles anywhere (only CSS styling for the classes at application.css:130-131). The flashes sit at the top of `<main>`, ahead of the yielded content, and convey action outcomes after Rails' POST/redirect/GET flow, so a screen reader user is not reliably given the result. The proposed fix (role="status" on notice, role="alert" on alert, or aria-live polite/assertive) is the standard, correct remedy. One caveat: strictly, WCAG 4.1.3 targets messages that appear without a change of context, whereas these arrive on a fresh page load after redirect, so the exact criterion mapping is slightly arguable; the practical barrier and fix are nonetheless real. Medium severity is right: a genuine gap in announcing action feedback to screen reader users, but non-blocking since the content remains present and reachable.

## U9. Error summaries are not focusable, not linked to fields, and don't move focus

**Medium** · _forms_ · `app/views/collectibles/_form.html.erb` - 9-18

> **Principle:** WCAG 3.3.1 Error Identification (A) / forms.md: show an error summary; GOV.UK error-summary pattern

**Finding.** On a failed submit the error list is a plain div/ul with no links to the offending fields, no focus management, and no role, so screen-reader and keyboard users are not taken to the errors and cannot jump to the field to fix. The same non-linking, non-focusing pattern repeats in every form's error block (collectibles/_import_fields.html.erb:9-11, settings/custom_sorts/_form.html.erb:4-9, settings/labels/edit.html.erb:6-8, settings/labels/index.html.erb:14-16, settings/show.html.erb:7-9).

**Fix.** Adopt an error-summary component: render each error as an in-page link to its field's id, wrap it in a container with tabindex="-1" and role="alert" (or move focus to it on load), and place it at the top of the form. Extract a shared partial so every form (collectible, import item, custom sort, label, settings) uses it.

**Verified** (confirmed, severity Medium). Verified at app/views/collectibles/_form.html.erb:9-18: the error block is a plain <div class="errors"> containing a <p> and a <ul> of full_messages as static <li> text. It has no role (no role="alert"), no tabindex, no in-page <a href="#field_id"> links to the offending fields, and there is no JavaScript anywhere to move focus to it on a failed submit (the only focus hint is autofocus:true on the title field, which pulls focus *past* the summary). The claim is accurate. The five sibling citations are also confirmed and are in fact weaker: _import_fields.html.erb:9-11, custom_sorts/_form.html.erb:4-9, labels/edit.html.erb:6-8, labels/index.html.erb:14-16, and settings/show.html.erb:7-9 all render <div class="errors"><%= errors ... to_sentence %></div> with no list, links, role, or focus handling. So the described defect (no field links, no focus management, no role) genuinely exists at the cited location and repeats everywhere. I lowered severity from High to Medium: the errors ARE present in text, so WCAG 3.3.1 Error Identification (A) is technically met; the cleanly-violated criterion is 4.1.3 Status Messages (AA) (no programmatic announcement of the failed submit), and the "link to field / move focus" parts are GOV.UK error-summary best practice rather than a Level A requirement. Real, repeated barrier, but not a strict Level A conformance failure, so Medium fits better than High. The proposed fix (shared error-summary partial with in-page links, a focusable role="alert" container, placed at the top of each form) is sound.

## U10. Field-level error messages are not associated with their inputs

**Medium** · _forms_ · `app/views/collectibles/_form.html.erb` - 9-83

> **Principle:** WCAG 1.3.1 Info and Relationships (A) / 3.3.1 (A); forms.md: associate each message with its field (aria-describedby + aria-invalid)

**Finding.** Errors are shown only in a summary block; individual inputs get no aria-invalid and no aria-describedby pointing at the message, so a screen-reader user focused on the Title field is not told it is in error or why. This holds across all forms including per-item import errors (_import_fields.html.erb:9-11) where the whole fieldset shares one undifferentiated error sentence.

**Fix.** Set aria-invalid="true" on each field with an error and render the field's message with an id referenced by the input's aria-describedby, so the message is announced when the field receives focus.

**Verified** (confirmed, severity Medium). Verified against both cited files. In app/views/collectibles/_form.html.erb the only error output is the summary block at lines 9-18 (a <ul> of @collectible.errors.full_messages); every input (title at 21-22, system, min/max_players, author, notes, checkboxes) is rendered with no aria-invalid and no aria-describedby. There is no per-field error markup anywhere in the file, so a screen-reader user focused on the Title field is not told it is invalid or why. In _import_fields.html.erb the claim also holds: lines 9-11 emit one shared <div class="errors"> using errors.full_messages.to_sentence for the whole fieldset, with no association to any individual input. Labels ARE correctly associated (form.label / label_tag with matching ids), so the failure is specifically the missing field-level error association (WCAG 1.3.1 / 3.3.1, A-level), not a broken form. Citation, location, and technical claim are all correct. I adjust severity from High to Medium: the errors are still presented visibly and as text in an accessible summary and the fields are properly labelled, so information is available (just not announced per-field on focus); it degrades rather than blocks the screen-reader experience. The proposed fix (aria-invalid=\"true\" plus a message id referenced by aria-describedby per errored field) is the correct remedy.

## U11. Main site navigation never shows the current section

**Medium** · _usability_ · `app/views/layouts/application.html.erb` - 26-37

> **Principle:** Nielsen: Visibility of system status; Krug navigation ("Where am I?")

**Finding.** The persistent top nav (My collection / All collections / Settings) never marks which section the user is currently in, so on any inner page the user cannot tell where they are from the primary nav. The settings subnav does highlight its active item, so the parity is inconsistent.

**Fix.** Add an `active` class (as the settings subnav and view-toggle already do) to the current top-nav item, e.g. compare `request.path.start_with?` for each destination and style `.site-nav a.active` like `.subnav a.active`.

**Verified** (confirmed, severity Medium). Verified at app/views/layouts/application.html.erb:26-37. The `.site-nav` renders "My collection" (l.28), "All collections" (l.29), and "Settings" (l.30) as plain `link_to` calls with no `active` class or current-section marking, so the primary nav never indicates the current section (Nielsen visibility of system status; Krug "Where am I?"). The parity claim is also accurate: app/views/settings/_nav.html.erb applies an `active` class per item (via `current_page?`/`request.path.start_with?`), and app/views/profiles/show.html.erb:5 does the same for the view toggle; CSS styles both distinctly (.subnav a.active at application.css:363, .view-toggle a.active at :314) while .site-nav has no active rule. The proposed fix matches existing codebase patterns exactly. Severity Medium is defensible: it is a genuine orientation gap made more noticeable by the internal inconsistency, though mitigated by only three self-descriptive nav items and page headings/titles that still orient the user (a Low case could also be argued).

## U12. Settings subnav is missing on settings sub-pages, losing orientation

**Medium** · _usability_ · `app/views/settings/labels/edit.html.erb` - 1-22

> **Principle:** Krug: consistent persistent navigation / "Where am I? Where can I go?"

**Finding.** Index-level settings pages (settings/show, labels/index, sorting/show, visibility/show) render the settings subnav, but the drill-down pages (labels/edit, labels/confirm_delete, custom_sorts/new, custom_sorts/edit) do not. The user drops out of the settings section with no subnav and no breadcrumb, so the only way back is a single 'Cancel' link.

**Fix.** Render `settings/nav` (and/or a breadcrumb) at the top of settings/labels/edit.html.erb, settings/labels/confirm_delete.html.erb, settings/custom_sorts/new.html.erb and settings/custom_sorts/edit.html.erb so the section context stays visible.

**Verified** (confirmed, severity Medium). Verified against the actual markup. The four index-level settings pages all render the subnav with a "Settings" heading: settings/show.html.erb:3-4, settings/labels/index.html.erb:3-4, settings/sorting/show.html.erb:3-4, settings/visibility/show.html.erb:3-4 (each has `<h1>Settings</h1>` followed by `<%= render "settings/nav" %>`). The four drill-down pages do NOT render `settings/nav` and instead use a page-specific `<h1>`: settings/labels/edit.html.erb (`<h1>Edit label</h1>`, only back route is the "Cancel" link at line 20), settings/labels/confirm_delete.html.erb (`<h1>Delete this label?</h1>`, "Cancel" at line 31), settings/custom_sorts/new.html.erb and edit.html.erb (both render `_form`, whose sole back link is "Cancel" at _form.html.erb:49). There is no breadcrumb in any of these views. The citation app/views/settings/labels/edit.html.erb:1-22 is accurate (file is 23 lines). The claim about the subnav disappearing and a single Cancel link being the only way back is correct. Severity Medium is right rather than High: each drill-down does supply a working Cancel link back to its section index, and these are shallow one-step flows, so the user is never fully stranded, only disoriented (Krug persistent navigation, Nielsen recognition-over-recall). Not Low because it's a consistent, systematic break in section context across four pages.

## U13. Destructive actions are inconsistent: some confirm, some delete immediately

**Medium** · _usability_ · `app/views/settings/sorting/show.html.erb` - 42

> **Principle:** Nielsen: Error prevention; Consistency and standards

**Finding.** Deleting a collectible or a label routes through a dedicated confirmation page, but deleting a custom sort (sorting/show line 42), removing a person's access (visibility/show line 47) and revoking a share link (visibility/show line 84) fire immediately from a `button_to` with no confirmation and no undo. Same-severity destructive actions behave differently, and the unconfirmed ones are easy to trigger by mistake.

**Fix.** Give these destructive `button_to`s a confirmation step consistent with collectibles/labels, e.g. a `data: { turbo_confirm: "Delete this custom sort?" }` (or a confirm page), and apply the same to the Remove-access and Revoke-share-link buttons.

**Verified** (confirmed, severity Medium). Verified against the actual markup and controllers. The three cited buttons all fire deletion immediately via `button_to ... method: :delete` with no confirmation: `settings/sorting/show.html.erb:42` (Delete custom sort), `settings/visibility/show.html.erb:47` (Remove access), and `settings/visibility/show.html.erb:84` (Revoke share link). A grep for `turbo_confirm`/`confirm` across all views returned zero hits, so none carry a confirm attribute. The contrast the finding draws is also accurate: collectibles and labels route deletion through dedicated confirmation pages — `app/views/collectibles/confirm_delete.html.erb` and `app/views/settings/labels/confirm_delete.html.erb`, each backed by a `confirm_delete` controller action and route (`collectibles_controller.rb:43`, `labels_controller.rb:33`, `config/routes.rb:17,32`), while the custom_sorts/profile_accesses/share_links controllers have no such action. So same-severity destructive actions genuinely behave inconsistently, violating Nielsen error prevention and consistency/standards. Severity Medium is well-calibrated: the actions are destructive and unconfirmed (custom-sort deletion in particular is not trivially recoverable), but they live on secondary settings pages, are low-frequency, and removing access / revoking a link can be re-created; not High, clearly above Low. The proposed fix (add a `turbo_confirm` or a confirm page consistent with collectibles/labels) is appropriate.

## U14. View toggle marks the active view visually but not programmatically

**Low** · _accessible-code_ · `app/views/profiles/show.html.erb` - 2-6, 31-36

> **Principle:** WCAG 1.3.1 / name-role-value status parity

**Finding.** The Cards/List view toggle applies only an .active class to the current view; like the settings subnav it never sets aria-current, so the selected view is silent to assistive tech even though the group has role="group" aria-label="View".

**Fix.** In the view_link lambda add aria: { current: ("true" if @view == view) } (aria-current="true") to the active link, matching pagination's aria-current pattern.

**Verified** (confirmed, severity Low). Confirmed at app/views/profiles/show.html.erb. The view_link lambda (lines 2-6) sets only class: ("active" if @view == view) and emits no aria-current or other programmatic state. The toggle group (lines 31-36) has role="group" aria-label="View", so the group is announced but the active link ("Cards"/"List") is distinguished only visually via CSS .active, silent to assistive tech. This is a genuine WCAG 1.3.1/4.1.2 state-parity gap. The comparison to pagination is accurate: application/_pagination.html.erb already uses aria-current="page", so the codebase has an established pattern, and the proposed fix (aria: { current: ("true" if @view == view) }) is correct and idiomatic. Downgrading from Medium to Low: both links have clear, distinct visible labels and remain fully operable; the missing announcement is a convenience/orientation indicator, not a blocker to using the control or accessing content. Real but low impact.

## U15. No enhanced focus-visible styles defined in the stylesheet

**Low** · _accessible-code_ · `app/assets/stylesheets/application.css` - 98-124, 154-194

> **Principle:** WCAG 2.4.7 Focus Visible (AA) / 2.4.11 Focus Not Obscured

**Finding.** The stylesheet defines :hover states throughout but no :focus/:focus-visible rules; buttons, links, the view toggle, tags and pagination rely solely on the browser default outline. Not a failure (the outline is never removed), but custom-filled controls like .button and .view-toggle a.active have low-contrast default outlines against the brand fill on some themes, and there is no consistent, verified focus indicator across the seven themes.

**Fix.** Add a shared :focus-visible rule (e.g. outline: 2px solid var(--text); outline-offset: 2px) covering a, .button, .button-as-link, .view-toggle a, select and inputs, verified against each theme, rather than depending on UA defaults.

**Verified** (confirmed, severity Low). Verified against app/assets/stylesheets/application.css (the only stylesheet; no other CSS or inline focus styling exists). A grep for focus/outline/:active/accent-color across the file and all views returns nothing focus-related: the sole match is an unrelated comment at line 53, plus an `autofocus` attribute and commented-out service-worker JS in views. The stylesheet defines `:hover` states pervasively (nav lines 120-124, buttons 172-178, view-toggle 313-315, tags 341, pagination 681, subnav 362) but zero `:focus`/`:focus-visible` rules, so all controls rely on the UA default outline. The cited line anchors are accurate: line 98 is the base `a` rule, 105-124 the header/nav hover block, 154-194 the button and button-as-link rules with hover-only states. The claim that this is NOT a 2.4.7 failure is correct: there is no `outline: none/0` anywhere, so keyboard focus is never suppressed. The substantive concern is genuine and minor: custom-filled controls (.button, .view-toggle a.active) place the default outline against the brand fill, and on the two-tone themes that fill is #1a1a1a / #ededed, where a UA outline can be low-contrast; focus appearance is unverified across the seven themes. The proposed shared :focus-visible fix is sound. Two corrections to the finding: (1) the 2.4.11 Focus Not Obscured citation is misapplied - that criterion concerns sticky/overlay obscuring, and the header here is not position:sticky/fixed, so it is not engaged; the relevant criteria are 2.4.7 (met) and the AAA 2.4.13 Focus Appearance. (2) Because the default outline persists and is visible on the default light/dark backgrounds, this is an enhancement/robustness gap rather than a conformance failure, so Low severity is correct and should not be raised.

## U16. Export links "CSV" / "JSON" are single-word and meaningless out of context

**Low** · _content_ · `app/views/profiles/show.html.erb` - 47-49

> **Principle:** WCAG 2.4.4 Link Purpose (In Context) (Level A) / content.md link text

**Finding.** The two export links read only "CSV" and "JSON". Screen readers can list links out of context, where "CSV" gives no hint of purpose; both are also single-word links, which content.md flags as small targets for motor-impaired users, and they link directly to the file rather than to a page describing it.

**Fix.** Make the link text carry the action and format, e.g. "Export as CSV" and "Export as JSON", or add a visually-hidden suffix so the accessible name is "Export CSV" / "Export JSON". Keep the visible "Export" label adjacent so sighted context is preserved.

**Verified** (confirmed, severity Low). Confirmed at app/views/profiles/show.html.erb:47 and :49: `link_to "CSV", ...` and `link_to "JSON", ...`. The accessible name of each link is literally "CSV" / "JSON"; the visible word "Export" on line 46 is plain text outside both anchors, so it is not part of either link's accessible name. Both links point directly at the file (format: :csv / :json), not a describing page. So the code facts in the claim are correct, and the out-of-context screen-reader concern (a links-list showing bare "CSV"/"JSON") is genuine.

One correction to the framing: the WCAG citation is slightly off. 2.4.4 Link Purpose (In Context) is Level A and explicitly allows purpose to be derived from the surrounding sentence/paragraph. Here the links sit in one paragraph reading "Export CSV · JSON", so the context is programmatically determinable and 2.4.4 (In Context) is arguably satisfied. The precise failure is 2.4.9 Link Purpose (Link Only), which is Level AAA. The finding's own content.md "single-word / small target" note is a valid but secondary point.

Given (a) it is an owner-only utility line, (b) in-context text does mitigate the Level A criterion, and (c) the true failing criterion is AAA, this is Low rather than Medium. The proposed fix ("Export as CSV"/"Export as JSON", or a visually-hidden suffix) is correct and low-cost.

## U17. Repeated "Edit" / "Delete" row links share text but point to different destinations

**Low** · _content_ · `app/views/settings/labels/index.html.erb` - 45-46

> **Principle:** WCAG 2.4.4 Link Purpose (In Context) (Level A) / content.md link text

**Finding.** Each label row exposes generic "Edit" and "Delete" links; content.md says to use different text for links going to different places, and never generic single-word text. A screen-reader user listing links hears "Edit, Delete, Edit, Delete..." with no way to tell which label each acts on. The same pattern recurs for custom sorts (settings/sorting/show.html.erb lines 41-42) and the collectible show actions ("Edit"/"Delete" at show.html.erb lines 20-21).

**Fix.** Include the item name in the accessible name, e.g. link_to "Edit", ..., aria-label: "Edit label #{label.name}" (and likewise "Delete label #{label.name}"), keeping the short visible text. Apply the same to the custom-sort and collectible-show action links.

**Verified** (confirmed, severity Low). Verified. The cited markup exists exactly as described: settings/labels/index.html.erb:45-46 renders generic "Edit"/"Delete" link_to per label row; settings/sorting/show.html.erb:41-42 does the same per custom sort (line 42 is a button_to, not link_to, but same generic-text issue); collectibles/show.html.erb:20-21 has "Edit"/"Delete". The cited content.md guidance is accurate (references/content.md:36 "Never use generic text", :40-41 "different text for links going to different places"). So the problem genuinely exists.

I lowered severity from Medium to Low for two reasons. First, on the label and sort lists the item name is in the same <li> as the links, so the link purpose is programmatically determinable in context; that makes this pass WCAG 2.4.4 Link Purpose (In Context, Level A) and only fail the stricter 2.4.9 (Level AAA), plus the skill's own best-practice rule. It is a real usability/consistency gap for a screen-reader user scanning a links list, but not the Level A break the Medium framing implies. Second, the collectibles/show.html.erb case is overstated: there is exactly one Edit and one Delete on that single-item page, so the "hears Edit, Delete, Edit, Delete with no way to tell which" duplication argument does not apply there. The label and sorting list cases are the genuine ones. The proposed fix (aria-label including the item name) is sound and appropriate.

## U18. Search-help tables lack a caption and scope on column/group headers

**Low** · _content_ · `app/views/collectibles/_search_help.html.erb` - 10-103

> **Principle:** WCAG 1.3.1 Info and Relationships (Level A) / content.md tables

**Finding.** The syntax reference table has header cells but the column <th> elements carry no scope="col", the section rows (search-help__group) use <th colspan="3"> as visual sub-headings without a scope/association, and the table has no <caption>. content.md requires proper <th> scope and a <caption>. The same gaps exist in collections/_search_help.html.erb (lines 10-76).

**Fix.** Add scope="col" to the Filter/Matches/Example header cells, add a <caption> such as "Search filters and examples", and either give the group rows scope="colgroup"/rowgroup semantics or restructure each type section as its own captioned table so the grouping is programmatic, not purely visual.

**Verified** (confirmed, severity Low). Verified against both files. In app/views/collectibles/_search_help.html.erb the table (lines 10-103) has a header row `<tr><th>Filter</th><th>Matches</th><th>Example</th></tr>` (line 12) with no scope="col", uses group rows `<tr class="search-help__group"><th colspan="3">...</th></tr>` (lines 15, 62, 79, 96) as purely visual sub-headings with no scope, and has no <caption>. app/views/collections/_search_help.html.erb (lines 10-76) has the same header row without scope (line 12) and no <caption>. content.md (references/content.md lines 94-95) explicitly requires "proper headers (<th>) with correct scope, and a <caption> describing the table." So the claim is accurate and the citation is correct. WCAG 1.3.1 is Level A, but the finding is Low: these are simple tables where column headers sit directly above their cells and are auto-associated by most screen readers, and the caption/scope omissions cause only minor orientation loss rather than blocking comprehension. One small overstatement in the claim: the collections file is a flat table with no `<th colspan>` group rows, so the group-row part of "the same gaps exist" does not apply there, though the scope and caption gaps do. Severity Low stands.

## U19. Custom-sort composer table has no caption

**Low** · _content_ · `app/views/settings/custom_sorts/_form.html.erb` - 21-45

> **Principle:** WCAG 1.3.1 Info and Relationships (Level A) / content.md tables

**Finding.** The sort-composer table correctly uses <th scope="row"> for the field column, but the column headers (Field/Rank/Direction) lack scope="col" and the table has no <caption> describing what it does, which content.md lists as required for data tables.

**Fix.** Add scope="col" to the thead cells and a <caption> such as "Rank and direction for each sort field" (visually hidden if it should not show).

**Verified** (confirmed, severity Low). Verified at app/views/settings/custom_sorts/_form.html.erb:21-45. Line 23 `<tr><th>Field</th><th>Rank</th><th>Direction</th></tr>` — the three column headers are plain `<th>` with no `scope="col"`. Line 29 `<th scope="row">` correctly scopes the row header, matching the finding. There is no `<caption>` anywhere in the table. Both parts of the claim (missing `scope="col"`, missing `<caption>`) are genuinely true, so the finding is REAL and the file:line citation is correct. Low severity is right, and arguably it is at the low end of Low: (1) each interactive control already has an explicit visually-hidden `<label>` (lines 31 and 37) giving it a full accessible name like "Type rank" / "Type direction", so a screen-reader user is not left guessing what a cell control does even without column-header association; and (2) a `<p class="muted">` on lines 17-20 explains the table's purpose in adjacent prose, partially mitigating the missing caption (though it is not programmatically associated via `<caption>`). The `scope="col"` omission is still a legitimate WCAG 1.3.1 Level A gap for a data table, so it warrants a fix, but the real-world impact is minimal. The proposed fix (add `scope="col"` to the thead cells and a visually-hidden `<caption>`) is valid and appropriate.

## U20. Hint text is not programmatically associated with its field

**Low** · _forms_ · `app/views/collectibles/_form.html.erb` - 77

> **Principle:** forms.md: attach help text via aria-describedby, not ambiguous nearby prose; WCAG 1.3.1 (A)

**Finding.** Help/hint prose sits as a sibling paragraph rather than being tied to the control with aria-describedby, so it isn't announced as part of the field. Recurs at settings/custom_sorts/_form.html.erb:14 ("Leave blank..." hint for Name), collectibles/import.html.erb:20 and :50 (hints for the CSV radio and file field), settings/sorting/show.html.erb:13 and settings/visibility/show.html.erb:15,20 (hints under legends/radios), and settings/labels/_type_checkboxes.html.erb:4.

**Fix.** Give each hint an id and reference it from the associated input/fieldset via aria-describedby (for a fieldset-wide hint, put aria-describedby on a representative control or use the legend); keep the hint visible.

**Verified** (confirmed, severity Low). The underlying pattern is real: visible `.hint` prose sits as a sibling of the control instead of being tied to it via `aria-describedby`, so it isn't announced as part of the field. This genuinely recurs at custom_sorts/_form.html.erb:14 (Name hint), import.html.erb:50 (file field hint) and :32 (Default type fieldset hint), sorting/show.html.erb:13, visibility/show.html.erb:15 and :20, and labels/_type_checkboxes.html.erb:4.

However, the primary citation is WRONG. collectibles/_form.html.erb:77 is `<p class="hint"><%= link_to "Manage labels", settings_labels_path %></p>` — an action/navigation link inside the Labels fieldset, not descriptive hint prose. There is nothing here to associate via aria-describedby; the `.hint` class is being reused for a link. Same mischaracterization applies to two of the cited recurrences: import.html.erb:20 is a "Download CSV template" link, not a hint for the CSV radio. The finding conflates action links with descriptive hints, and the actual genuine import.html.erb hint is at :32 (not the cited :20). 

Severity should be Low rather than Medium: the real hints are visible and immediately adjacent to their controls, the content is supplementary (optional-field guidance, "uncheck to hide", visibility explanations), and several of the flagged instances are links that carry no describing text at all. The WCAG 1.3.1 gap is genuine but low-impact given the adjacency and non-critical content.

## U21. OTP field lacks numeric inputmode and pattern

**Low** · _forms_ · `app/views/two_factor_authentication/sessions/show.html.erb` - 8

> **Principle:** forms.md: set inputmode/type so mobile keyboards suit the field; WCAG 1.3.5 Identify Input Purpose (AA)

**Finding.** The 6-digit one-time-code field is a plain text_field with autocomplete='one-time-code' but no inputmode='numeric', so mobile users get an alphabetic keyboard for a digits-only value. Same at two_factor_authentication/setup/show.html.erb:13.

**Fix.** Add inputmode: "numeric", pattern: "[0-9]*", and autocomplete: "one-time-code" (already present) to the otp_attempt field on both the session and setup views.

**Verified** (confirmed, severity Low). Confirmed at both cited locations. app/views/two_factor_authentication/sessions/show.html.erb:8 is `<%= f.text_field :otp_attempt, autocomplete: 'one-time-code' %>` — a plain text_field with autocomplete but no inputmode or pattern. The setup view has the identical field; the citation says setup:13 but the text_field is actually on line 14 (line 13 is the label) — a harmless off-by-one, the field is present as described. Both are 6-digit numeric OTPs (prose confirms "Enter the 6-digit code"), so mobile users get an alphabetic keyboard instead of a numeric keypad; adding inputmode: 'numeric', pattern: '[0-9]*' is the correct fix. Severity lowered from Medium to Low: this is a mobile keyboard ergonomics degradation, not a functional blocker (the field still works), and WCAG 1.3.5 Identify Input Purpose is arguably already satisfied by the existing autocomplete='one-time-code', weakening the pure WCAG-failure framing.

## U22. OTP label is an unhelpful abbreviation

**Low** · _forms_ · `app/views/two_factor_authentication/sessions/show.html.erb` - 7

> **Principle:** forms.md: labels are the question in plain language; WCAG 2.4.6 Headings and Labels (AA)

**Finding.** The visible label is just "OTP", an acronym, rather than a plain-language label matching the instruction above it ("Enter the 6-digit code..."). Same at two_factor_authentication/setup/show.html.erb:12.

**Fix.** Label the field "6-digit code" (or "Authentication code") to match the on-screen instruction and avoid the unexpanded acronym.

**Verified** (confirmed, severity Low). Confirmed at both cited locations. app/views/two_factor_authentication/sessions/show.html.erb:7 and app/views/two_factor_authentication/setup/show.html.erb:13 both render `<%= f.label :otp_attempt, "OTP" %>`. The visible label is the bare acronym "OTP", sitting directly beneath a plain-language instruction ("Enter the 6-digit code from your authenticator app:" / "Then enter the 6-digit code to verify and enable 2FA:"). The claim is accurate: the label is not the question in plain language, and "OTP" is unexpanded, which is unhelpful for users who do not know the acronym. This engages WCAG 2.4.6 Headings and Labels (AA), which asks that labels be descriptive. Low severity is appropriate: the field is still programmatically labelled (name/for association is intact, so screen readers announce a label and it is operable), the input carries autocomplete='one-time-code', and the surrounding instruction text supplies context; the issue is clarity/quality of the visible label rather than a blocker. Proposed fix (e.g. "6-digit code" or "Authentication code") is reasonable and should be applied to both files.

## U23. Player range fields don't cross-validate or explain the relationship

**Low** · _forms_ · `app/views/collectibles/_form.html.erb` - 31-41

> **Principle:** forms.md: prevent errors first with clear formats; Nielsen error prevention

**Finding.** Minimum and Maximum players are two number fields in a Players fieldset with no hint about the min<=max relationship and no client-side guard; a user can enter max below min and only discover it via a generic summary error. The import equivalent (_import_fields.html.erb:24-32) has the same gap.

**Fix.** Add a fieldset hint (associated via aria-describedby) stating the expected relationship, and where possible constrain the max field's min to the entered minimum; ensure any resulting error is field-associated per the summary/aria-invalid fixes above.

**Verified** (confirmed, severity Low). Verified against the cited markup. app/views/collectibles/_form.html.erb:31-41 is a Players fieldset (legend "Players") with two number_field inputs, min_players ("Minimum") and max_players ("Maximum"), each constrained only with `min: 1`. There is no hint text, no aria-describedby explaining the min<=max relationship, and no client-side constraint tying max's minimum to the entered minimum. The import equivalent at app/views/collectibles/_import_fields.html.erb:24-32 has the identical gap (number_field_tag min_players/max_players with `min: 1` only). One nuance: the finding says a bad value is "only discover[ed] via a generic summary error", but there is in fact NO validation at all. app/models/board_game.rb has no validation of min<=max, so entering max below min is silently persisted rather than surfacing a summary error. The described UX gap (prevent-errors-first: no hint, no client guard) is therefore real and if anything slightly understated. Low severity is correct: it affects only the board-game subtype, the underlying value feeds only a display string (player_count, lines 10-17, which renders correctly regardless of ordering), and there is no security or data-integrity impact. Location and claim confirmed.

## U24. Unconfirmed destructive controls styled as plain text links, not as danger actions

**Low** · _usability_ · `app/views/settings/visibility/show.html.erb` - 47, 84

> **Principle:** Norman: signifiers; Krug: make important/dangerous actions look their weight

**Finding.** Remove-access, Revoke and Delete-custom-sort use `.button-as-link`, rendering an irreversible action as an ordinary inline link. Confirmed deletes elsewhere use `.button--danger`. The visual weight does not signal that these are destructive, so a user scanning the row can trigger them as casually as a navigation link.

**Fix.** Either route them through confirmation (see above) or give them a danger signifier consistent with the rest of the app; at minimum they should read as destructive rather than as a neutral link.

**Verified** (confirmed, severity Low). Verified at app/views/settings/visibility/show.html.erb:47 ("Remove") and :84 ("Revoke"): both are button_to with method: :delete and class: "button-as-link", with no confirmation flow (no turbo_confirm data attribute, no confirm_delete page). Per application.css:184-192, .button-as-link renders as an underlined brand-colored inline text link with no border/background, visually indistinguishable from a navigation link. The app has an established danger convention (.button--danger, application.css:177) used for confirmed destructive actions in collectibles/confirm_delete.html.erb:11, collectibles/show.html.erb:21, and settings/labels/confirm_delete.html.erb:30, so these destructive controls genuinely deviate from the app's own signifier for its weight (Norman signifiers; Krug making dangerous actions look their weight). One citation imprecision: the finding also names "Delete-custom-sort" as if in this file, but that control is actually in app/views/settings/sorting/show.html.erb:42 (same button-as-link pattern) - so the pattern claim holds but the location for that third instance is wrong. Severity Low is appropriate: the actions are irreversible but low-blast-radius (revoking access or deleting a share link is easily re-done, no cascading data loss). It sits near the Low/Medium boundary given the inconsistency with the app's own danger styling, but Low as cited is defensible.

## U25. External 'look it up' links open in a new tab with no cue

**Low** · _usability_ · `app/views/collectibles/show.html.erb` - 52-54

> **Principle:** Nielsen: Visibility of system status; Match between system and real world

**Finding.** Search links (also in _collectible.html.erb lines 31-34) use target="_blank" but give no visible or textual signifier that they leave the app in a new window, so the new tab is an unexpected result. Krug's convention is to warn before opening a new window.

**Fix.** Add an 'opens in a new tab' signifier - a visually-hidden span for assistive tech plus a small visible icon or note - on the `.tag--link` links in show.html.erb and _collectible.html.erb.

**Verified** (confirmed, severity Low). Verified at both cited locations. show.html.erb:53 (within the 52-54 range) and _collectible.html.erb:32 (within the cited 31-34 range) both render `link_to ..., target: "_blank", rel: "noopener"`. There is no visible icon, textual note, or visually-hidden span cueing that these links open a new tab. The `.tag--link` CSS (application.css:336-341) provides only border/background/hover styles with no `::after` icon content. So the new tab is an unannounced context change, which is exactly the described problem.

Severity Low is correct. Warning before opening a new window maps to WCAG 3.2.5 Change on Request, which is AAA (not A/AA), and this affects only the secondary 'Look it up' search links rather than core navigation. `rel="noopener"` is already set, so the security dimension is handled. Genuine but minor. Note: strictly these are search-provider URLs (effectively external) rather than same-app links, but that does not change the finding's validity.

## U26. Two-factor pages have no exit / cancel path

**Low** · _usability_ · `app/views/two_factor_authentication/setup/show.html.erb` - 11-20

> **Principle:** Nielsen: User control and freedom (clear exits)

**Finding.** The 2FA setup and verify screens (sessions/show.html.erb too) offer only the submit button; there is no visible way to cancel or go back if the user cannot complete the step, trapping them in the flow. Every other form in the app pairs its submit with a Cancel/Back link.

**Fix.** Add a Cancel/Back link next to the submit on both two_factor_authentication views, consistent with the `.actions` Cancel pattern used elsewhere.

**Verified** (confirmed, severity Low). Citation is accurate: app/views/two_factor_authentication/setup/show.html.erb:11-20 and sessions/show.html.erb both render only a submit button (Enable 2FA / Verify) with no Cancel/Back link, so the core observation (no visible exit path) genuinely exists. However, the finding's supporting justification is overstated and partly false: it claims "Every other form in the app pairs its submit with a Cancel/Back link," but multiple other forms also omit Cancel, e.g. settings/show.html.erb:49-51 (Save settings only) and settings/visibility/show.html.erb:22-24 (Save only), plus the search/sorting forms. The .actions Cancel pattern exists only on certain edit/create forms (collectibles/_form.html.erb:87, settings/labels/edit.html.erb:20, custom_sorts/_form.html.erb), not universally. Impact is also mild in context: the setup screen is reached from settings and site chrome/nav provides an exit; the verify (sessions) screen is a mid-login gate where lacking an in-form exit is largely expected. Low severity is appropriate (a consistency/affordance nicety, mainly on the setup screen), not the near-trap the wording implies.

## U27. Field label 'OTP' uses jargon instead of plain language

**Low** · _usability_ · `app/views/two_factor_authentication/setup/show.html.erb` - 14

> **Principle:** Nielsen: Match between system and the real world

**Finding.** The visible field label is the abbreviation 'OTP' (also sessions/show.html.erb line 8), while the surrounding prose correctly says '6-digit code from your authenticator app'. 'OTP' is internal jargon many users will not recognise, and it contradicts the prompt text right above it.

**Fix.** Label the field in the user's words, e.g. 'Authentication code' or '6-digit code', matching the instruction sentence above.

**Verified** (confirmed, severity Low). Verified. The label "OTP" appears in both 2FA views: two_factor_authentication/setup/show.html.erb:13 and two_factor_authentication/sessions/show.html.erb:7 (via `<%= f.label :otp_attempt, "OTP" %>`). In both, the prose directly above uses plain language ("6-digit code to verify and enable 2FA" at setup line 9; "6-digit code from your authenticator app" at sessions line 3), so the jargon label does contradict the surrounding copy. The heuristic (Nielsen: match between system and the real world) is apt and the proposed fix ("Authentication code" / "6-digit code") is sound. Minor citation inaccuracies: the finding lists the label at setup line 14 (it is line 13; 14 is the text_field) and cites the second file as "sessions/show.html.erb line 8" when the actual path is two_factor_authentication/sessions/show.html.erb and the label is line 7. These are off-by-one/path imprecisions, not errors of substance. Severity Low is correct: with autocomplete="one-time-code" and the clear instructional prose above each field, users can still complete the task; this is a consistency/plain-language polish issue rather than a functional blocker.

## U28. Two-factor forms lack the .stack wrapper and the app's field layout

**Low** · _usability_ · `app/views/two_factor_authentication/sessions/show.html.erb` - 5-14

> **Principle:** Krug: Consistency and standards; visual hierarchy

**Finding.** Both 2FA views wrap fields in bare `<div>`s rather than the `.stack` / `.field` / `.actions` structure every other form uses, so they render without the consistent label spacing, max-width and action styling. The result looks unlike the rest of the app and reads as an unfinished screen.

**Fix.** Adopt the same `class: "stack"` form and `.field` / `.actions` wrappers used by the collectible, label and settings forms.

**Verified** (confirmed, severity Low). Confirmed at app/views/two_factor_authentication/sessions/show.html.erb:5-14 (and the same pattern at setup/show.html.erb:11-19). Both 2FA forms use `form_with` with no `class: "stack"` and wrap fields in bare `<div>`s, whereas the collectible form (_form.html.erb), label form (labels/edit.html.erb:5), and settings views use `class: "stack"` on the form plus `.field` and `.actions` wrappers. The referenced CSS (application.css:197-239) confirms each lost effect: `.stack` sets max-width:560px, `.field` gives 1rem bottom margin with bold, spaced labels, and `.actions` provides a flex layout with gap. So the 2FA forms genuinely render without the app's consistent field layout, label spacing, max-width, and action styling — the claim is accurate in location and substance. Severity Low is appropriate: the forms remain functional and accessible (labels associated, inputs present, submit keeps `.button`); the defect is purely cosmetic consistency (full-width stretch, weaker label styling, un-gapped actions) on two low-traffic auth screens, so it does not rise to Medium.

## U29. PWA install identity uses placeholder colours and description

**Low** · _usability_ · `app/views/pwa/manifest.json.erb` - 19-21

> **Principle:** Nielsen: Consistency and standards; Krug: follow conventions

**Finding.** theme_color and background_color are the literal string "red" and the description is the placeholder "Collection.", so the installed-app splash and OS chrome do not match the app's actual brand palette (the CSS `--brand` is a blue) and the store/description text is a stub. The install experience is inconsistent with the running app.

**Fix.** Set theme_color/background_color to real hex values matching the app's brand/background tokens and give description a real one-line summary (mirror the homepage tagline).

**Verified** (confirmed, severity Low). Verified at app/views/pwa/manifest.json.erb:19-21. The markup literally reads "description": "Collection.", "theme_color": "red", and "background_color": "red". The app's actual default brand token is --brand: #3a52c6 (a blue) in app/assets/stylesheets/application.css:42, so "red" matches no theme in the palette, and the description is a bare placeholder. The claim is accurate: the PWA install identity (splash/OS chrome color and store description) is inconsistent with the running app. Severity Low is correct — this is install-time cosmetic polish, not a functional or accessibility defect. Minor caveat, not affecting validity: the app ships several color themes (dark/mono/sepia/green/terracotta), so a single static manifest can only mirror one; "red" mirrors none, and the proposed fix (real hex + a one-line summary) is sound.

## U30. Pagination and inline list-row action targets are small and closely spaced

**Low** · _visual-design_ · `app/assets/stylesheets/application.css` - 666-685, 356-357

> **Principle:** WCAG 2.5.8 Target Size (Minimum) (AA)

**Finding.** Pagination links use padding 0.35rem 0.65rem on ~14-16px digits, and list-row action clusters (.list__actions Edit/Delete, .button-as-link Delete/Revoke/Remove which render as unpadded inline text at font size) sit 0.75rem apart. The inline-link exception in 2.5.8 covers text in a sentence, but these are standalone controls in tight rows and can fall under the 24x24 CSS px minimum, particularly the pagination page numbers and the zero-padding .button-as-link controls.

**Fix.** Ensure standalone controls meet ~24x24px: increase pagination link padding (e.g. min-height/inline-block with more vertical padding) and give .button-as-link and .list__actions links a little padding or increased line spacing so their hit area and the gap between adjacent targets reach 24px.

**Verified** (confirmed, severity Low). Citations are accurate. app/assets/stylesheets/application.css:357 defines `.list__actions { display: flex; gap: 0.75rem; align-items: center; }` and lines 674-680 give `.pagination a, .pagination__current { padding: 0.35rem 0.65rem; ... }`. `.button-as-link` (line 184-192) has `padding: 0; font: inherit;`, and plain `link_to` action links get no padding rule at all. The markup confirms these are standalone controls in tight rows: settings/labels/index.html.erb:44-46 renders Edit and Delete as adjacent `link_to` links inside `.list__actions`. At --fs-base (16px), these zero-padding text links have a hit target roughly 16-19px tall, under the 24x24 CSS px WCAG 2.5.8 (AA) minimum, and adjacent targets sit only 0.75rem (12px) apart, so the target-spacing exception (a 24px circle must not overlap a neighbour) is also at risk. The inline-link "text in a sentence" exception does not cleanly cover these standalone row actions. One caveat: the pagination part of the claim is overstated - padded links compute to ~27px tall and ~31px wide for single digits, so they roughly meet the minimum; the real exposure is the zero-padding action links, which the finding itself flags as the primary concern. Because 2.5.8 is AA and the shortfall is a borderline height/spacing issue rather than grossly undersized controls, Low severity is correct.

## U31. PWA manifest theme_color/background_color set to a named 'red'

**Low** · _visual-design_ · `app/views/pwa/manifest.json.erb` - 20-21

> **Principle:** visual-design (colour value / brand consistency)

**Finding.** theme_color and background_color are both the literal string "red", which does not match any of the app's theme palettes and would give an off-brand, high-saturation splash/toolbar colour in installed-PWA contexts. It also ignores the user's chosen theme entirely.

**Fix.** Set theme_color/background_color to a real brand value (e.g. the light theme --bg #f6f7fb with brand #3a52c6, or render per the user's theme). Avoid the CSS keyword 'red'.

**Verified** (confirmed, severity Low). Verified at app/views/pwa/manifest.json.erb:20-21: both "theme_color" and "background_color" are the literal string "red", the unmodified Rails PWA scaffold default. This matches none of the app's real palette tokens in app/assets/stylesheets/application.css (light --bg #f6f7fb / --brand #3a52c6, dark --brand #93a7f2, etc.), so it does give an off-brand toolbar/splash colour in installed-PWA contexts. The finding's proposed fix values are the actual brand tokens present in the codebase. Severity Low is correct: it is a cosmetic default affecting only PWA install chrome, not functionality, content, or contrast/accessibility of any layered text. Minor caveat: the "ignores the user's chosen theme" point is true but weak, since a static, theme-agnostic manifest is normal and expected; the core off-brand-"red" claim stands.