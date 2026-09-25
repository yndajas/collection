# UI-craft review — Collection (v11)

**Lens** ui craft (usability + accessibility). **Scope** all views / partials /
layouts under `app/views/`, `app/assets/stylesheets/application.css`, the PWA
manifest + service worker, the three helpers, controller flash strings, and
`config/locales/en.yml`. **Excluded** code craft; Devise's own unpublished view
*markup* (gem defaults — only its flash/locale content is in scope).
**Depth** exhaustive. **Execution** inline, **2 independent passes** (my own pass
+ one fresh critic agent), reconciled against the code with contrast computed.
**Date** 2026-08-13. **Commit** `0a2078c` (branch `prototype`).

Sidecar: `ui_craft_review_v11.coverage.md` (per-screen matrix, parity/landmark
sweeps, the 7-theme contrast table, destructive-action census).

## Coverage caveat

A review samples a larger space than any one pass can cover, so gaps are likely —
including task-blocking accessibility failures. Two independent passes were merged
here, walking the interface twice (as a first-time sighted mouse user and as an
assistive-technology user), which raises coverage above a single pass but does not
make it complete. Contrast was computed from the theme variables, not trusted from
the stylesheet's "AA verified" comment. Devise's rendered form markup and the
full theme × element contrast matrix were not exhaustively checked.

The interface is well built for a prototype: fully rem-based type scale (zoom /
reflow respected), consistent semantic components, `fieldset`/`legend` on every
group, every input labelled, exemplary pagination, and genuinely AA-compliant text
contrast across all seven themes. The findings cluster around four roots: state
that is shown but not announced (T1); the shared layout's missing accessibility
scaffolding (T2); forms that report errors without helping you find or fix them
(T3); and inconsistently guarded destructive actions (T4).

## Findings index

| ID | Severity | Effort | Dimension | Location | Title | Status |
|----|----------|--------|-----------|----------|-------|--------|
| UI-03 | High | Small | Status Messages (WCAG 4.1.3) | layout:42-43 + controllers | Flash not announced to screen readers | open |
| UI-09 | High | Small | Non-text Content (WCAG 1.1.1) | tfa/setup:5-7 | QR-only 2FA setup, no manual key or alt | open |
| UI-01 | Medium | Small | Page Titled (WCAG 2.4.2, A) | tfa/setup, tfa/sessions | 2FA screens have no page title | open |
| UI-02 | Medium | Small | Focus Visible (WCAG 2.4.7) | application.css | No enhanced/visible focus indicator | open |
| UI-04 | Medium | Small | Name/Role/Value (WCAG 4.1.2, 1.4.1) | _nav, profiles/show, layout | Current-item cue missing on nav siblings | open |
| UI-05 | Medium | Small | Landmarks (WCAG 1.3.1) | layout:26, _nav:1, collectibles/show:4 | Unlabelled duplicate nav landmarks | open |
| UI-06 | Medium | Small | Bypass Blocks (WCAG 2.4.1) | layout:22-46 | No skip link; `main` not a target | open |
| UI-07 | Medium | Small | Heading levels (WCAG 1.3.1) | _collectible:6 + profiles/show | Shared partial h1→h3 skip on cards | open |
| UI-08 | Medium | Medium | Error identification (WCAG 3.3.1) | all forms | Error summaries not associated / focus-moved | open |
| UI-11 | Medium | Medium | Error prevention (Nielsen #5) | visibility, sorting | Destructive actions without confirmation | open |
| UI-10 | Low | Small | Labels (WCAG 2.4.6) | tfa views | Generic "OTP" field label | open |
| UI-12 | Low | Small | Non-text contrast (WCAG 1.4.11) | application.css:337,677 | Interactive boundaries below 3:1 | open |
| UI-13 | Low | Small | Input purpose (WCAG 1.3.5) | settings, visibility | Missing `autocomplete` on identity fields | open |
| UI-14 | Low | Small | Link text (WCAG 2.4.4) | profiles/show:47-49 | Single-word export links | open |
| UI-15 | Low | Small | Heading hierarchy (WCAG 1.3.1) | settings/visibility, sorting | Sibling settings sections use h3 | open |
| UI-16 | Low | Small | Consistency (Nielsen #4) | pwa/manifest | Placeholder manifest colours/description | open |

## Findings

### High

#### UI-03 · Flash messages are not announced to screen readers
**Severity** High · **Effort** Small · **Confidence** High
**Dimension** Announcing change / live regions (WCAG 2.2 4.1.3 Status Messages, AA; Nielsen #1 visibility of system status)
**Locations**
- app/views/layouts/application.html.erb:42-43 (both flash `<p>`s)
- controllers setting `notice:`/`alert:` — collectibles_controller.rb:20,37,48,82,87,103,105; follows_controller.rb:12,15,24; all settings controllers; two_factor_authentication/*_controller.rb:15,17
**Problem** `notice`/`alert` render as a plain `<p class="flash">`. "Added to your
collection", "Invalid OTP code", "You can't follow that collection" appear
visually but are never announced, so an assistive-technology user gets no
confirmation an action succeeded or failed and repeats or abandons it. Redirect
flashes render on load (a role would announce on arrival); the `flash.now` cases
(import, 2FA errors) especially need it.
**Fix** Give the flash region `role="status"` for notice and `role="alert"` for
alert (or one `aria-live="polite"`/`"assertive"` pair), on the wrapping element so
it exists at load.
**Verify** axe finds a status-message region; a screen reader announces the flash
text on load / after submit.
**Related** Theme T1; subject layout. #1 on the fix list.
**Status** open

#### UI-09 · QR-only 2FA setup — no text alternative and no manual key
**Severity** High · **Effort** Small · **Confidence** High
**Dimension** Non-text Content (WCAG 2.2 1.1.1, A); barrier on a mandatory flow
**Locations**
- app/views/two_factor_authentication/setup/show.html.erb:5-7 (`@qrcode`)
- app/controllers/two_factor_authentication/setup_controller.rb:27 (`RQRCode…as_svg.html_safe`)
**Problem** The setup screen renders an inline SVG QR code with no `role`/`title`/
label, and the provisioning secret is encoded *only* in that image. 2FA is
mandatory (`otp_required_for_login` defaults true and
`ApplicationController#ensure_2fa_setup` forces every user through setup), so a
blind user or anyone who can't scan the code cannot obtain the secret to enter it
in their authenticator app — a hard task-blocker that locks them out of the app.
**Fix** Give the SVG `role="img"` + `aria-label="QR code to set up two-factor
authentication"`, and render the secret / `otpauth` URI as selectable text ("can't
scan? enter this code manually"), which is the standard TOTP fallback.
**Verify** Screen reader announces the image role/label; the manual key is present
as copyable text and completes setup without scanning.
**Related** Theme T1; subject tfa views (3 dims). #6 on the fix list.
**Status** open

### Medium

#### UI-01 · 2FA screens have no page `<title>`
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Titles (WCAG 2.2 2.4.2 Page Titled, Level A)
**Locations**
- app/views/two_factor_authentication/setup/show.html.erb:1 (no `content_for :title`)
- app/views/two_factor_authentication/sessions/show.html.erb:1 (no `content_for :title`)
**Problem** Neither view sets a title, so both fall back to the layout default
"Collection" (layout:4). On a security-critical step, a screen-reader user
reviewing tabs or history can't tell which page they're on, and the title doesn't
describe the page — a Level A failure, on the sign-in path for every 2FA user.
**Fix** Add `content_for :title, "Set up two-factor authentication"` /
`"Verify two-factor authentication"`, matching each `<h1>`.
**Verify** `grep -L "content_for :title" app/views/two_factor_authentication/**/*.erb`
returns nothing; axe "Documents must have a title" passes.
**Related** Subject tfa views. #6 on the fix list.
**Status** open

#### UI-02 · No enhanced focus indicator (all 7 themes)
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Visible focus (WCAG 2.2 2.4.7 Focus Visible, AA)
**Locations**
- app/assets/stylesheets/application.css (whole file — `grep "focus|outline"` returns only the line-53 comment). Affects `.button`, `.button-as-link`, nav links, `.view-toggle a`, `.tag--link`, `.pagination a`, `.search-help summary`, inputs/selects.
**Problem** The stylesheet defines no `:focus`/`:focus-visible` rule. The browser
default outline is never removed (good — 2.4.7 is technically met), but it is
unenhanced and can be weak or low-contrast against the brand-filled buttons and the
custom-styled `select`/pill controls here, so a keyboard user can lose their place.
(An explicit contrast threshold for the focus ring is AAA 2.4.13, which is why this
is Medium, not a hard AA failure.)
**Fix** Add a theme-aware `:focus-visible { outline: 3px solid var(--focus, var(--text)); outline-offset: 2px; }`,
ensuring visibility on brand-filled controls (a dedicated `--focus` token, or the
GOV.UK yellow highlight for one high-contrast cue across themes).
**Verify** `grep -n "focus-visible" application.css` returns the rule; tabbing
through each theme shows a clear ring on buttons, the `select`, and pagination.
**Related** Theme T2; subject application.css. #2 on the fix list.
**Status** open

#### UI-04 · Current-item cue missing on nav-like controls
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Name/Role/Value; Use of Colour (WCAG 2.2 4.1.2, 1.4.1)
**Locations**
- app/views/settings/_nav.html.erb:2-5 (`.active`, no `aria-current`)
- app/views/profiles/show.html.erb:5 (view-toggle active link `.active`, brand-fill only, no `aria-current`)
- app/views/layouts/application.html.erb:26-37 (site-nav current item has no cue in any modality)
**Problem** Pagination correctly carries `aria-current="page"`
(_pagination.html.erb:8) but its siblings don't. The settings subnav's active tab
is bold (a valid non-colour cue) yet exposes no `aria-current`; the view-toggle's
active state is brand-fill (colour) only; the site-nav gives no "you are here" at
all. Screen-reader users aren't told which item is current.
**Fix** Add `aria-current="page"` to the active settings tab and site-nav link,
and `aria-current="true"` to the active view-toggle link.
**Verify** `grep -rn "aria-current" app/views` lists all four nav-like controls;
the accessibility tree shows "current" on the active tab/toggle.
**Related** Theme T1; subject profiles/show. #4 on the fix list.
**Status** open

#### UI-05 · Multiple `<nav>` landmarks share no distinguishing name
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Landmark naming (WCAG 2.2 1.3.1; ARIA landmark practice)
**Locations**
- app/views/layouts/application.html.erb:26 (site-nav, no label)
- app/views/settings/_nav.html.erb:1 (subnav, no label)
- app/views/collectibles/show.html.erb:4 (breadcrumb `<nav>`, no label)
- (only app/views/application/_pagination.html.erb:3 is labelled)
**Problem** On a settings page a screen-reader landmark list reads "navigation,
navigation, navigation" with no way to tell them apart, defeating the landmark
shortcut.
**Fix** Distinct `aria-label`s: site-nav "Primary", subnav "Settings", breadcrumb
"Breadcrumb". Pagination already labelled.
**Verify** Every `<nav>` in `grep -rn "<nav" app/views` carries an `aria-label`;
axe "landmarks should be unique" passes.
**Related** Theme T2; subject layout. #1 on the fix list.
**Status** open

#### UI-06 · No skip link; `<main>` is not a focus target
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Bypass Blocks (WCAG 2.2 2.4.1)
**Locations**
- app/views/layouts/application.html.erb:22-46 (header repeats nav every page; no skip link; `<main class="site-main">` has no `id`)
**Problem** The header repeats the same 4-5 nav links on every page; a keyboard or
screen-reader user must tab through them on every navigation to reach content, with
no "skip to main content" bypass.
**Fix** Add `<a href="#main-content" class="skip-link">Skip to main content</a>`
as the first `<body>` child, give `<main id="main-content" tabindex="-1">`, and
reveal the link on focus.
**Verify** Tab once from load — the skip link appears and, on Enter, moves focus
into `<main>`.
**Related** Theme T2; subject layout. #1 on the fix list.
**Status** open

#### UI-07 · Shared `_collectible` partial emits `<h3>`, skipping `<h2>` on the cards view
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** Heading levels across a shared partial's contexts (WCAG 2.2 1.3.1, 2.4.10)
**Locations**
- app/views/collectibles/_collectible.html.erb:6 (`<h3 class="card__title">`)
- app/views/profiles/show.html.erb:64-66 (cards grid — nearest heading is the page `<h1>` at :10, so **h1 → h3**)
- app/views/root/index.html.erb:25,31 (under `<h2>` "From your collection" — h2 → h3, correct)
**Problem** The same partial is correct on the homepage but skips a level on the
collection page, where the cards sit directly under the `<h1>` with no intervening
`<h2>`. A screen-reader user navigating by heading hits a gap — the classic
shared-partial heading defect a single-screen review can't see.
**Fix** Wrap the collection cards grid in a section with an `<h2>` (a
visually-hidden "Collectibles" heading is fine), or make the card heading level a
partial local each caller passes.
**Verify** axe "heading levels should only increase by one" passes on the cards
view; no h1→h3 jump in the rendered heading outline.
**Related** Subject _collectible.erb, profiles/show. #5 on the fix list.
**Status** open

#### UI-08 · Error summaries are not associated with fields or focus-moved
**Severity** Medium · **Effort** Medium · **Confidence** High
**Dimension** Error identification & association (WCAG 2.2 3.3.1, 3.3.3; GOV.UK error-summary pattern)
**Locations**
- app/views/collectibles/_form.html.erb:9-18; settings/labels/edit.html.erb:6-8; labels/index.html.erb:14-16; settings/show.html.erb:7-9; settings/custom_sorts/_form.html.erb:4-9; collectibles/_import_fields.html.erb:9-11
- controller `alert:` summaries — settings/visibility_controller.rb:15, share_links_controller.rb:21, profile_accesses_controller.rb:20
**Problem** On a failed submit, errors render as a `<div class="errors">` (or a
flat sentence) — not linked to the offending inputs, not moved to focus, and the
inputs carry no `aria-invalid`/`aria-describedby`. A screen-reader user isn't told
an error occurred nor taken to it; a keyboard user must hunt. The markup looks
like a plausible error block while announcing nothing useful.
**Fix** Adopt the GOV.UK error-summary pattern: a container with
`role="alert"`/`tabindex="-1"` focused on load, each message a link to `#field_id`;
set `aria-invalid="true"` + `aria-describedby` on each errored input with the
message in that described element.
**Verify** On a failed submit, focus lands on the summary, each error links to its
field, and axe reports the input–message association.
**Related** Theme T3; all form views. #3 on the fix list.
**Status** open

#### UI-11 · Destructive actions with no confirmation step
**Severity** Medium · **Effort** Medium · **Confidence** Medium
**Dimension** Error prevention (Nielsen #5; Norman: constraints); consistency (Nielsen #4)
**Locations**
- app/views/settings/visibility/show.html.erb:47 (Remove access)
- app/views/settings/visibility/show.html.erb:84 (Revoke share link)
- app/views/settings/sorting/show.html.erb:42 (Delete custom sort)
**Problem** Collectible-delete and label-delete get proper confirm screens
(credited), but revoking a share link, removing a person's access, and deleting a
custom sort are single-click `button_to` actions with no confirmation and no undo.
A misclick silently cuts off access or destroys a sort config — and it's
inconsistent with the two flows that do confirm.
**Fix** Route these through a confirm step (a screen like the existing ones, or at
minimum `data-turbo-confirm`), or offer undo. Match the established delete pattern.
**Verify** Each destructive control requires a confirming interaction; the pattern
is consistent across all delete/revoke/remove actions.
**Related** Theme T4. #7 on the fix list.
**Status** open

### Low

#### UI-10 · Generic "OTP" field label
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Labels / plain language (WCAG 2.2 2.4.6 Headings and Labels)
**Locations**
- app/views/two_factor_authentication/setup/show.html.erb:14
- app/views/two_factor_authentication/sessions/show.html.erb:8
**Problem** The visible/accessible label is the acronym "OTP"; the surrounding
prose says "6-digit code from your authenticator app", but the field's name (as a
screen reader lists it) is bare jargon.
**Fix** Label it "One-time code" or "6-digit code". `autocomplete="one-time-code"`
is already correct.
**Verify** Accessibility tree shows the descriptive name; no bare acronym.
**Related** Subject tfa views. #6 on the fix list.
**Status** open

#### UI-12 · Interactive control boundaries below 3:1
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Non-text contrast (WCAG 2.2 1.4.11)
**Locations**
- app/assets/stylesheets/application.css:337 (`.tag--link` border = `var(--border)`)
- app/assets/stylesheets/application.css:677 (`.pagination a` border = `var(--border)`)
**Problem** These interactive controls draw their boundary with `--border`, a value
tuned for *decorative* card edges (light `#e2e5ee` on `#fff` ≈ **1.26:1**), so the
pagination page-number boxes and external-link pills read as edgeless — weak
affordance as discrete targets. Text still meets contrast, so this is a
UI-component-boundary nuance (monochrome themes are fine — border == ink).
**Fix** Give interactive tags/pagination a `--field-border`-strength boundary
(already ≥3:1), or add a persistent non-colour affordance (a resting underline on
`.tag--link`, which currently only appears on hover).
**Verify** Non-text-contrast check on the pagination and `.tag--link` borders ≥3:1
in every theme.
**Related** Subject application.css. 
**Status** open

#### UI-13 · Missing `autocomplete` on identity fields
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Identify Input Purpose (WCAG 2.2 1.3.5)
**Locations**
- app/views/settings/show.html.erb:15 (display_name), :19 (username)
- app/views/settings/visibility/show.html.erb:39 (email-or-username identifier)
**Problem** These identity fields set no `autocomplete`, so browsers/password
managers can't autofill and the field purpose isn't exposed.
**Fix** `autocomplete="nickname"` (display_name), `autocomplete="username"`
(username); leave the ambiguous email-or-username identifier or split it.
**Verify** `grep autocomplete app/views/settings/**/*.erb` shows the tokens.
**Related** — 
**Status** open

#### UI-14 · Single-word export links
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Link text & target size (WCAG 2.2 2.4.4)
**Locations**
- app/views/profiles/show.html.erb:47 ("CSV"), :49 ("JSON")
**Problem** "CSV"/"JSON" are single-word links — small motor targets whose text is
ambiguous out of context (e.g. in a screen-reader link list).
**Fix** "Export as CSV" / "Export as JSON" (also absorbs the separate "Export"
label word), giving larger, self-describing targets.
**Verify** Link list shows descriptive text; targets are multi-word.
**Related** — 
**Status** open

#### UI-15 · Sibling settings sections use `<h3>`, skipping `<h2>`
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Heading hierarchy (WCAG 2.2 1.3.1)
**Locations**
- app/views/settings/visibility/show.html.erb:35 ("People with access"), :57 ("Share links") — top-level sections at `<h3>` under the `<h2>` "Visibility"
- app/views/settings/sorting/show.html.erb:28 ("Custom sorts") — sibling-level section at `<h3>`
**Problem** These are independent top-level sections of the page, not sub-parts of
the preceding `<h2>` section, yet they're marked `<h3>`, so the heading outline
implies a nesting that doesn't exist.
**Fix** Promote sibling-level sections to `<h2>` (or wrap them so the `<h3>` is
genuinely nested).
**Verify** The heading outline of each settings page reflects the real section
nesting; no orphan level jump.
**Related** — 
**Status** open

#### UI-16 · PWA manifest uses placeholder colours and description
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Consistency / polish (Nielsen #4)
**Locations**
- app/views/pwa/manifest.json.erb:19 (`"description": "Collection."`), :20-21 (`"theme_color": "red"`, `"background_color": "red"`)
**Problem** The installed-PWA splash/theme colour is bare CSS `red`, matching none
of the seven themes, and the description is a placeholder. User-facing install
chrome.
**Fix** Set `theme_color`/`background_color` to the light theme's `--brand`/`--bg`
(`#3a52c6` / `#f6f7fb`) and write a real description.
**Verify** Lighthouse PWA audit; the installed icon/splash uses brand colours.
**Related** — 
**Status** open

## Themes

### T1 · State is shown but not announced
**Members** UI-03 (flash), UI-04 (active nav/tab/toggle), UI-08 (error state),
UI-09 (QR conveys a secret only visually). **Root** the UI reports state and
outcomes visually with no ARIA equivalent. Whole-scope re-sweep:
`role=status`/`alert`/`aria-live` appear **zero** times in `app/views`;
`aria-current` appears **once** (pagination). **Leverage** the dominant cluster —
adding announced equivalents at each state-change point is the highest-value work.

### T2 · The shared layout's accessibility scaffolding is incomplete
**Members** UI-02 (focus), UI-03 (flash region), UI-05 (nav labels), UI-06 (skip
link). **Root** `layouts/application.html.erb` (plus the stylesheet for focus) is
the single element that would fix bypass, landmark naming, status announcement, and
focus for the whole app at once. **Leverage** one file resolves most of the
structural accessibility gaps.

### T3 · Forms report errors but don't help you find or fix them
**Members** UI-08 (association/focus), UI-10 (label wording). **Root** every form
(9 of 9) renders errors as an untied banner/sentence; none move focus or set
`aria-invalid`. **Leverage** a single shared error-summary component dissolves all
of them.

### T4 · Destructive actions are inconsistently guarded
**Members** UI-11. **Root** two delete flows confirm, three don't. A consistency
and error-prevention gap; one shared confirm pattern closes it.

## Subject grid

| Subject | Dimensions (finding IDs) | # | Severity | Interpretation |
|---------|--------------------------|---|----------|----------------|
| layouts/application.html.erb | UI-02(+css), UI-03, UI-05, UI-06 | 4 | **High** | the app's single point of failure for accessible page structure: no skip target, no named landmarks, no live region, no focus enhancement |
| tfa setup/sessions views | UI-01, UI-09, UI-10 | 3 | **High** | a mandatory security flow that is untitled, image-only, and jargon-labelled |
| application.css | UI-02, UI-12 | 2 | Medium | focus + interactive-boundary contrast |
| profiles/show.html.erb | UI-04, UI-07, UI-14 | 3 | Medium | parity, heading context, link text (each individually small) |
| settings/visibility, sorting | UI-11, UI-15 | 2 | Medium | destructive guards + heading hierarchy |
| all form views | UI-08 | 1 | Medium | shared error pattern |

**Convergence rule** a subject at 3+ distinct dimensions gets its own finding at
High or higher. Both `layouts/application.html.erb` (4 dims) and the **2FA views**
(3 dims, a security flow) cross the floor and are escalated to High-priority
clusters — the layout via UI-03/UI-06 severity, the 2FA flow via UI-09. The floor
is held on dimension count, not lowered by any "each item is small" impression:
`profiles/show` also sits at 3 dims but its three findings are genuinely
independent small nits on different controls (not one root cause), so it stays a
Medium hotspot rather than escalating — the evidence is that no single fix
dissolves all three.

## Leverage-ordered fix list

1. **Rework the shared layout** (`layouts/application.html.erb`): skip link + `main#main-content[tabindex=-1]`, an `aria-label` per nav, flash wrapped in `role="status"`/`role="alert"` → dissolves UI-03, UI-05, UI-06 (3). Effort Small. *Cheapest structural win.*
2. **Add a global `:focus-visible` style** to `application.css`, theme-aware → dissolves UI-02 across all 7 themes (1). Effort Small.
3. **Build one error-summary component** and wire every form to it (focus + `aria-invalid` + `aria-describedby`) → dissolves UI-08 for all 9 forms (1, wide). Effort Medium.
4. **Add `aria-current`** to settings subnav, view-toggle, and site-nav active item → dissolves UI-04 (1). Effort Small.
5. **Fix the card heading level** on `profiles/show` (section + `<h2>`, or partial local) → dissolves UI-07; promote sibling settings sections → UI-15 (2). Effort Small.
6. **2FA screen pass**: titles, "One-time code" label, `role="img"`+label on the QR, and a manual-entry text fallback → dissolves UI-01, UI-09, UI-10 (3). Effort Small.
7. **Confirmation on the three unguarded destructive actions** → dissolves UI-11 (1). Effort Medium.
8. Tail: interactive-boundary contrast (UI-12), autocomplete (UI-13), export link text (UI-14), manifest polish (UI-16). Effort Small each.

## Credits

Each falsified before writing, scoped to what was checked.

- **Text contrast genuinely meets AA across all 7 themes.** Falsified by computing
  the tightest pairs (sidecar table), not trusting the "AA verified" comment:
  retro brand link 4.54:1, light on-danger 4.63:1, all muted/brand/label-chip/flash
  pairs 5:1–17:1, `--field-border` on inputs ≥3.6:1 (1.4.11). The only sub-3:1
  value is `--border`, legitimately decorative *except* where it bounds interactive
  controls (carved out as UI-12). A real strength.
- **Every form input has an associated `<label>`.** Falsified across the whole
  census: search fields use `visually-hidden` `label_tag`; sort-composer selects
  each get a hidden `label_tag` (custom_sorts/_form.html.erb:31,37);
  `collection_check_boxes` / `check_box_tag` are label-wrapped. No unlabelled input
  found.
- **Radio/checkbox groups use `<fieldset>`/`<legend>` correctly** — confirmed on
  `_form` (Status/Multiplayer/Labels/Players), `import` (Format/Default type),
  `visibility`, `sorting`, `settings/show`, `_type_checkboxes`. No orphan group.
- **Pagination is exemplary** — `aria-label="Pagination"` *and*
  `aria-current="page"` on the current page (_pagination.html.erb:3,8): the pattern
  the siblings (UI-04) should copy.
- **Confirm-delete screens for collectibles and labels** are well done: distinct
  title, `<h1>`, plain-language "this can't be undone", `.button--danger`. Scoped:
  falsified against the *other* destructive actions — three lack this (UI-11), so
  the credit covers only these two flows.
- **Type scale is fully rem-based and theme-independent** (application.css:22-30),
  so text zoom (1.4.4) and reflow (1.4.10) hold; layout uses `max-width` + flex/grid
  with a `40rem` breakpoint.
- **Optional fields are marked, not required ones** (custom_sorts/_form.html.erb:12
  "Name (optional)") — the low-noise GOV.UK convention, correctly applied.
- **The default focus outline is never removed** (no `outline: none` anywhere), so
  UI-02 is a missing-enhancement, not actively-broken-focus — which is why it is
  Medium, not High.

**Coverage gaps** Devise's own sign-in/up/reset view *markup* is gem-default and
unpublished, so only its flash/locale content was reviewed, not its rendered
fields. Contrast was computed for the tightest identifiable pairs, not all theme ×
element combinations. As a merged two-pass review, expect some tail items to
remain — a further fresh pass is the most reliable way to close them.
