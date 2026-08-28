# ADR-079: Event Self-Registration & Identity Resolution

**Status:** Proposed (Phase 1 DB schema + Phase 2 public registration UI **implemented** 2026-07-05 — spec §5.2, RTM FR-120–FR-130; Phases 4/5 (magic-link email) still not started, blocked on Resend/eu.org, but **no longer blocking registration** — see the 2026-08-17 amendment). **Amended 2026-07-05 (§7):** registration URL auto-fill + in-app modal presentation. **Amended 2026-08-17:** unmatched fencers register with `id_fencer` NULL; `register.html` is PROD-only.
**Date:** 2026-07-04
**Source:** Event Registration & Clean-Roster Seeding subsystem (spec §5.2); ADR-078, ADR-080
**Amended by:** [ADR-084](084-calendar-quarter-barrel-event-card.md) §7 (decouples the entry-list gate from the registration cutoff).

## Amendment (2026-08-17 — the unmatched fencer registers; register.html is PROD-only)

Two corrections, made while opening PPW1-2026-2027 for entry. §§1, 3, 5 (read-only
invariant, BY reconciliation matrix, schema) are untouched; §2's *gating* changes and
§7(c)'s credential injection was **wrong in a way that silently misrouted every entry**.

### (a) A non-exact match no longer requires email — it registers

§2's Model B table routes Paths B/C/D through "one magic-link click". Phases 4/5 never
shipped, so the form did the only other thing it could: it rendered a *"email verification
is coming soon — please contact the organizer"* panel and **wrote nothing at all**. Every
newcomer, and everyone whose stored birth year was an ingestion estimate rather than a
confirmed value, was refused outright.

That inverts the ADR's own purpose. §Context justifies this subsystem by the birth years it
would collect; the population whose BY we most need is precisely the population the form
turned away.

**A miss now continues to RODO and is written with `id_fencer` NULL.** No email, no gate.

The security argument is §4's own: email *"proves inbox control, not identity — it is
friction + accountability, never load-bearing for integrity."* Removing it therefore costs
nothing the ADR ever claimed for it. The four real defences are all intact — (a) the
read-only invariant, (b) the confirmed-BY-sacrosanct rule, (c) the organizer's venue check,
(d) the results-based ranking, under which a fake entry that never fences scores nothing.
The worst case is unchanged from §1: a junk, ephemeral, deletable `tbl_registration` row.

Nothing downstream needed changing, which is the strongest evidence the design anticipated
this:

- `fn_create_registration` already takes `p_id_fencer INT DEFAULT NULL` and inserts it.
- `vw_registration_entry_list` joins `tbl_event` and `tbl_season` — **not** `tbl_fencer` — so
  an unmatched registrant appears on the public roster with a derived age category.
- `python/pipeline/ftl_seed_export.py` already declares `id_fencer: int | None` and
  interleaves unranked registrants by `ts_created`.

So the declaration reaches both the roster and the organizer's seed file without
`tbl_fencer` ever being written. The real fencer row is still created at ingestion (§3),
where the declared BY feeds the existing reconciliation machinery unchanged.

Verified end to end against PROD before the link was shared: a fencer absent from
`tbl_fencer` completed the flow, `SELECT count(*) FROM tbl_fencer` for that surname returned
**0**, and the row surfaced on `vw_registration_entry_list` with a server-derived `V1`.

The `reg_verify_*` locale keys are retained, not deleted — Phases 4/5 will reuse them when
magic-link delivery ships. Email then becomes an *optional* strengthening of an entry that
already exists, rather than a precondition for making one.

### (b) `register.html` receives PROD credentials only

§7(c) settled that `register.html` is a CE-bundle artefact whose credentials are injected by
`release.yml`. It did not say **which** credentials, and the workflow injected all four
attributes — both the CERT and the PROD pair.

`RegistrationElement.svelte` resolves its client as `(supabaseCertUrl || supabaseProdUrl)`.
A populated CERT pair therefore always won, and **every registration made through the public
link would have been written to CERT** while the page looked entirely healthy to the fencer.
The component's own comment asserted that "build-time sed picks one pair per deploy target";
no such per-target selection existed.

`release.yml` now blanks `supabase-cert-*` for `register.html` and injects the PROD pair
only. `index.html` keeps both — it exposes a runtime admin environment toggle; this page has
none by design (§6), so it gets exactly one environment. Blanking rather than omitting is
required: the build's *"no localhost in dist"* guard would otherwise fail on the committed
LOCAL defaults.

This defect is invisible to tests and to inspection of the rendered page. It was caught only
by registering once against the deployed URL and then querying **both** databases.

### (c) Smaller corrections shipped in the same change

- **Gender no longer defaults to `M`.** A woman who never touched the select was silently
  recorded male — into her sub-ranking category, the public entry list and the FTL seed. It
  is now a declared value, required before Continue.
- **Write failures surface.** `fn_create_registration` RAISEs once the D10 window guard
  trips; the rejected promise previously left the fencer pressing a button that did nothing.
- **One Back step from RODO**, so a mistyped birth year can be corrected without re-entering
  the form.
- **A soft already-registered warning**, read from `vw_registration_entry_list` before the
  write. It is a warning, not a constraint — see Open items.
- **Payment details are real.** The IBAN was empty on both surfaces (no workflow ever filled
  `register.html`'s `iban=""`, and `CalendarView` passes no payment props at all), and three
  separate `'SPWS'` defaults overrode the full registered account name a transfer is matched
  against. Both now come from `frontend/src/lib/orgPayment.ts`, where an empty prop means
  "use the association details". The transfer note follows the association's stated
  convention — first name, surname, weapon, age category — with the event code retained,
  since several rounds share one account.
- **The payment deadline is quoted, not described.** It reads
  `COALESCE(dt_registration_deadline, dt_start)` — the same expression the D10 guard
  enforces — instead of the previous hand-written "12 hours before the event starts", which
  corresponded to no rule in the system.

### Open items

1. **`UNIQUE(id_event, id_fencer)` does not constrain unmatched rows.** Postgres treats NULLs
   as distinct, so the hole described in §5 is now *reachable* for the first time — before
   this amendment nothing could write a NULL-fencer row. A fencer who registers twice creates
   two rows and appears twice on the roster and in the seed file. **Recommendation:** a
   partial unique index on
   `(id_event, txt_surname, txt_first_name, int_birth_year) WHERE id_fencer IS NULL`, plus a
   branch in `fn_create_registration` — a single `INSERT` cannot carry two `ON CONFLICT`
   arbiters. Not yet decided.
2. **Club is collected and discarded.** There is no `txt_club` column, and
   `ftl_seed_export.py` hardcodes `"Club": ""`. The user has asked for it to reach the seed
   file. Note this **inverts the current consent text**, which states *"Klub — tylko do plików
   startowych · nie zapisujemy"*; storing it is a genuine `CONSENT_VERSION` bump to `v1.1`,
   not a silent string edit. Not yet decided.
3. **Whether registration should be accepted after the advertised deadline.** Raised as a
   revenue question and explicitly deferred by the user on 2026-08-17. The D10 guard is
   enforced in the database, so this is not a copy change. **Recommendation:** gate the guard
   on `dt_start` rather than the deadline, leaving `dt_registration_deadline` as the
   advertised date — the same decoupling [ADR-084](084-calendar-quarter-barrel-event-card.md)
   applied to the entry list. Not yet decided.

### Corpus audit

- [ADR-078](078-gdpr-data-handling.md) — **relates, unchanged.** Its processing table still
  lists the salted email hash with a lawful basis; that column simply stays NULL until
  Phases 4/5. No data is now collected that the table does not cover. (Its "payment reference
  + paid/unpaid status" row remains inconsistent with §4, which states payment is not tracked
  digitally — a pre-existing discrepancy, flagged, not fixed here.)
- [ADR-080](080-clean-roster-ftl-seeding.md) — **relates, strengthened.** Its population rule
  is "every row of `tbl_registration`". Unmatched fencers now produce rows, so the seed
  covers entrants it previously could not have seen.
- [ADR-083](083-server-enforced-authorization.md) — **relates, one factual drift.** It states
  that `fn_create_registration` and `fn_match_registration_fencer` are "the entire server
  surface" of this flow. The form now also reads `vw_registration_entry_list` for the
  duplicate warning. No new grant was needed — that view already grants SELECT to `anon` for
  the public roster — but the sentence is no longer exhaustive.
- [ADR-016](016-supabase-auth-totp-mfa.md) — **clean.** Its email-confirmation setting governs
  admin accounts, not registration.

## Amendment (2026-08-09 — the entry list outlives the registration window)

§7 gated the entry-list link on the same cutoff as the registration link, so both vanished together once the deadline passed. [ADR-084](084-calendar-quarter-barrel-event-card.md) **decouples them**: registration closes at `COALESCE(dt_registration_deadline, dt_start)`, but the entry list stays visible until the event **starts** (CQ.31, CQ.32, EC.22), and is never shown on a cancelled event (CQ.33).

This is the point at which people most want to see who is entered — after entries close and before the event runs.

**No existing test pinned the old coupling**, which is why the change cost new tests rather than rewrites: every test touching `.entry-list-link` set a deadline *equal to* `dt_start`, so both readings agreed. The uncomfortable half is why it was cheap — the coupling was never covered, so nothing would have caught it drifting either way.

The in-app modal presentation from the 2026-07-05 amendment is unchanged; the links moved from the timeline row to `EventCard`, which emits `onopenregistration`/`onopenentrylist` for the orchestrator to act on (EC.24, CV.12–CV.14).

## Context

Automation is stuck near 90 % because birth-year (BY) data in `tbl_fencer` is
unreliable — worst case, two different people share an identical name with
different BY. BY today flows *backwards* (scrape → fuzzy match → BY **estimated**
from the tournament's age band, `bool_birth_year_estimated=TRUE`; ADR-056). If
fencers **self-declare** identity + BY *before* the event, that BY becomes an
authoritative signal and discrepancies drop toward zero for registered fencers.

The challenge: prevent duplicate/conflicting entries and corruption of the fencer
table by mistaken or malicious registrations, while keeping the flow usable for
elderly veterans (who forget emails) and minimising stored personal data
(ADR-078).

## Decision

### 1. Core invariant — registration is READ-ONLY on `tbl_fencer`

The registration subsystem **reads** `tbl_fencer` (to match, derive category,
route the flow) and **writes only** `tbl_registration` (ephemeral) + generates the
FTL seed. It **never** writes `tbl_fencer`, results, or the ranking. Those are
mutated only by (a) the event-ingestion pipeline and (b) explicit admin actions
(merges, manual edits, GDPR erasure) — unchanged from today.

Declared BY/identity rides on the registration record as a **high-quality signal**;
ingestion name-matches the seeded exact name → pulls the declared BY → feeds the
**existing** reconciliation machinery (`stages.py`, `fuzzy_match.py`, the PENDING /
IdentityManager flow), which does the authoritative write and marks the BY
*confirmed*. New fencers are **not** created at sign-up — a fencer enters
`tbl_fencer` only when results ingest (today's behaviour), now enriched with a
declared BY instead of a guess.

**Security consequence (by construction):** a malicious registration can at most
create a junk, ephemeral, deletable `tbl_registration` row — it cannot mutate an
identity or a ranking, because that code path does not exist in the registration
flow.

### 2. Identity model — Model B (email as one-time verification, not an account)

> **Superseded in part by the 2026-08-17 amendment (a).** The Path B/C/D *gating* below —
> "every other path takes one magic-link click" — no longer holds: a non-exact match is
> accepted and written with `id_fencer` NULL, with no email step. The rest of this section
> (Model B's rationale, the no-persistent-account property, the exact-triple fast path, and
> the dedup note) stands unchanged.

The form collects **Surname, Name, Gender, BY**, normalises (case/diacritics/
spacing), and matches via `find_best_match`. One gate rule: **skip email only on an
exact `(Surname, Name, BY)` triple match; every other path takes one magic-link
click.** Email proves **inbox control, not identity** — it is friction +
accountability, never load-bearing for integrity. There is **no persistent
account**: a veteran who lost an old email just verifies whatever inbox they have
now; admin intervention shrinks to true edge cases (formal erasure, disputes).

| Path | Match result | Email? | Outcome |
|---|---|---|---|
| A | exact name **and** BY equal | No | anonymous fast-path → weapon → category → RODO → payment |
| B | strong name (≥95), BY differs | Yes | verify → reconciliation (below), record on registration |
| C | weak name (50–94) | Yes | verify → "is this you?" + admin review |
| D | no match | Yes | verify → new registration (declared BY carried to ingestion) |

Dedup on the anonymous path is enforced by `UNIQUE(id_event, id_fencer)` upsert. A
fencer correcting our BY types a different year → the triple no longer matches →
auto-routed into the verified path.

#### Implementation note — form-side routing is exact-only; no Python bridge (2026-07-05)

The four-path table above is a **conceptual** identity model. In implementation it
resolves to a **binary** form-side decision, because the step-2 mockup (the build
SSOT) deliberately collapses Paths B/C/D into a **single** "we couldn't match you
exactly — confirm by one-time email link" screen that shows **no** fuzzy candidate
and explicitly states *"final identity matching happens when the organizer loads
results."*

Consequently:

- The **public form** performs **only** the exact `(surname, first, BY)` triple
  lookup — `fn_match_registration_fencer` (SQL RPC, `anon`-callable). Exact hit →
  Path A (skip email); **any** miss (unknown, near-miss typo, or right-name/wrong-BY)
  → the email-verify path. It does **no** fuzzy matching. (Pinned by pgTAP 49.22.)
- The **fuzzy** distinctions among B/C/D (`find_best_match`, RapidFuzz) are an
  **ingestion-time reconciliation** concern (§3), realised by the **existing**
  Python matcher that already runs when results are scraped — never invoked
  synchronously from the browser.

This **closes the "invocation gap"** flagged during Phase 1 (there is no mechanism
for the public frontend to call Python's `find_best_match`) **by construction**:
there is nothing the frontend needs to invoke in Python. A synchronous
Python-from-browser bridge (a hosted Python request/response service, or a SQL
`pg_trgm` re-implementation of the matcher) was considered and **rejected** — it
would add always-on infrastructure (violating the serverless, zero-dollar
architecture) or a second divergent matcher, to serve a UX flow that intentionally
does not use a form-side fuzzy result. Path A — the only integrity-sensitive,
no-email fast path — is exact equality, so no fuzzy logic is security-load-bearing
at the form regardless.

### 3. BY reconciliation matrix (runs at INGESTION, not the form)

The declared BY is reconciled against the stored BY by the ingestion pipeline. A
**confirmed** BY is **sacrosanct** — self-service never overwrites it:

| Stored BY | Declared − stored | Interpretation | Action |
|---|---|---|---|
| Estimated | any | our guess; declaration wins | overwrite ← declared, mark confirmed |
| Confirmed | any discrepancy | may be a namesake / bad edit | **quarantine → admin review; real row untouched** |
| — (multiple same-name) | — | self-declared BY selects the twin | link closest; none in band → new |

Two genuinely different people with the **same name + same BY** is the residual
hard case — disambiguated only by email, club, or optional full DOB.

### 4. Impersonation hardening

Email verification does **not** stop a foul player entering a victim's name. The
system does **not** track payment completion digitally — it only displays
bank-transfer instructions so the fencer can pay correctly; there is no
"paid" gate on the seed or entry list (corrected 2026-07-04 — an earlier draft
of this ADR proposed one, which wrongly assumed digital payment tracking this
system does not do). The real defences: (a) the read-only invariant +
confirmed-BY-sacrosanct rule → no data corruption; (b) **venue-level check** —
the organizer verifies payment (and can challenge an unfamiliar face) in person
at check-in, before the competition starts — a physical control, not enforced
in software; (c) the ranking is **results-based**, so a fake entry that never
fences has zero ranking effect, and the victim can spot the bogus entry via
"Sprawdź zgłoszenie" for admin removal; (d) the salted-hash abuse log + rate
limit. This is the same residual exposure every open amateur registration
carries (competit.pl included) — minimised, detectable, reversible, not
eliminated.

### 5. Schema (Phase 1)

- New `tbl_registration` (EPHEMERAL, RLS-gated — **rows, not a JSON file**: public
  concurrent writes need ACID; a file has no locking, no host with Supabase Storage
  disabled, no access control, and is a GDPR hazard if committed): `id_event`,
  `id_fencer` (nullable match), declared surname/first/gender/BY, weapons,
  `txt_ftl_name`, `ts_consent`, `txt_consent_version`, salted email hash,
  `ts_created`. **No payment-status column** — payment completion is not
  tracked digitally (corrected 2026-07-04; see §4). Optional own `reg` schema.
- `tbl_event` additions: `url_entry_list`, `txt_organizer_email`, `ts_ftl_sent`,
  `num_entry_fee_2w`, `num_entry_fee_3w`, `bool_use_spws_registration`
  (`url_registration` + `dt_registration_deadline` already exist, ADR-030).
- RLS: registration insert only via a controlled RPC; a public read-only entry-list
  view (name · gender · category · weapons — **no BY, no club**); writes REVOKEd
  from `anon`.

### 6. UI

Public Svelte route + custom element `<spws-registration event="…">` (mirrors
`<spws-ranklist>`/`<spws-calendar>`), reachable from the calendar's
`url_registration`, plus a public `url_entry_list` "Lista zgłoszonych". Bilingual
PL/EN. Mockups: `doc/mockups/registration_step{1,2,3}_*.html`,
`registration_rodo_consent.html`, `registration_entry_list.html`.

### 7. Amendment (2026-07-05) — registration URL auto-fill + in-app modal presentation

Two follow-on gaps surfaced once §6's UI was live: the calendar never actually
rendered a registration link (nothing fed it a base URL), and the flow that
was reached always navigated the fencer away from the calendar. Both are fixed
here; neither changes §1–§5 (read-only invariant, Model B, BY matrix,
impersonation defence, schema are all unchanged).

**a) Self-contained URLs, admin-triggered (a deliberate, scoped exception to
[[feedback_urls_admin_managed]]).** `CalendarView.svelte` gated the SPWS links
on `bool_use_spws_registration && registrationBase !== ''`, but no entry point
(`App.svelte`, `index.ce.html`) ever supplied `registrationBase` — so the
generated link never rendered, and PPW1-2026-2027 (flag on, no
`url_registration`) showed nothing. Rather than thread a deployment-time
`registration-base` attribute through every embed (LOCAL, GH Pages, a future
WordPress iframe), **`url_registration` and `url_entry_list` are computed
client-side and persisted** the moment the admin ticks
`bool_use_spws_registration` in `EventManager.svelte`:
`new URL('register.html', window.location.href).href` + `?event=<txt_code>`
(+`&view=list`). Unticking clears both. This makes a calendar embedded on a
foreign origin self-sufficient — the stored URL, not the embedding page,
determines where registration lives. `fn_update_event` gains
`p_url_entry_list TEXT` (migration `20260705000004`, DIRECT assignment — value
sets, `NULL` clears — matching how `p_registration` already treats
`url_registration`, **not** the "NULL = unchanged" convention the function's
other trailing params use, since the two registration URLs are always sent
together by the form). `CalendarView` now renders both links straight from the
stored columns; the old `registrationBase`/`useSpwsReg` prop plumbing is
removed entirely (dead once the URLs are self-contained).

**b) In-app modal instead of navigation.** Once the links worked, clicking one
still took the fencer off the calendar to the standalone `register.html` page
— jarring, and it lost the calendar's context. `RegistrationForm.svelte` and
`EntryList.svelte` gain optional `onclose`/`onviewlist` callback props
(undefined on the standalone page — nothing to close to there); a new
`RegistrationModal.svelte` wraps them in the same backdrop-click-to-close
overlay pattern already used by `DrilldownModal`, full-bleed on ≤600px
viewports. `CalendarView` opens this modal on left-click for
`bool_use_spws_registration=true` events (`e.preventDefault()`); the `href` is
left on the anchor unchanged, so right-click "copy link" / open-in-new-tab
still resolve to the real standalone URL. Links to a plain hand-entered
`url_registration` (flag off) are untouched — plain `<a>` navigation, no modal,
by construction (only SPWS-hosted events get an `onclick` handler at all).

**c) `register.html` stays a CE-bundle artefact (a correction, not a
sequel).** The reachable-fix for (a)+(b) first tried moving `register.html`
into the **main** Vite build (`vite.config.ts`) so a single `dist/` covered
everything `release.yml` deploys. That produced completely unstyled
("bare-HTML") `<spws-registration>`/`<spws-entry-list>` output: Svelte only
inlines a nested (non-custom-element) child component's `<style>` into a
shadow root when the **whole** compile graph runs under
`customElement: true`; under the main build's plain config those styles land
in the document `<head>` instead, invisible inside the CE's shadow DOM. Fix:
`register.html` reverts to being an input of `vite.config.ce.ts` (as it always
was) alongside `index.ce.html`, and `release.yml` gains a second build step —
`vite build --config vite.config.ce.ts` — whose `dist-ce/register.html` +
`dist-ce/assets/` are copied into the already-built `dist/` so Pages still
ships one merged output (closing the original "never deployed" gap without
re-splitting the artefact). Credential `sed` now targets `register.html`
directly (shared source, injected once, read by both build configs).
`register.html` also gained an inline page-shell `<style>` (dark background +
padding matching `doc/mockups/registration_*.html`) — without it the
CE-shadow-scoped card floated on the surrounding page's default white
background.

pgTAP 652→654 (8.24 `fn_update_event` URL auto-fill + prior 12.14 EVF
null-date fix, same day); vitest 449→463 (`RegistrationModal.test.ts` new,
`CalendarView`/`RegistrationForm`/`EntryList`/`EventManager` tests extended);
`svelte-check` 0 errors throughout.

**d) The same unstyled-render bug also hit LOCAL `npm run dev` (found after
push, user report).** (c) fixed the deployed/production path — CERT and PROD
both verified rendering correctly — but the *local dev server* is a separate
code path: `npm run dev` runs plain `vite`, which reads **`vite.config.ts`**
(the main config), not `vite.config.ce.ts`. `vite.config.ts` never set
`compilerOptions.customElement: true`, so visiting `register.html` directly
on the dev server (e.g. `http://localhost:5173/register.html?event=...` — the
exact URL an admin copies out of the calendar link to paste into Facebook/a
share) hit the identical shadow-DOM-styling gap as (c), just on a different
build path that (c) never touched. The in-app modal never showed this because
it renders `RegistrationForm`/`EntryList` as ordinary imported components
(normal Vite dev CSS injection), never through the `<spws-registration>`
custom-element boundary — so a working calendar modal gave no signal that the
standalone URL was broken. Fix: add `compilerOptions.customElement: true` to
`vite.config.ts` too. Verified safe — `App.svelte`/`main.ts` (the main app)
never declare `<svelte:options customElement>`, so only the four `ce/*.svelte`
wrapper files (which already declare it) are affected; the flag has no effect
on components that don't opt in. Confirmed empirically: `register.html` on
the plain `npm run dev` server now renders identically to the in-app modal;
the main ranklist/calendar app is unaffected (screenshots, console clean
apart from a pre-existing unrelated stale-auth-token log). vitest still
463/463, `svelte-check` 0 errors, main `vite build` unaffected (still emits
only `dist/index.html` — the CE-bundle-merge path in `release.yml` from (c)
is untouched, since that path was already verified working on CERT/PROD).

## Consequences

- No new form-side write path to `tbl_fencer`; reconciliation reuses existing
  ingestion code (declared BY replaces estimation).
- Elderly-friendly: most veterans use the frictionless anonymous path; email only
  on non-exact match, never a recoverable account.
- Birth year exposed in the ranking drilldown remains lawful (ADR-078 §3, Art. 13
  transparency + legitimate interest — purpose: category verification).
- (§7) `url_registration`/`url_entry_list` are the one admin-managed-URL
  exception in the codebase: auto-derived, not hand-typed, whenever
  `bool_use_spws_registration` is on. Every other event URL keeps the
  hand-entered convention.

## References

- ADR-078 (GDPR), ADR-080 (seeding), ADR-056 (BY reconciliation), ADR-016 (admin
  auth), ADR-030 (registration URL + deadline), ADR-034/064 (gender at matcher),
  ADR-050/070–074 (ingestion pipeline).
