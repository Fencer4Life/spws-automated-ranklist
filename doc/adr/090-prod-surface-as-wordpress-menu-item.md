# ADR-090: Publishing a PROD surface as a full-screen WordPress menu item

**Status:** Draft (proposed 2026-09-05; revised 2026-09-05 after live review; awaiting sign-off)
**Date:** 2026-09-05
**Amends:** [ADR-007](007-shadow-dom-deferred.md) (the anticipated WordPress embed is now built, and the element gains a `view`/`chrome` interface), [ADR-009](009-cert-prod-runtime-toggle.md) (GitHub Pages is no longer the only publication target, and the environment a surface opens on is now derived from the credentials it holds rather than fixed at `CERT`)
**Relates to:** [ADR-011](011-artifact-release-pipeline.md) (the bundle ships through the existing release pipeline), [ADR-083](083-server-enforced-authorization.md) (the exposure argument rests on the anon grants), [ADR-079](079-event-self-registration-identity.md) (self-registration becomes reachable from the association's own menu), [ADR-084](084-calendar-quarter-barrel-event-card.md) (the calendar is the first surface through the pattern), [ADR-085](085-points-calculator-temporary-static-page.md) (the calculator will reuse the presentation, not the build)
**Source:** `doc/plans/prod-deployment-wordpress-2026-09-05.html`

## Context

The SPWS ranking, calendar and points calculator are published on GitHub Pages
at `https://fencer4life.github.io/spws-automated-ranklist/`. That address is
not the association's website. Fencers reach `weteraniszermierki.pl`, whose
calendar page `/kalendarz-2/` is 25 KB of hand-typed event lines maintained by
hand, three seasons deep, while the generated calendar with live registration
sits on an address almost nobody knows.

ADR-007 anticipated exactly this: the component was built as a custom element
with Shadow DOM specifically so it could be embedded in a WordPress page. The
mechanism has existed since M8 and has never been used.

What was measured on 2026-09-05, against the live site and the live database,
rather than assumed:

- **The embed survives WordPress's save-time filter.** A draft page carrying
  `<spws-calendar>`, an external `<script type="module">`, an inline `<script>`,
  a `<style>` element and hyphenated custom attributes was written over XML-RPC
  and read back **byte-identical**. The administrator holds `unfiltered_html`,
  as the single-site install predicted. The planned `mu-plugins` fallback — and
  with it the dependency on a DirectAdmin login nobody holds — is not needed.
- **The render-time filter behaves differently from the save-time one.**
  `wpautop` is active: measured against three published pages, bare text and a
  top-level `<img>` are wrapped in `<p>`, while a top-level `<div>` passes
  through untouched. `spws-calendar` is not a tag `wpautop` recognises, so the
  embed is wrapped in a `<div>` to keep it out of a paragraph.
- **The theme prints its own `<h1 class="entry-title">`** above the content
  area on every page. The plan's "no page heading" cannot be achieved by
  omitting a heading from the content; it needs a rule that hides the theme's.
- **PROD's security posture is green now**, not as of the last deploy: all five
  ADR-083 assertions pass against `spws-ranklist-prod`.
- **PROD's calendar data is sound.** 120 rows across 4 seasons; `arr_weapons`
  fully populated; none of the three known CERT defect classes present. The 23
  undated `CREATED` rows in the current season are ADR-077 planning skeletons
  and are already hidden twice over — `calendarMonths.ts:258` drops events with
  no `dt_start`, and `visibleEvents` at `calendarMonths.ts:545` filters
  `enum_status !== 'CREATED'`.

Two defects in the existing code were found by the tests written for this work,
both invisible while the application only ever ran on GitHub Pages:

1. **A PROD-only embed rendered blank.** `activeEnv` was initialised to the
   literal `'CERT'`, and `supabaseUrl` derived as
   `activeEnv === 'PROD' && prodUrl ? prodUrl : certUrl`. Given only the PROD
   pair, that yields an empty string, the init effect's `supabaseUrl &&
   supabaseKey` guard never passes, and nothing loads — with no error anywhere.
   This is the mirror image of the 2026-08-17 `RegistrationElement` defect,
   where `(certUrl || prodUrl)` silently resolved to CERT: the same assumption
   that both credential pairs always exist, failing in the other direction.
2. **Opening directly on the calendar loaded the ranking.** `App.init()` ended
   in an unconditional `loadRanking()`. That was correct while `currentView`
   always started at `'ranklist'` and the calendar was only ever reached through
   `navigateTo()`, which loads it. An embed that opens on the calendar fetched
   ranking rows nobody sees and left the barrel with no events.

## Decision

Publish an SPWS PROD surface as a **full-screen-capable WordPress page reached
from a menu item**, with the bundle served from the existing GitHub Pages origin
at a stable file name. The subject of this decision is the **pattern**, not the
calendar: the ranking and the points calculator follow it without ADRs of their
own.

### 1 · The embed is the same application, not a second one

`<spws-calendar>` mounts `App.svelte` with `view="calendar" chrome="none"`
(`CalendarElement.svelte:9`), inheriting the client initialisation, the
all-seasons load and the locale store that already work. It was previously a
mock stub whose only prop was `demo` and which had never queried a database.

`App.svelte` gains two attributes, both defaulting to today's behaviour so the
GitHub Pages build is unchanged:

- `view` (`ranklist` | `calendar`), default `ranklist` — `App.svelte:379`
- `chrome` (`full` | `none`), default `full` — `App.svelte:380`

`chrome="none"` removes the header, the hamburger and the drawer: a single
embed has no second view to navigate to.

### 2 · A surface opens on the environment it holds credentials for

`activeEnv` is initialised as `certUrl && certKey ? 'CERT' : 'PROD'`
(`App.svelte:489`). With both pairs present the behaviour is exactly as ADR-009
specifies — the Pages app opens on CERT and shows the CT/PD toggle. With only
the PROD pair, the surface opens on PROD instead of resolving to an empty URL.

This amends ADR-009's reactivity chain. The `dualEnv` flag and the toggle's
meaning are unchanged.

### 3 · The embed ignores `?admin=1`

`adminRequested` is gated on `chrome !== 'none'` (`App.svelte:445`).
Administration stays on GitHub Pages; the sign-in modal is not reachable from a
public page on the association's site whatever the address bar says.

### 4 · Asset paths resolve through a base, not the origin root

The four organizer marks and the header mark are referenced by bare file name,
which resolves only because the Pages app sits at the origin root. A module-level
base (`lib/assetBase.ts`) is set once from an `asset-base` attribute and read by
`EventCard`, `Sidebar` and the embed bar. Empty by default, so Pages output is
byte-for-byte what it was.

It is a module singleton rather than a prop for the reason `initClient` is: the
value arrives once as a static attribute and is read three components deep.

### 5 · One row replaces the removed application header

At no extra height: the **SPWS mark linked to `https://weteraniszermierki.pl`**,
the page's name in the **active language only** (set large and bold — it is the
page's only heading, since §7 removes the theme's), and the language toggle.

There is **no fullscreen control**. One was built on the Fullscreen API, but §7
already gives the element the whole viewport with no theme chrome around it, so
the button had nothing left to add and read as a stray glyph beside the flags.

The mark is **required, not decorative**. Because §7 removes the theme's header,
navigation and footer from this page, the mark is the **only route back** to the
association's site from the calendar. It was briefly removed on 2026-09-05 and
that left the page a dead end; two tests now pin its presence and its href.

The drawer's mark in the Pages app does gain a link home (`Sidebar.svelte:8`),
which is that copy's only route back to the association's site. That is the
GitHub Pages build, not the embed, and it is unaffected.

### 6 · The bundle keeps a stable file name

`vite.config.ce.ts:30` pins `output.entryFileNames` so the CE entry publishes as
`assets/main.ce.js` rather than `main.ce-<hash>.js`. The WordPress page hard-codes
that URL, so WordPress is touched once and every later release reaches the live
page by replacing the file at the same address.

The trade-off is deliberate: no content hash means no cache-busting. It is
guarded rather than trusted — `release.yml:128` fails the release if the stable
file is missing or a hashed sibling appears, because a rename would not fail in
CI, it would fail silently on a live page on the association's website.

### 7 · The page is presented full-screen, with the theme removed

The page body holds a `<style>` block that hides the theme's chrome on this page
only — `header.header` (the site logo and the navigation), `section.page-image`,
`.entry-header`/`.entry-title`, the `#slideout` and `#facebook` side tabs, and
`footer.footer` — then zeroes the margins and padding of `#content.site-content`,
`#primary.content` and `.entry-content` so the calendar occupies the viewport.
Every selector was read off the rendered page rather than guessed. `<style>` was
verified to survive the content filter in the same round-trip as the embed.

This supersedes the plan's locked decision that the site's header and menu wrap
the embed. The user directed the change after seeing the page live: the surface
is a full-screen calendar, not a calendar inside a website page.

**Consequence:** with the theme's navigation gone, the SPWS mark in the embed row
(§5) is the only in-page route back to the rest of the site. That is why the mark
is mandatory rather than decorative, and why removing it is a regression the
tests now catch.

The page template is **not** the mechanism. `wp_page_template` cannot be set
reliably over XML-RPC — the value does not stick and reads back as `None`, the
same protected-meta limitation that blocks menu items (see Open items). The
`<style>` approach needs no template and works on the default one.

### 8 · Nothing is published without per-page approval

The page and its menu item are created as drafts and stay drafts until the user
approves that specific page. `/kalendarz-2/` and `/klasyfikacja/` are not
modified; the old and new calendars can run side by side for as long as the
association wants.

## Alternatives considered

1. **An `<iframe>` pointing at the Pages site.** Rejected: no style or height
   negotiation with the host page, poor behaviour at phone width — the binding
   constraint for every one of these surfaces — and no shadow-DOM isolation
   guarantee to inherit. The custom element already exists and ADR-007 built it
   for this.
2. **Rebuilding the calendar as a WordPress plugin or theme template.** Rejected:
   duplicates the ranking engine's read model in PHP, and puts a second
   implementation of the domain on a host nobody in this project controls.
3. **A hashed bundle name with the WordPress page updated per release.**
   Rejected: it makes every release a two-system change, and the failure mode is
   a live page silently loading a 404 until someone notices.
4. **Publishing to a page template that drops the theme chrome**
   (`Redux pełna szerokość`, `Redux płótno`). Rejected on evidence, not taste:
   `wp_page_template` set through `wp.editPost` does not take effect — it reads
   back as `None` and the rendered page is byte-identical — so the template
   cannot be selected through the only channel available here. A `<style>` block
   achieves the result on the default template with no such dependency.
5. **Moving PROD off GitHub Pages entirely.** Out of scope. This is the first
   step of PROD leaving Pages, not the completion of it; the Pages origin still
   serves the bundle and the assets.
6. **Blanking the CERT attributes and passing PROD in the CERT slots**, as
   `register.html` does. Rejected: it makes the page lie about which environment
   it talks to. Fixing the resolution (§2) is a smaller change than a permanent
   misnaming, and it removes a defect class rather than working around it.

## Consequences

**New files**

- `frontend/src/lib/assetBase.ts` — the asset base singleton.
- `frontend/tests/assetBase.test.ts` — 6 tests.
- `frontend/tests/CalendarEmbed.test.ts` — 23 tests covering credential
  resolution, `chrome="none"`, view routing, the top row and the element itself.

**Changed**

- `frontend/src/App.svelte` — `view`, `chrome`, `asset-base`; the embed bar
  (mark linked home, name, language toggle, fullscreen); the `activeEnv` and
  `init()` fixes.
- `frontend/src/ce/CalendarElement.svelte` — mock stub replaced by a mount of
  the real application; `:host` gives the element its viewport height.
- `frontend/src/components/EventCard.svelte`, `Sidebar.svelte` — assets through
  `assetUrl`; the drawer's link home.
- `frontend/src/lib/locales/{pl,en}.json` — 2 embed-only keys each (550 each,
  parity held).
- `frontend/vite.config.ce.ts` — stable entry name.
- `.github/workflows/release.yml` — the stable-name guard.

**Test impact.** 768 vitest tests pass (up from 738); `svelte-check` reports 0
errors. No test was deleted or weakened. Both defects in Context were caught by
a failing test written first, and the `init()` fix was verified by reverting it
and confirming the test fails.

**The registration form becomes materially more reachable.** Nothing about its
privilege changes — anon still holds no table write, and registrations go
through `SECURITY DEFINER` RPCs — but ADR-079 §4's defence (d), the rate limit
and salted-hash abuse log, still does not exist. Moving the form from an obscure
Pages URL into the association's main menu changes how many people walk past an
unthrottled public form. The exposure is accepted for now and the follow-up is
scheduled for 2026-09-06 alongside the XML export work.

**Cache behaviour changes for the CE bundle.** A stable name means browsers key
on the file name; a release replaces the file in place.

**Found and deliberately not fixed.** `scripts/cloud-sql.sh:96` strips SQL
comments with `sed -E 's@--[^\n]*@ @g'`. `sed` has no `\n` escape inside a
bracket expression, so `[^\n]` means "not a backslash and not the letter n": any
leading comment containing an `n` truncates the strip and a plain `SELECT` is
routed to the write-confirmation gate. It fails safe and is outside this
decision's scope.

## Open items

1. **The theme heading.** §7 hides it with a `<style>` rule on the default
   template. If the `Redux pełna szerokość` template turns out to omit the
   heading and widen the content area, it is a one-attribute change on the same
   page — but it is unmeasured until something uses it. *Recommendation:* ship
   on the default template, measure the alternative later if the width is
   wanted.
2. **The menu item.** Not created. WordPress stores a menu item's structure in
   protected `_menu_item_*` meta, which XML-RPC accepts on write but hides on
   read, so a menu item cannot be verified through the channel that creates it.
   *Recommendation:* create it in `wp-admin`, where it can be seen, or accept an
   unverified draft item on explicit instruction. The live menu is `nav_menu`
   term 33 ("Moje menu"); the LINKI parent is item 7128.
3. **Step 2's placement and timing** — the ranking and the calculator — depend
   on an SPWS Board decision expected in the week of 2026-09-08, and the
   calculator additionally on a DirectAdmin/FTP login not yet held. Neither
   blocks this decision.
