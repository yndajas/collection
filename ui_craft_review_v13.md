# UI-craft review — v13

**Lens** UI craft — usability (Krug, Nielsen's heuristics, Norman) and
accessibility (WCAG 2.2 AA, GOV.UK Design System / dxw accessibility manual).
**Scope** The whole view layer: all `app/views/**` templates and partials, the
layout, `app/assets/stylesheets/application.css`, the PWA manifest and
service-worker, and user-facing content assembled in helpers/controllers (flash
strings, labels, alt text). **Excluded:** server-side code quality/security (see
`code_craft_review_v13.md`); Devise's sign-in/up/reset views (gem defaults, not in
the repo — flagged as a coverage gap, UI-14). **Depth** Exhaustive. **Execution**
Inline, two independent parallel passes (fresh agents), diffed and verified against
the source, then synthesised. **Date** 2026-08-14. **Commit** `0a2078c` (branch
`prototype`).

IDs are fresh for this pass (`UI-`). Unbiased: no prior review file was consulted.

## Coverage caveat

A review is a sample of a larger space, and gaps are likely — including
task-blocking ones. Two independent passes were run and reconciled; the second
pass caught findings the first missed (the h1→h3 heading skip in particular), which
is exactly why more than one look raises coverage. But this is a *static* review:
focus order, live-region announcements, actual screen-reader output, reflow at
400%/320px, and target-size all need a running app with `axe` + VoiceOver/NVDA to
confirm. Several findings are marked accordingly. Another independent pass, or a
live assistive-technology pass, is the most reliable way to raise coverage further.

## Findings index

| ID | Severity | Effort | Dimension | Location(s) | Title | Status |
|----|----------|--------|-----------|-------------|-------|--------|
| UI-01 | High | Medium | WCAG 1.1.1 / inclusive design | 2fa setup | 2FA QR has no manual key or text alternative | open |
| UI-02 | High | Medium | WCAG 3.3.1 / 1.3.1 / 4.1.3 | all forms | Error blocks aren't an accessible error summary | open |
| UI-03 | Medium | Small | WCAG 2.4.1 Bypass Blocks | layout | No skip link | open |
| UI-04 | Medium | Small | WCAG 2.4.7 Focus Visible | application.css | No house focus indicator | open |
| UI-05 | Medium | Small | WCAG 4.1.3 Status Messages | layout | Flash messages aren't live regions | open |
| UI-06 | Medium | Small | WCAG 1.3.1 Info & Relationships | _collectible.html.erb:6 | Heading skips h1→h3 on collection pages | open |
| UI-07 | Medium | Small | WCAG 2.4.6 / 1.3.1 | settings/* | Every settings page's `<h1>` is generic "Settings" | open |
| UI-08 | Medium | Small | WCAG 4.1.2 Name, Role, Value | _follow_button.html.erb | Follow toggle names its state, hides the action in `title` | open |
| UI-09 | Medium | Small | WCAG 2.4.4 / 4.1.2 | settings list rows | Repeated "Edit"/"Delete"/"Revoke" with no per-row context | open |
| UI-10 | Medium | Small | WCAG 1.4.1 / Krug signifiers | _collectible.html.erb | Link chips indistinguishable from static chips | open |
| UI-11 | Medium | Small | WCAG 3.2.5 / content | _collectible.html.erb:31-33 | External links open new tab with no warning | open |
| UI-12 | Medium | Small | WCAG 3.3.2 / forms.md | 2fa views | "OTP" jargon label; no numeric inputmode | open |
| UI-13 | Medium | Medium | Nielsen #5 Error prevention | import.html.erb | Paste + file + format inputs can silently conflict | open |
| UI-14 | Medium | Medium | Nielsen #4 / forms.md | devise + 2fa views | Auth pages are unstyled defaults with no error pattern | open |
| UI-15 | Medium | High | Nielsen #6 Recognition over recall | search forms | Power-user query syntax with no plain-language controls | open |
| UI-16 | Low | Small | consistency / PWA UX | pwa/manifest.json.erb | Manifest ships placeholder red + one icon size | open |
| UI-17 | Low | Small | WCAG 1.3.1 / 1.1.1 | application_helper.rb:44 | "★ Following" glyph announced by screen readers | open |
| UI-18 | Low | Small | Nielsen #8 minimalism | root/index.html.erb | Three empty collection shelves on the new-user homepage | open |
| UI-19 | Low | Small | Nielsen #6 | settings/labels | Label colour `<select>` gives no swatch preview | open |
| UI-20 | Low | Small | Nielsen #4 / Krug | search forms | "Search" and "Apply" buttons do the same thing | open |

## Findings

### High

#### UI-01 · 2FA setup offers only a QR code — no manual key, no text alternative
**Severity** High · **Effort** Medium · **Confidence** High
**Dimension** WCAG 2.2 1.1.1 Non-text Content (A); inclusive design (don't force one input path); Nielsen #3 User control
**Locations**
- app/views/two_factor_authentication/setup/show.html.erb:5-7 (`<div class="qr-code"><%= @qrcode %></div>`)
- app/controllers/two_factor_authentication/setup_controller.rb:26-27 (`@provisioning_uri` computed, then `@qrcode = RQRCode…as_svg(module_size: 4).html_safe`)

**Problem** Verified from the controller: the provisioning URI is computed but never
rendered, and no `otp_secret` key is shown — the QR image is the *only* enrolment
path. A blind user, anyone whose authenticator is on the same device (so can't scan
its own screen — very common), or anyone with a broken camera cannot complete 2FA
setup, a security-critical step. The `as_svg` output also carries no `role="img"` or
`<title>`, so a screen reader announces nothing (or dives into hundreds of `<rect>`
children).
**Fix** (1) Render the secret in text: `<p>Can't scan? Enter this key manually:
<code><%= current_user.otp_secret %></code></p>` (formatted in space-separated
groups). (2) Give the SVG an accessible name — wrap it `<div role="img"
aria-label="QR code to add this account to your authenticator app">`, or
`aria-hidden="true"` once the manual key is the primary path.
**Verify** With images off and a screen reader on, a user completes enrolment using
the text key alone; the accessibility tree shows one labelled image node, not a tree
of rects.
**Related** Theme T-UI-3. #2 on the fix list.
**Status** open

#### UI-02 · Form error blocks are not an accessible error summary
**Severity** High · **Effort** Medium · **Confidence** High
**Dimension** WCAG 2.2 3.3.1 Error Identification (A), 3.3.3 Error Suggestion (AA), 1.3.1 (A), 4.1.3 (AA); `forms.md` error-summary pattern; Nielsen #9
**Locations**
- app/views/collectibles/_form.html.erb:9-18 (`.errors` list of `full_messages`)
- app/views/collectibles/_import_fields.html.erb:9-11 (per-item `.errors`, `to_sentence`)
- app/views/settings/show.html.erb:7-9, settings/labels/index.html.erb:14-16, settings/labels/edit.html.erb:6-8, settings/custom_sorts/_form.html.erb:4-9

**Problem** On a failed submit each form renders a generic error banner at the top,
but: (a) focus is not moved to it, so after `render …, status: :unprocessable_entity`
a keyboard/screen-reader user lands on the nav with no signal the submit failed;
(b) the summary items are plain text, not links to the offending fields; (c) invalid
inputs carry no `aria-invalid="true"` and no `aria-describedby` pointing at their
message — field and error are associated only by proximity. The banner is also not a
live region, so a future Turbo re-render would be silent. This is the same defect on
every form in the app.
**Fix** Adopt the error-summary pattern (`forms.md`): a container with `role="alert"`
and `tabindex="-1"` that receives focus on failed submit, each error an in-page link
to the field `id`; set `aria-invalid="true"` and `aria-describedby="<field>-error"`
on each errored input, with the message in an element of that id. One shared partial
fixes every form.
**Verify** Submit an invalid collectible form with a screen reader — failure is
announced, focus lands on the summary, each link jumps to and names its field.
**Related** Theme T-UI-2; also lifts UI-14. #1 on the fix list.
**Status** open

### Medium

#### UI-03 · No skip link
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 2.4.1 Bypass Blocks (A); `accessible-code.md` landmarks
**Locations**
- app/views/layouts/application.html.erb:21-46 (header nav precedes `<main>` on every page; `grep skip` over views/assets returns nothing)

**Problem** The header nav (4-5 links) is the first focusable content on every page,
re-rendered on every navigation. Keyboard and switch users must tab through all of it
to reach `<main>` each time. `<main class="site-main">` exists (good) but has no `id`
and takes no programmatic focus.
**Fix** Add as the first child of `<body>`: `<a href="#main-content"
class="skip-link">Skip to main content</a>`; give `<main id="main-content"
tabindex="-1">`; style `.skip-link` visually-hidden-until-`:focus` (the existing
`.visually-hidden` stays hidden on focus, so add a focusable variant).
**Verify** Tab from a fresh load — first stop is a visible "Skip to main content"
that moves focus into `<main>`; axe "bypass" passes.
**Related** Theme T-UI-1. #3 on the fix list.
**Status** open

#### UI-04 · No house focus indicator
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 2.4.7 Focus Visible (AA); `accessible-code.md` "include `:focus`, prefer `:focus-visible`"
**Locations**
- app/assets/stylesheets/application.css (verified: no `:focus`/`:focus-visible` rule anywhere; the sole "outline" match is a comment)

**Problem** The stylesheet defines `:hover` states but never a focus style.
Adjudicated between the two passes: nothing sets `outline: none`, so the browser
default outline *is* present and 2.4.7 is not outright failed — hence Medium, not
High. But the default thin outline can be nearly invisible against the brand-filled
`.button` and the segmented `.view-toggle a.active` (a brand fill), so focus is not
reliably perceivable, and any future `outline: none` would silently break it with no
replacement. It's a robustness/consistency gap on a real AA criterion.
**Fix** Add a global ring that works on every theme:
`:where(a,button,input,select,textarea,summary,[tabindex]):focus-visible { outline:
3px solid var(--brand); outline-offset: 2px; }`, pairing a contrasting colour or a
box-shadow halo on controls that already use `--brand` as a fill.
**Verify** Tab through each page in the monochrome and pastel themes; every control
shows a clearly visible ring at ≥3:1 against adjacent colour. (Manual — axe won't
catch this.)
**Related** Theme T-UI-1.
**Status** open

#### UI-05 · Flash messages aren't live regions
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 4.1.3 Status Messages (AA); Nielsen #1 Visibility of system status
**Locations**
- app/views/layouts/application.html.erb:42-43 (`<p class="flash flash--notice">` / `flash--alert`, plain paragraphs)
- `flash.now` render paths: app/controllers/collectibles_controller.rb:82, 87, 105 (import); two_factor_authentication/setup_controller.rb:15 and sessions_controller.rb (invalid OTP)

**Problem** The flash is the app's entire feedback channel ("Removed from your
collection", "Invalid OTP code", import results). After a redirect it's in the new
DOM so a screen reader reaches it eventually, but with no `role` it isn't announced
*as a status*; and on the `flash.now` re-render paths (import errors, wrong OTP) it
appears without a navigation and is never announced. Sighted users get a coloured
banner; AT users may miss it.
**Fix** Mark the notice region `role="status"` (polite) and the alert region
`role="alert"` (assertive). Keep the regions in the DOM even when empty if you later
move to async updates, so the live region exists before content arrives.
**Verify** Trigger a failed import or wrong OTP with a screen reader — the message is
spoken without navigating. (Manual SR test; axe won't catch it.)
**Related** Theme T-UI-1.
**Status** open

#### UI-06 · Heading level skips h1 → h3 on collection pages
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 1.3.1 Info and Relationships (A); `accessible-code.md` "headings never skip levels"
**Locations**
- app/views/collectibles/_collectible.html.erb:6 (hard-coded `<h3 class="card__title">`)
- app/views/profiles/show.html.erb:10 (`<h1>`) then the cards grid renders the partial at :63-68 with no intervening `<h2>` → h1→h3
- app/views/root/index.html.erb:21 (`<h2>From your collection</h2>`) hosts the same partial correctly (h2→h3)

**Problem** A shared partial with a fixed `h3` is correct on the homepage (under an
h2) but skips a level on a collection page (directly under the h1). Screen-reader
users navigating by heading get a broken outline. Verified both contexts from source.
This was caught by only one of the two passes — a genuine miss the second look
surfaced.
**Fix** Preferably demote the card title from a heading to non-heading markup (it's a
link; `.card__title` styling can move to a `<p>`/`<div>`), removing 24 per-card
headings a grid doesn't need. Or pass a `heading_level:` local so `profiles/show`
uses `h2` and the homepage `h3`.
**Verify** Run HeadingsMap on `/u/<username>` in card view — no skipped levels; the
homepage outline stays logical.
**Related** Theme T-UI-4.
**Status** open

#### UI-07 · Every settings page's `<h1>` is the generic "Settings"
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 2.4.6 Headings and Labels (AA), 1.3.1; Krug "Where am I?"
**Locations**
- app/views/settings/show.html.erb:3, settings/visibility/show.html.erb:3, settings/sorting/show.html.erb:3, settings/labels/index.html.erb:3 — all render `<h1>Settings</h1>` then a section `<h2>`

**Problem** Each settings page has exactly one `<h1>` (good) but it's identical
("Settings") across four distinct pages, while the `<title>` differs ("Visibility",
"Labels", …). The visible heading doesn't say which page you're on — the identity
lives only in the sub-nav `.active` state and the `<h2>`. The title/heading mismatch
also breaks the usual expectation that they align.
**Fix** Make each settings page's `<h1>` its real subject ("Visibility", "Labels",
"Sorting", "General") and drop the redundant "Settings" heading (or demote it to a
small eyebrow). The sub-nav marks location; the `<h1>` names it.
**Verify** Each settings page's single `<h1>` matches its `<title>` and active
sub-nav item.
**Related** Theme T-UI-4.
**Status** open

#### UI-08 · Follow toggle names its state, hides the action in `title`
**Severity** Medium · **Effort** Small · **Confidence** Medium
**Dimension** WCAG 2.2 4.1.2 Name, Role, Value (A), 1.4.1; Nielsen #4, #6
**Locations**
- app/views/profiles/_follow_button.html.erb:2-7 (following → `button_to "Following"` with `title: "Unfollow this collection"`; not-following → `button_to "Follow"`)

**Problem** In the following state the accessible name is "Following" — the current
*state*, not the *action* (unfollow). The only hint that clicking unfollows is the
`title` tooltip, which screen readers generally don't announce, touch users can't
hover for, and keyboard users can't reach. `aria-pressed` isn't used, so the toggle
state isn't exposed as a toggle either. Follow vs following also leans on the
ghost-vs-solid fill (colour/weight).
**Fix** Either use an explicit action label that changes ("Follow" ↔ "Unfollow"), or
keep "Following" and add `aria-pressed="true"` plus visually-hidden " — unfollow" so
the accessible name is unambiguous. Don't rely on `title`.
**Verify** A screen reader on the following state announces an action the user
understands (or "Following, pressed").
**Related** Theme T-UI-3.
**Status** open

#### UI-09 · Repeated "Edit"/"Delete"/"Revoke"/"Remove" across list rows with no context
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 2.4.4 Link Purpose (In Context) (A) / 4.1.2; `accessible-code.md` unique accessible names
**Locations**
- app/views/settings/labels/index.html.erb:45-46 ("Edit"/"Delete" per label row)
- app/views/settings/sorting/show.html.erb:41-42 ("Edit"/"Delete" per custom sort)
- app/views/settings/visibility/show.html.erb:47 ("Remove" per person), :84 ("Revoke" per share link)

**Problem** Each list row emits an identically-named control. A screen-reader user
listing controls (or using the rotor) hears "Edit, Edit, Edit… Delete, Delete…" with
no way to tell which label/sort/person/link each acts on — the exact case
`accessible-code.md` calls out.
**Fix** Append visually-hidden context per control, e.g. `Edit<span
class="visually-hidden"> label "Comfort games"</span>`. Same for Delete/Remove/Revoke.
**Verify** The links/forms rotor shows uniquely named controls.
**Related** Theme T-UI-3.
**Status** open

#### UI-10 · Link chips are visually indistinguishable from static chips
**Severity** Medium · **Effort** Small · **Confidence** Medium
**Dimension** WCAG 2.2 1.4.1 Use of Color (A); Krug "make clickable things obviously clickable"; Norman signifiers
**Locations**
- app/views/collectibles/_collectible.html.erb:15-19 (trait `.tag`), :22-26 (`.tag--label`), :29-35 (`.tag.tag--link`); CSS `.tag` and `.tag--link` differ only by border/background/size, no underline, same pill shape
- app/views/collectibles/show.html.erb (same three chip families stacked)

**Problem** A card shows three rows of pills that all look like the same kind of
thing; only the external-link pills are clickable, and nothing signals that until
hover — which touch users never get, and which is a colour/hover-only affordance for
everyone. Trait pills ("Completed") look identical to link pills.
**Fix** Give `.tag--link` a persistent, non-hover signifier — an underline, a link
colour, and/or a trailing external-link glyph — distinct from the static
`.tag`/`.tag--label`.
**Verify** Without hovering, a first-time user (colour-blind and touch users included)
can tell which chips are actionable.
**Related** Theme T-UI-3.
**Status** open

#### UI-11 · External links open a new tab with no warning
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 3.2.5 Change on Request (AAA, best practice at AA); Nielsen #3; `content.md` link text; G201
**Locations**
- app/views/collectibles/_collectible.html.erb:31-33 and show.html.erb:52-54 (`link_to link[:name], link[:url], target: "_blank", rel: "noopener"` — text is just the site name)

**Problem** Opening a new tab unexpectedly disorients users who rely on Back (it
won't return) and screen-reader users who aren't told a new context opened. Compounded
by UI-10 (they don't look like links).
**Fix** Append a visually-hidden "(opens in new tab)" to each link's accessible name
(or a small external-link icon carrying that text). Consider whether new-tab
behaviour is needed at all.
**Verify** A screen reader announces "…, opens in new tab" for each external link.
**Related** Theme T-UI-3.
**Status** open

#### UI-12 · "OTP" jargon label; no numeric input mode
**Severity** Medium · **Effort** Small · **Confidence** High
**Dimension** WCAG 2.2 3.3.2 Labels or Instructions (A), 2.4.6; `content.md` plain language; Nielsen #2; `forms.md` sensible input types
**Locations**
- app/views/two_factor_authentication/setup/show.html.erb:13 and sessions/show.html.erb:8 (`f.label :otp_attempt, "OTP"`; plain `text_field` with `autocomplete: "one-time-code"`)

**Problem** The programmatic label a screen reader announces is "OTP", an acronym on
a high-stakes login step, even though the prose says "6-digit code". The field is a
plain text input with no `inputmode`, so mobile users get an alphabetic keyboard for a
numeric code. (`autocomplete="one-time-code"` is already correct — credit.)
**Fix** Label it "6-digit code" (or "Authentication code"); add `inputmode: "numeric"`
and optionally `pattern: "[0-9]*"`.
**Verify** On mobile the numeric keypad appears; a screen reader announces a
plain-language label.
**Related** Theme T-UI-5.
**Status** open

#### UI-13 · Import lets paste + file + format inputs conflict silently
**Severity** Medium · **Effort** Medium · **Confidence** Medium
**Dimension** Nielsen #5 Error prevention; Norman constraints; `forms.md` "prevent first"
**Locations**
- app/views/collectibles/import.html.erb:10-51 (a "Format" radio group, a "Default type" group, a "Paste your data" textarea, and a file input)
- controller precedence: collectibles_controller.rb:113 (`import_format` prefers the radio, else infers from file extension), :126-129 (`import_content` prefers the file over the textarea)

**Problem** A user can paste text, choose a file, and pick a format radio that
disagrees with the file's extension — three inputs that can conflict. The UI neither
prevents nor explains it: the hint says a file's extension "sets the format
automatically", silently overriding the radios, and nothing says the file also wins
over the pasted text. A mistake waiting to happen on a bulk action.
**Fix** State precedence inline ("If you upload a file, the pasted text and the Format
above are ignored") and/or disable the textarea + Format radios once a file is chosen;
or split "paste" vs "upload" into an explicit choice.
**Verify** A first-time importer can predict which input will be used before
submitting.
**Related** Theme T-UI-6.
**Status** open

#### UI-14 · Auth pages are unstyled defaults with no error pattern
**Severity** Medium · **Effort** Medium · **Confidence** Medium
**Dimension** Nielsen #4 Consistency and standards; `forms.md`; WCAG 3.3.1
**Locations**
- app/views/two_factor_authentication/sessions/show.html.erb and setup/show.html.erb wrap fields in bare `<div>` (not `.field`/`.stack`), so they miss the app's label/spacing treatment and set no `content_for :title`
- No `app/views/devise/**` exist (verified) → sign-in/up/reset render Devise gem defaults, outside the app's form patterns and error-summary handling

**Problem** The authentication surface — the first screens a new user meets — is
visually and structurally inconsistent with the rest of the app, and its error
handling doesn't follow UI-02's summary pattern. Prototype-stage, so lower priority,
but it's on the key path, and the Devise views can't be confirmed accessible from the
repo (coverage gap).
**Fix** Wrap the 2FA fields in `.stack`/`.field`; run `rails g devise:views` and apply
the app's form markup, `autocomplete` attributes (`email`/`current-password`/
`new-password`), and the UI-02 error summary; add `content_for :title` to the 2FA
pages.
**Verify** Sign-up/in/2FA pages match the app's form styling and follow the same error
behaviour; run axe on the rendered pages.
**Related** Themes T-UI-2, T-UI-5.
**Status** open

#### UI-15 · Power-user query syntax with no plain-language controls
**Severity** Medium · **Effort** High · **Confidence** Medium
**Dimension** Nielsen #6 Recognition rather than recall, #7 Flexibility; Krug; Hick's Law
**Locations**
- app/views/collectibles/_search_form.html.erb:9-11 + _search_help.html.erb (the whole syntax)
- app/views/collections/_search_form.html.erb:5-7 + _search_help.html.erb

**Problem** The only filter mechanism is a single free-text box expecting a bespoke
query language (`is:completed system:switch`, `players:2..4`, `OR`, parentheses),
documented in a collapsed `<details>`. It forces recall of operators rather than
offering recognisable controls; first-time and non-technical users won't discover
`is:coop`. The placeholder ("Search e.g. is:completed system:switch zelda") leaks
jargon into its example. This raises the floor for everyone.
**Fix** Keep the advanced syntax, but surface the two or three most-used filters as
real controls (a type dropdown, a "completed only" checkbox, a "following" toggle)
that compose into the query — progressive disclosure.
**Verify** A cheap usability test: can a new user filter to "unfinished board games"
without opening help?
**Related** Theme T-UI-6.
**Status** open

### Low

#### UI-16 · Manifest ships placeholder red and a single icon size
**Severity** Low · **Effort** Small · **Confidence** High
**Dimension** Consistency/polish; PWA install UX (Nielsen #1/#4); `content.md`
**Locations**
- app/views/pwa/manifest.json.erb:19-21 (`"description": "Collection."`, `"theme_color": "red"`, `"background_color": "red"`) and :3-14 (only a 512×512 icon, listed twice)

**Problem** The install splash and OS chrome paint a jarring pure red unrelated to the
blue brand (`--brand: #3a52c6`); the description is a one-word stub; only a 512px icon
is declared (no 192px), so some launchers show a blurry/absent icon. The manifest is
static, so it can't reflect the user's theme.
**Fix** Set `theme_color`/`background_color` to real brand values (e.g. `#3a52c6` /
`#f6f7fb`); write a real description; add a 192×192 icon entry.
**Verify** Install as a PWA; splash colours and home-screen icon look right.
**Related** Theme T-UI-7.
**Status** open

#### UI-17 · "★ Following" glyph is announced by screen readers
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** WCAG 2.2 1.3.1 / 1.1.1; `visual-design.md` "don't rely on shape/colour"
**Locations**
- app/helpers/application_helper.rb:44 (`tags << "★ Following"`)

**Problem** The star is decorative but not hidden, so a screen reader may read "black
star Following" (or an emoji name). It adds nothing over the word "Following". (The
breadcrumb separator at collectibles/show.html.erb:6 is correctly `aria-hidden` —
credit.)
**Fix** Drop the "★" or wrap it in an `aria-hidden` span.
**Verify** A screen reader reads "Following" cleanly on a followed collection row.
**Related** Theme T-UI-3.
**Status** open

#### UI-18 · Three empty collection shelves on the new-user homepage
**Severity** Low · **Effort** Small · **Confidence** Medium
**Dimension** Nielsen #8 minimalist design; Krug "omit needless words"; GOV.UK "do less"
**Locations**
- app/views/root/index.html.erb:39-49 ("Collections you follow" and "Private collections shared with you" render even when empty, each with an empty-state sentence)

**Problem** A brand-new signed-in user with no follows and nothing shared sees two
headings each followed by "You're not following any collections yet." / "No private
collections have been shared with you." — near-empty sections competing for attention
on the primary landing page.
**Fix** Collapse the empty follow/shared sections (or merge into one "Discover
collections" prompt linking to All collections); keep "Recently updated" as the
always-present browse entry point.
**Verify** A new user's homepage leads with a clear next action, not three empty
shelves.
**Related** Theme T-UI-6.
**Status** open

#### UI-19 · Label colour `<select>` gives no swatch preview
**Severity** Low · **Effort** Small · **Confidence** Low
**Dimension** Nielsen #6 Recognition over recall; `forms.md`
**Locations**
- app/views/settings/labels/edit.html.erb:14-15 and index.html.erb:22-24 (`form.select :colour` over `Label::COLOURS` — names, not swatches)

**Problem** A user picking "Purple" from a text `<select>` can't see the resulting chip
until saving, and the rendered colour varies per theme (`--label-*`). A named-palette
select is itself a reasonable, accessible choice (credit) — the only gap is the missing
live preview. Low/low-confidence.
**Fix** Optionally render a small swatch beside each option, or a live chip preview.
**Verify** A user can anticipate the label's appearance before saving.
**Related** Theme T-UI-6.
**Status** open

#### UI-20 · "Search" and "Apply" buttons do the same thing
**Severity** Low · **Effort** Small · **Confidence** Low
**Dimension** Nielsen #4 Consistency; Krug self-evidence
**Locations**
- app/views/collectibles/_search_form.html.erb:12 ("Search"), :23 ("Apply"), :15 ("Clear"); collections/_search_form.html.erb:8, 20

**Problem** One `<form>` holds a search box + "Search" button and a sort select +
"Apply" button; because both submit the same form, either applies both query and
sort — so the two buttons are functionally identical, which is confusing, and a user
may not realise a sort change needs a button press.
**Fix** Use a single submit, or auto-submit the sort `<select>` on change (with a
no-JS fallback button), and label the remaining button plainly.
**Verify** A first-time user understands how to apply a sort without discarding their
search.
**Related** Theme T-UI-6; related to UI-15.
**Status** open

## Themes

### T-UI-1 · Global accessibility scaffolding is missing
**Members** UI-03, UI-04, UI-05. **Root** layout-level primitives — skip link, a house
focus indicator, live regions for status — were never added, so every page inherits
the gap at once. **Leverage** three small edits in the layout and CSS fix the whole app
simultaneously; highest leverage per line changed.

### T-UI-2 · Forms stop at "render the errors"
**Members** UI-02, UI-14. **Root** every form shows an error banner but none implement
the summary → focus → field-association → `aria-invalid` chain. **Leverage** one shared
error-summary partial (plus focus move) fixes collectible, settings, labels,
custom-sorts, import, 2FA, and — once owned — Devise forms together.

### T-UI-3 · Meaning encoded in styling/hover/title/state, not in text or semantics
**Members** UI-08, UI-09, UI-10, UI-11, UI-17. **Root** clickable-ness, toggle state,
new-tab behaviour, per-row identity, and a decorative glyph are conveyed by colour,
hover, `title`, or an unhidden symbol rather than an accessible name or a non-colour
cue. **Leverage** a consistent "accessible name + non-colour signifier" habit across
chips, toggles, and list controls closes a whole row of the subject grid; touch,
colour-blind, and screen-reader users each get back a different lost piece.

### T-UI-4 · Heading semantics drift from visual role
**Members** UI-06, UI-07. **Root** a shared partial's fixed level breaks ordering in one
host page, and settings pages repeat a generic `<h1>` while the real name lives in the
`<title>`/sub-nav. **Leverage** getting the outline right restores "navigate by
heading" and answers Krug's "where am I?".

### T-UI-5 · Plain-language and consistency gaps on the auth path
**Members** UI-12, UI-14. **Root** "OTP" jargon and unstyled/inconsistent auth pages sit
on the very first screens a user meets. **Leverage** small content + markup edits make
the highest-traffic, highest-stakes flow feel finished and legible.

### T-UI-6 · Power-user surface with no beginner ramp
**Members** UI-13, UI-15, UI-18, UI-19, UI-20. **Root** the app optimises for the expert
author — bespoke query syntax, mode-switching import, dual submit buttons, empty
shelves, name-only colour picker — so first use is a puzzle. **Leverage** progressive
disclosure (a few real filter controls, clearer import modes, a single submit) lowers
the floor without removing the power features.

### T-UI-7 · Placeholder/borrowed chrome
**Members** UI-16 (and UI-14's Devise defaults). **Root** the manifest stubs and the
un-owned Devise views are the unfinished edges of an otherwise carefully styled app.

## Subject grid

| Subject | Dimensions (finding IDs) | # | Severity | Interpretation |
|---------|--------------------------|---|----------|----------------|
| layouts/application.html.erb | UI-03 (bypass), UI-05 (live region), UI-04 (focus, via CSS) | 3 | Medium | The shared shell carries three distinct global gaps — scaffolding never added; fixing it lifts every page. Not an "overloaded partial" (each gap is independent), but the highest-leverage subject. |
| 2fa setup/session views | UI-01 (non-text), UI-12 (label/jargon), UI-14 (structure/errors) | 3 | High | The security-critical enrolment flow fails perceivability *and* plain-language *and* consistency at once — the flow, not just a control, is the fault. |
| collectibles/_form + settings/labels/custom_sorts forms | UI-02 (errors) | 1 | High | Same error-summary gap repeated; one partial dissolves it. |
| _collectible.html.erb | UI-06 (heading), UI-10 (chip affordance), UI-11 (new tab) | 3 | Medium | The card partial concentrates a heading-order fault and two "meaning-in-styling" faults — an overloaded shared partial rendered on multiple pages. |
| _follow_button.html.erb | UI-08 | 1 | Medium | State-named toggle |
| settings list rows (labels/sorting/visibility) | UI-09 | 1 | Medium | Repeated ambiguous control names |
| import.html.erb | UI-13, UI-15 (its search cousin), UI-18/UI-20 (sibling views) | — | Medium | Beginner-ramp cluster (theme T-UI-6) |
| pwa/manifest.json.erb | UI-16 | 1 | Low | Placeholder metadata |

Convergence rule: a subject at 3+ distinct dimensions gets its own finding at High or
higher. The **2FA setup/session** subject crosses it (UI-01, UI-12, UI-14) and is
already carried at High via UI-01 — the flow is the hotspot, and its severity is not
lowered. **`_collectible.html.erb`** and **layouts/application.html.erb** also reach 3
dimensions; each is held at Medium with evidence (the faults are independent
single-criterion A/AA issues with small fixes, not a task-blocking convergence), not a
cohesion impression — but both are named as the shared-partial/shell hotspots that
predict where the next issue will land.

## Leverage-ordered fix list

1. Add one shared accessible error-summary partial (role, focus move, field association, `aria-invalid`) and use it on every form → dissolves UI-02, lifts UI-14 (2). Effort Medium.
2. Add a manual secret key + `role="img"`/label to 2FA setup → dissolves UI-01 (1). Effort Medium.
3. Layout scaffolding pass: skip link + `<main id tabindex>`, a `:focus-visible` ring, `role=status`/`role=alert` on the flash regions → dissolves UI-03, UI-04, UI-05 (3). Effort Small.
4. Chip/control accessible-name pass: non-colour signifier on link chips, "(opens in new tab)", per-row hidden context, `aria-pressed`/action label on follow, drop the "★" → dissolves UI-08, UI-09, UI-10, UI-11, UI-17 (5). Effort Small.
5. Heading pass: demote the card title out of the heading flow; make settings `<h1>`s specific → dissolves UI-06, UI-07 (2). Effort Small.
6. Auth-content pass: "6-digit code" label + numeric inputmode; own + style the Devise/2FA views → dissolves UI-12, and completes UI-14 (2). Effort Medium.
7. Beginner-ramp pass: surface a few real filter controls, clarify import precedence, single submit, tidy empty homepage shelves → dissolves UI-13, UI-15, UI-18, UI-20 (4). Effort High.
8. Manifest polish: real brand colours, description, 192px icon → dissolves UI-16 (1). Effort Small.

## Credits

Each was computed or checked (falsified) before being written.

- **Colour contrast is genuinely well engineered — this is not where the problems are.**
  Both passes independently computed WebAIM-formula ratios from the CSS across all seven
  themes: light body 14.85:1, muted 5.99-6.42:1, brand links ~6.1-6.6:1, all nine label
  colours 5.13-8.20:1 (white on the darkened `--label-*`), dark 7.16-14.77:1,
  pastel_parlour 5.72-10.11:1, retro brand ~5.0:1; `--field-border` control edges
  ≥3:1 (1.4.11). The comment "all pairs WCAG-AA verified" holds. (Falsified: the
  decorative `--border` is only ~1.26:1 on surface — but it's a card/section edge, not a
  UI-component boundary or text, so 1.4.11 doesn't apply.)
- **Semantic form markup is mostly right.** Real `<label for>` associations everywhere;
  radio/checkbox groups consistently wrapped in `<fieldset>/<legend>` (collectible
  status/multiplayer/labels, visibility, sorting, import format/type, label
  type-checkboxes); `scope="row"` on the sort-composer `<th>`; visually-hidden (not
  placeholder-only) labels on the search boxes and share-link fields; per-cell labelled
  selects in the custom-sort composer. Verified by reading each cited line.
- **Landmarks, `lang`, and per-page titles are present.** One `<main>`, native
  `<header>`/`<nav>`, `<html lang="en">`, viewport meta, distinct `content_for :title`
  on nearly every page (the two 2FA pages are the exception → folded into UI-14).
- **Destructive actions are guarded.** Delete collectible and delete label both route
  through a GET `confirm_delete` page that names the item and says "can't be undone", with
  real Delete/Cancel controls, not colour-only (Nielsen #5, WCAG 3.3.4-spirit). Verified
  both confirm views.
- **Pagination is exemplary.** `<nav aria-label="Pagination">`, `aria-current="page"` on
  the current page, the gap marked, current page emphasised by weight+border not colour
  alone (1.4.1). Verified `application/_pagination.html.erb`.
- **`<details>/<summary>` for help disclosures** — native, keyboard-operable, no ARIA
  reinvention (accessible-code.md "first rule of ARIA").
- **External links carry `rel="noopener"`**; the breadcrumb separator is correctly
  `aria-hidden`. (The *new-tab warning* is still missing — UI-11.)
- **Type scale is all `rem`** (honours zoom, 1.4.4) and layout uses relative/flex/grid
  with a mobile breakpoint (1.4.10 reflow plausibly met — needs a live 320px/400% check).

## Coverage note

Every `.erb` template and partial in scope, the layout, `application.css` (contrast
computed per theme; `focus`/`skip`/`reduced-motion` greps run), both PWA files, all
controller flash strings, and the three helpers were read in full at `0a2078c` across
the two passes. High-stakes flows walked end to end: sign-in entry point, 2FA setup, 2FA
challenge, delete collectible/label, import → review → create, visibility/sharing.

Gaps needing a running app or design intent (out of scope for a static review): live
axe/screen-reader pass (UI-01/02/05 severities warrant confirmation); reflow at 400% /
320px and text-spacing (1.4.10/1.4.12 — the `.search-help__table` and `.sort-composer`
at `width:100%` are the likeliest pinch points); target size 2.5.8 (pagination pills and
`.button-as-link` inline buttons — check 24×24); the exact `<svg>` attributes
`RQRCode.as_svg` emits (UI-01 assumes no `<title>`, matching the gem default but not
confirmed against a live render); and the Devise default sign-in/up/reset views (UI-14 —
confirmed absent from the repo, so gem defaults are served, but not rendered/inspected
live). `prefers-reduced-motion`: no CSS animation exists, so nothing to gate — re-check
if motion is added.
