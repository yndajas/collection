# UI-craft review (v7)

**Lens:** UI craft — usability (Krug, Nielsen, Norman) and accessibility (WCAG 2.2 AA, GOV.UK, dxw).
**Scope:** every view, partial, and layout under `app/views/`, the single stylesheet `app/assets/stylesheets/application.css`, and the helpers/controllers that assemble user-facing text and accessible names (scoped by lens, not file type).
**Excluded:** automated tests; Devise's own default views (sign-in/up/reset are not overridden in this repo — only their submit styling is themed).
**Depth:** exhaustive (the low-severity tail is reported).
**Execution:** inline single pass, walked twice — once as a first-time sighted mouse user, once as a keyboard/screen-reader user — with the craft-reviewing rigour apparatus.

The visual and content craft here is high: a single tokenised type scale, seven fully re-skinned themes whose text and interactive-control contrast I verified against AA (see credits), consistent empty states, plain-language microcopy, real `<label>`s on every input (visually hidden where the design omits a visible one), and a correctly-implemented paginator with `aria-current="page"`. The findings cluster into a few systematic accessibility gaps rather than scattered nits.

---

## Themes (the across-screens, same-problem view)

1. **Links aren't distinguishable without colour** — a global `a { color: var(--brand) }` with no underline (only on `:hover`) means inline prose links fail WCAG 1.4.1 in *every* theme, and are literally invisible in the two monochrome themes. The single highest-impact finding.
2. **State shown but not announced** — the paginator announces the current page with `aria-current`; its sibling "current item" controls (view toggle, settings sub-nav) show state with a class/colour only.
3. **Landmark and bypass gaps** — a repeated header nav with no skip link and no targetable `<main>`, and several `<nav>` landmarks with no distinguishing label.
4. **Heading structure breaks in the card grid** — the collection page jumps `<h1>` → `<h3>` because the card partial hardcodes `h3` with no intervening `h2`.
5. **Form error handling sits below the accessible baseline** — errors are listed but not linked to fields, not programmatically associated, and focus is never moved; required fields are unmarked.

---

## Findings

### High

**H1. Inline links are distinguished by colour alone; invisible in monochrome themes (WCAG 1.4.1 Use of Colour, Level A; Krug: make clickable things obviously clickable).**
`application.css:98` sets `a { color: var(--brand); }` with **no** `text-decoration`; the underline appears only on `:hover` (and via the browser default focus ring). For a link inside running text that is the *only* non-positional cue that it's a link, so it must contrast ≥ 3:1 against the surrounding body text. It does not, in any theme — measured link-vs-text ratios:

| Theme | link-vs-text | Theme | link-vs-text |
|---|---|---|---|
| light | 2.42 | pastel_woodland | 1.77 |
| dark | 1.91 | pastel_parlour | 1.88 |
| retro | 2.60 | monochrome_light | **1.00** |
| | | monochrome_dark | **1.00** |

In the two monochrome themes `--brand` equals `--text`, so an inline link is pixel-identical to the text around it until hovered. Affected inline links include the collectible show "← Back…" (`collectibles/show.html.erb:60`) and breadcrumb (`:4`), the "Manage labels" / "Add custom sort" hints (`_form.html.erb:77`, several settings screens), the visibility page's "Your public profile" link (`settings/visibility/show.html.erb:29`), and the CSV-template download (`import.html.erb:21`). Fix: underline links in body content by default (keep nav and `.button`/`.tag--link` as-is — they carry their own non-colour affordance from position and shape). Severity High: it's a Level-A failure asserted globally, and total link loss in two shipped themes.

### Medium

**M2. No skip link and no targetable main landmark (WCAG 2.4.1 Bypass Blocks, Level A).**
`application.html.erb:22` repeats the full site header/nav on every page, but there is no skip-to-content link and `<main class="site-main">` (`:41`) has no `id`. A keyboard or screen-reader user must tab through every nav item on every page to reach the content. Add a visually-hidden-until-focused "Skip to main content" link as the first focusable element and give `<main id="main">` a target. `accessible-code.md` calls this out specifically for a repeated header.

**M3. `aria-current` parity: current-item state shown but not announced (WCAG 4.1.2 Name/Role/Value; Nielsen 1 Visibility of status).**
The paginator does this right — `application/_pagination.html.erb:8` marks the current page `aria-current="page"`. Its siblings don't:
- **View toggle** (`profiles/show.html.erb:31`): the active Cards/List option is styled with `.active` (brand fill) but carries no `aria-current`; a screen-reader user hears "Cards, link / List, link" with no indication which is applied. It's wrapped in `role="group" aria-label="View"`, so add `aria-current="true"` (or visually-hidden "current" text) to the active link.
- **Settings sub-nav** (`settings/_nav.html.erb:2–5`): the active section uses `.active` (colour + weight) only; add `aria-current="page"`.

This is the classic "one component gets the a11y detail right, its siblings don't" parity gap. Grouped as Medium because state is conveyed, just not to assistive tech.

**M4. Card grid skips a heading level (WCAG 1.3.1 Info and Relationships; 2.4.6 Headings).**
`collectibles/_collectible.html.erb:6` renders the title as `<h3>`. On the collection page (`profiles/show.html.erb`) the cards sit directly under the page `<h1>` with no `<h2>` between, so the outline runs h1 → h3. (On the homepage the same partial is fine because an `<h2>` precedes it — which is exactly why a hardcoded level in a shared partial is fragile.) Either demote the card title to `h2` on the collection page, or wrap the grid in a section with a real (possibly visually-hidden) `<h2>` heading so levels don't skip. Severity Medium: screen-reader users navigate by heading level and a skipped level misreports structure.

**M5. Form errors are listed but not wired for accessible recovery (WCAG 3.3.1 / 3.3.3; `forms.md`; Nielsen 9).**
The collectible form (`collectibles/_form.html.erb:9`) and the settings/label forms render errors as a plain `<div class="errors">` list or sentence at the top of the form. Compared with the accessible pattern they are missing: (a) an **error summary whose entries link to the offending fields**, (b) **focus moved to the summary** on failed submit, (c) per-field association (`aria-invalid` + `aria-describedby` pointing at the message), and (d) preserved position near each field. Inputs also aren't marked **required** (title is validated `presence` but has no `required`/`aria-required` or "(optional)" convention, `_form.html.erb:21`). For a prototype the current listing is serviceable, but it's the biggest accessibility gap in the interactive flows. The GOV.UK error-summary component implements exactly this if you want a drop-in.

### Low

**L6. `<nav>` landmarks lack distinguishing labels (WCAG 1.3.1; `accessible-code.md`).**
Multiple navigation landmarks are unlabelled, so a screen reader's landmark list reads "navigation" several times: `site-nav` (`application.html.erb:26`), the settings `subnav` (`settings/_nav.html.erb:1`), and the breadcrumb (`collectibles/show.html.erb:4`). Only the paginator is labelled. Add `aria-label` to each (e.g. "Primary", "Settings", "Breadcrumb"). Low because context usually disambiguates, but cheap to fix and it's a set-consistency issue.

**L7. "OTP" is jargon as a field label (WCAG 3.3.2 Labels; `content.md`: plain language).**
`two_factor_authentication/sessions/show.html.erb:8` and `setup/show.html.erb:13` label the input `"OTP"`, though the surrounding prose says "6-digit code". Relabel to "6-digit code" (or "Authentication code") to match the user's language. While there, add `inputmode="numeric"` (and `autocomplete="one-time-code"` is already present — good) so mobile keyboards show digits.

**L8. Flash messages aren't in a live region (Nielsen 1; `accessible-code.md`).**
`application.html.erb:42–43` renders notice/alert as plain `<p class="flash">`. Because the app uses full page loads, a screen reader re-reads the page on navigation and will reach these in source order, so this is minor today — but marking the alert flash `role="alert"` (and notice `role="status"`) makes success/error announcements reliable and future-proofs it against any Turbo-stream update. Low.

**L9. Decorative glyphs read aloud (`content.md`).**
The "★ Following" tag (`application_helper.rb:44`) renders a literal star a screen reader announces as "black star"; the middot separators in `_profile_row.html.erb:13` and `collectible_counts` are read as punctuation. Wrap the star in `aria-hidden` (or use a text-only "Following"), and the separators are harmless but could be `aria-hidden` too. Low.

**L10. Search-help table has no caption and uses `th` rows as section headers (WCAG 1.3.1; `content.md`).**
`collectibles/_search_help.html.erb:10` and `collections/_search_help.html.erb:10` give a good `<thead>`/`<th>` structure but no `<caption>`, and the group rows (`<tr class="search-help__group"><th colspan="3">`) act as visual section dividers inside `<tbody>` — a screen reader announces them as header cells with no clear association. Add a `<caption>` and consider splitting into captioned sub-tables or using row-group semantics. The data itself is genuinely tabular, so the table is the right element. Low.

**L11. External search links open in a new tab without warning (WCAG 3.2.5 advisory; Nielsen 4).**
`_collectible.html.erb:31` / `collectibles/show.html.erb:53` render the look-up links with `target="_blank"` (and `rel="noopener"` — good). A new tab opening unannounced can disorient screen-reader and cognitive users. Optional: add visually-hidden "(opens in a new tab)" text or drop `target` and let users choose. Low / advisory.

**L12. Focus is left to the browser default.**
No `:focus`/`:focus-visible` rule exists in the stylesheet — and, correctly, nothing sets `outline: none`, so the browser's default focus ring is preserved everywhere (this is the acceptable fallback per `accessible-code.md`, hence a credit not a defect). Noted only as an opportunity: a single explicit `:focus-visible` style would give the segmented control and brand-filled active states a consistent, higher-contrast ring. Low / enhancement.

---

## Subject pivot (the within-file, many-problems view)

| Subject | Dimensions it collects | Read |
|---|---|---|
| **`application.html.erb` (layout)** | Bypass/skip link (M2) · unlabelled nav (L6) · flash live region (L8) | The frame every page inherits — three separate criteria converge on the shared shell, so one file's fixes lift the whole app. Highest-leverage single file. |
| **`application.css` (global `a`)** | Use of colour 1.4.1 (H1) · focus default (L12) | One global rule is the app's biggest a11y failure; a one-line default underline resolves it across all seven themes at once. |
| **`_collectible.html.erb` (card partial)** | Heading skip (M4) · new-tab links (L11) · (code-side: labels N+1, see code report) | A shared partial correct in one context (homepage) and wrong in another (collection page) — the hardcoded `h3` is the fragility. |
| **Collectible / settings forms** | Error summary + association + focus (M5) · required marking (M5) | The interactive recovery path is where the accessibility gap is widest and most worth closing. |
| **Current-item controls** (`_pagination`, view toggle, `settings/_nav`) | `aria-current` parity (M3) | One pattern implemented once correctly and twice not. |

The layout and the global stylesheet are the two hotspots: between them they carry H1, M2, L6, L8, and L12, so a small number of edits to shared infrastructure clears most of the list.

---

## Leverage-ordered fix list (by findings dissolved, not by cost)

1. **Underline body/content links by default** (H1). Cost: S (one CSS rule, scoped to prose links). Fixes a Level-A failure across all seven themes and restores links in monochrome — the single highest-value change.
2. **Add a skip link + `id="main"`** and **label the `<nav>` landmarks** (M2, L6). Cost: S. One layout edit clears two bypass/landmark findings for every page.
3. **Add `aria-current` to the view toggle and settings sub-nav** (M3). Cost: S. Brings both up to the paginator's standard.
4. **Fix the card-grid heading level** (M4). Cost: S. Restores a correct outline on the busiest page.
5. **Upgrade form errors to the summary-and-association pattern** (M5). Cost: M. The one structural piece of work; largest single accessibility gain for interactive users.
6. **Content/polish tail**: relabel "OTP" (L7), `role="alert"` on flashes (L8), `aria-hidden` the star (L9), table caption (L10), new-tab warning (L11), a `:focus-visible` style (L12). Cost: S each.

---

## Credits (each falsified before writing — see `rigour.md`)

- **"All colour pairs WCAG-AA verified" — largely holds, and I scoped it by measuring.** I computed ~30 of the riskiest pairs across all seven themes, deliberately at the smallest text sizes (`--fs-xs` 12px tags/eyebrows, `--fs-sm` 14px muted text): `--brand`, `--muted`, `.tag`, `.tag--link`, every `--label-*` on its background, `--on-brand` on fills, and `--field-border` on inputs. Every **text** and **interactive-control** pair meets AA (lowest observed 4.54:1 for retro links; interactive `--field-border` ≥ 3.5:1). The one sub-3:1 result — pastel_parlour `--border` #d183ad on `--surface` (2.36:1) — is a **decorative** card/section edge, which WCAG does not require to meet 3:1, so it is not a failure. The claim survives, scoped to text + interactive controls. (Contrast is genuinely a strength; H1 is a *use-of-colour* problem, orthogonal to contrast.)
- **Every input has an accessible name.** Falsified by walking each form: visible `<label>` on collectible/label/settings fields; visually-hidden `<label>` for the search box (`_search_form.html.erb:8`), the sort select, the access `identifier`, the share `description`/`expires_in`, and every custom-sort composer select (`custom_sorts/_form.html.erb:31,37`). No placeholder-as-only-label. The one weak name is wording, not absence — L7.
- **The paginator is fully correct.** `aria-label="Pagination"` on the nav, `aria-current="page"` on the current page, gap markers as inert `<span>`s, real `<a>` for the rest (`_pagination.html.erb`). This is the reference the parity finding (M3) measures the siblings against.
- **Focus indicators are not suppressed.** Searched the stylesheet: no `outline: none` / `outline: 0` anywhere, so the browser default ring is intact on every control (L12 is an enhancement, not a regression).
- **Language and page titles are set.** `<html lang="en">` (`application.html.erb:2`); every top-level view sets a distinct `content_for :title`, so titles are unique per page and the 2xl/xl/lg/base type scale gives a consistent visual heading hierarchy.

---

## Coverage attestation

All 40 view files/partials/layouts and the stylesheet were swept per WCAG criterion and per Nielsen heuristic across the whole scope (not screen-by-screen); the helpers/controllers that build user-facing strings and accessible names were read through the content lens. Instance censuses were run by search for the two cross-screen smells — `aria-current`/`aria-label`/`role`/`<nav>` occurrences (M3, L6) and colour-only link distinguishability computed for all seven themes (H1). Both walkthroughs were completed: sighted-mouse (visual hierarchy, affordances, conventions) and keyboard/screen-reader (landmarks, headings, names, focus order). No screens were sampled or skipped.

**Surfaced during the self-grill:** the monochrome-theme link invisibility (H1) — the light-theme ratio alone (2.42) reads as "borderline low contrast" until you compute all themes and see 1.00 in the two monochrome ones, which reframes it from a nit to the top finding; and the card-grid heading skip (M4), which only appears when you check the shared `h3` partial against *each* page it renders in rather than reading it once.
