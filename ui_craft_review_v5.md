# UI-craft review (whole interface, `prototype` branch)

A whole-interface review through the ui-craft lens: usability (Krug, Nielsen, Norman) and accessibility (WCAG 2.2 AA, GOV.UK Design System, dxw manual). Swept per WCAG criterion and per heuristic across the whole surface, walking twice (first-time mouse user; assistive-tech user).

## Scope and coverage

Reviewed in full: the **layout** (`layouts/application.html.erb`), the entire **stylesheet** (`application.css`, all 7 themes), and **all ~40 view templates** — collectibles (`_collectible`, `_form`, `_import_fields`, `_import_help`, `_search_form`, `_search_help`, `confirm_delete`, `edit`, `import`, `new`, `review`, `show`), collections (index + search form/help), profiles (`show`, `_profile_row`, `_follow_button`, `private_profile`), root (`index`, `_collection_list`), settings (`show`, `_nav`, visibility, sorting, labels/*, custom_sorts/*), the shared `_pagination`, and 2FA views. Helpers emitting markup (`label_tag_span`, `collection_tags`) checked.

Not covered: Devise's own auth screens (not in the repo — see gaps); I could not run an automated contrast checker or a real screen reader, so contrast findings are reasoned/flagged-to-verify, not tool-confirmed.

## What already works well

- `lang="en"` on `<html>`; a unique `<title>` per page via `content_for`; one `<main>` per page.
- **Pagination is the accessibility exemplar:** `<nav aria-label="Pagination">` with `aria-current="page"` on the current page (`_pagination.html.erb:3-8`). This is the reference instance — the sibling checks below flow from it.
- Type scale is tokenised in `rem` (honours zoom); the search help uses a real `<details>` progressive disclosure (Hick's law); empty states are specific and helpful; `simple_format` on notes is safe.
- The view toggle uses `role="group" aria-label="View"` (`profiles/show.html.erb:32`) and the breadcrumb hides its decorative `/` with `aria-hidden="true"` — both thoughtful.
- No `outline: none` anywhere and no motion, so the UA focus ring is intact and there's no reduced-motion obligation.

## Findings by theme

### Theme 1 — State shown visually but not exposed to assistive tech (the strongest theme)

Pagination sets `aria-current` correctly; **no other active/current control does**:

- **Medium** — settings subnav active tab gets `class="active"` (bold) but no `aria-current="page"` (`settings/_nav.html.erb:2-5`).
- **Medium** — the Cards/List view toggle marks the active link with `class="active"` only; no `aria-current` (`profiles/show.html.erb:2-6, 33-34`).
- **Medium** — the top nav gives no indication of the current page (`layouts/application.html.erb:26-37`) — Nielsen "visibility of system status" / "where am I".

Fix: add `aria-current="page"` to each active nav/toggle link. One theme, four sites.

### Theme 2 — Landmarks and bypass

- **Medium/High** — **no skip link.** The header repeats nav on every page but there's no skip-to-main-content link, and `<main class="site-main">` has no `id` (`layouts/application.html.erb:41`). WCAG 2.4.1 Bypass Blocks (A). Add a skip link + `id="main-content"` (and `tabindex="-1"`) — fixes every page at once.
- **Medium** — **multiple `<nav>` landmarks aren't distinctly labelled.** `site-nav`, the settings `subnav`, and the breadcrumb `<nav>` have no `aria-label`, so a screen reader announces several ambiguous "navigation" regions (pagination is the only labelled one). Add `aria-label="Primary"` / `"Settings"` / `"Breadcrumb"`.

### Theme 3 — Heading hierarchy skips via a shared partial

- **Medium** — the card partial hardcodes `<h3 class="card__title">` (`_collectible.html.erb:6`). On the homepage it sits correctly under an `<h2>` ("From your collection"), but on the collection and all-collections pages it follows the page `<h1>` with **no `<h2>` between** — a skipped level (WCAG 1.3.1). This is the classic "shared partial, hardcoded heading, correct on one page, wrong on another". Make the card's title level a local, or add a section `<h2>` on the collection pages.

### Theme 4 — Links distinguished by colour alone (WCAG 1.4.1)

- **High (monochrome themes) / Medium (others)** — body text links get colour only: `a { color: var(--brand) }` with underline **only on hover** (`application.css:98`). Inline links inside prose — the export "CSV · JSON" (`profiles/show.html.erb:47-49`), "Manage labels" hint (`_form.html.erb:77`), profile links in list rows, share URLs — rely on colour with no persistent non-colour cue. In `monochrome_light`/`monochrome_dark`, `--brand` is set *equal to* `--text` (`application.css:477, 517`), so those links are **completely indistinguishable** from surrounding text until hover — a definite 1.4.1 failure. Fix: underline in-content links (keep nav/button regions as they are).

### Theme 5 — Forms: error recovery and field association

- **Medium (systemic)** — **no error summary pattern.** Every form renders `errors.full_messages` as plain text in an `.errors`/`.errors`-list block (`_form.html.erb:9-18`, labels/custom-sort/settings forms), with **no links to the offending fields and no focus moved to the summary** on failed submit, and **no per-field `aria-invalid`/`aria-describedby`**. This is the GOV.UK error-summary pattern (and WCAG error-identification best practice). Keyboard/SR users aren't taken to the errors. Add a linked summary + focus management + field-level association.
- **Low/Medium** — **required fields not marked.** Title is the only required field but carries no `required` attribute or marker; most others are optional and unmarked (`_form.html.erb:20-23`). Adopt the GOV.UK "(optional)" convention or add `required`.
- **Low** — repeated identical link/button text in lists ("Edit"/"Delete" per label; "Remove"/"Revoke" per access/share-link; "Edit"/"Delete" per custom sort) with no per-row context — the exact "several Edit buttons in a table" case from `accessible-code.md`. Add visually-hidden context: `Edit <label name>` (WCAG 2.4.4). Systemic across labels, custom sorts, visibility.
- **Low** — 2FA field has `autocomplete="one-time-code"` (good) but no `inputmode="numeric"`, and "OTP" is jargon — prefer "Authentication code" (`two_factor_authentication/*/show.html.erb`). Settings username/display-name fields lack `autocomplete="username"`/`"nickname"`.

### Theme 6 — Destructive actions: inconsistent confirmation and weak signifiers (Nielsen 5, Krug)

- **Medium** — collectible and label deletes go through a `confirm_delete` page (good), but **custom-sort "Delete" fires immediately** with no confirmation (`settings/sorting/show.html.erb:42`), and **share-link "Revoke"** and profile-access "Remove" also fire immediately (`visibility/show.html.erb:47, 84`). Inconsistent (Nielsen 4) and no error prevention (Nielsen 5) — revoking a link is irreversible (the token can't be recovered). At minimum add a `data-turbo-confirm`; ideally match the confirm-page pattern for the destructive ones.
- **Medium** — these destructive controls are styled as `.button-as-link` (plain underlined text, `padding: 0`, `application.css:184-192`): a **weak signifier** (Krug/Norman — destructive actions don't look like buttons) and a **small tap target** (WCAG 2.5.8, 24×24). Give them button affordance and adequate size, or at least the danger colour.

### Theme 7 — Colour contrast (flagged to verify — no tool run)

The stylesheet asserts "all pairs WCAG-AA verified", and the light/dark spot-checks I could reason through (`--muted #585f6d` on white ≈ 5.8:1; `--brand #3a52c6` on white ≈ 6.6:1; label chips) look fine. But contrast is *asserted, not tested in CI*, and the higher-risk combinations I couldn't confirm by eye are the small (`--fs-sm`) `--muted` text across the pastel themes (`pastel_parlour` muted `#5f4a54` on pink `#f7cede`, tag text on tinted chips). **Recommendation:** add an automated contrast check across all 7 themes rather than relying on the comment. I'm flagging this as *verify*, not asserting a failure.

### Theme 8 — Focus visibility (enhancement)

- **Low/Medium** — there's no explicit `:focus-visible` style; the app relies on the UA default outline (acceptable per the reference since it's never removed). But `.button`, `.view-toggle a.active` and `.tag--link` have custom themed backgrounds, and the default ring isn't guaranteed 3:1 against all 7 theme surfaces. Add one tokenised `:focus-visible` outline so focus is consistent and contrast-safe everywhere.

### Smaller notes

- **Low** — external search links open in a new tab (`target="_blank" rel="noopener"`, `_collectible.html.erb:32`, `show.html.erb:53`) with no warning to SR users; add visually-hidden "(opens in new tab)". `rel="noopener"` is correctly set.
- **Low** — the "★ Following" tag (`application_helper.rb:45`) reads the star as "black star" in some SRs; wrap the ★ in `aria-hidden`.
- **Low** — help/sort-composer tables lack `scope="col"` on column headers and a `<caption>` (`_search_help.html.erb`, custom_sorts `_form.html.erb`). The composer's `scope="row"` on field names is already correct — credit.
- **Low** — flash messages are `<p class="flash">` with no `role="status"`/`role="alert"` (`layouts/application.html.erb:42-43`). Acceptable on full page loads (read in document order), but the roles improve it.
- **Low** — `autofocus` on the title field (`_form.html.erb:22`) can disorient SR users by skipping context.

## Subject/hotspot pivot

`layouts/application.html.erb` is the highest-leverage file — it carries findings from four different criteria (skip link, nav labelling, nav `aria-current`, flash roles). Fixing it once clears them across every page. The `_collectible` partial is the second (heading level + new-tab links) and recurs wherever it renders.

## Impact-ordered fix list (not severity order)

1. **Fix the layout** — skip link + `id="main-content"`, `aria-label` on each `<nav>`, `aria-current` on the active nav item, `role` on flash. *One file, clears ~5 findings across every page.*
2. **Underline in-content links** (and stop `--brand == --text` in monochrome themes). *A few CSS lines; resolves the 1.4.1 failures including the monochrome one.*
3. **Add `aria-current` to the view toggle and settings subnav.** *Two partials; completes Theme 1.*
4. **Make the card heading level contextual** (or add section `<h2>`s). *Clears the heading skip on two pages.*
5. **Add an error-summary + field association** to the shared form patterns. *Systemic; every form benefits.*
6. **Standardise destructive actions** — confirmation + button affordance + target size. *Systemic across settings.*
7. **Add contrast tests + a `:focus-visible` token.** *Guards the visual layer across all 7 themes.*

## Coverage gaps / caveats

- Devise's auth screens (sign in/up, password reset) aren't in the repo and weren't reviewed; the app's own field styling applies to them via the `:not([class])` selector, but their markup/labels are unaudited.
- No automated contrast tool or real screen reader was run — Theme 7 and the name/role/value findings are reasoned from the markup and CSS, and Theme 7 in particular should be verified with a checker before treating any theme as pass/fail.
