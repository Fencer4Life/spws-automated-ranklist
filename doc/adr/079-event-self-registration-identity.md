# ADR-079: Event Self-Registration & Identity Resolution

**Status:** Proposed (Phase 1 DB schema + Phase 2 public registration UI **implemented** 2026-07-05 — spec §5.2, RTM FR-120–FR-130; Phases 4/5 (email delivery) not started, blocked on Resend/eu.org). **Amended 2026-07-05 (§7):** registration URL auto-fill + in-app modal presentation.
**Date:** 2026-07-04
**Source:** Event Registration & Clean-Roster Seeding subsystem (spec §5.2); ADR-078, ADR-080

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
