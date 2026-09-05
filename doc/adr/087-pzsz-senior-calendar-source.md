# ADR-087: PZSz as a fourth event source — Polish national senior events on the calendar

**Status:** Accepted (proposed 2026-09-03, accepted 2026-09-04). Implemented and released to CERT and PROD.
**Date:** 2026-09-03
**Amends:** [ADR-084](084-calendar-quarter-barrel-event-card.md) §F and §11 (`registryOf()` widens from three registries to four; a fourth hue enters the organizer channel; `PanelType` gains a fifth member)
**Relates to:** [ADR-046](046-pew-weapon-suffix.md) (the event-code shape this extends with a gender letter), [ADR-081](081-cert-prod-event-reconciler.md) (childless CREATE, field ownership, code-keyed reconcile), [ADR-028](028-evf-calendar-results-import.md) (the calendar-source precedent this deliberately does not generalise), [ADR-086](086-evf-weapon-evidence-ladder-strict-skip.md) (the partially-published-season lesson applied before it bit), [ADR-083](083-server-enforced-authorization.md) (grants are table-level, so the new column needs none)
**Source:** `doc/plans/pzsz-kalendarz-seniorski-2026-09-03.html`, `supabase/migrations/20260903000001_pzsz_organizer_and_event_id.sql`, `python/scrapers/pzsz_calendar.py`, `python/scrapers/pzsz_sync.py`
**Amended by:** [ADR-088](088-calendar-location-contract.md) (PZSz adopts the shared location contract and gains venue-title extraction from the komunikat's `Miejsce Zawodów` line, which §7 here read past and discarded; the city path is unchanged in output).

## Context

Polish veterans also enter senior national competitions, fencing the same pools as
people half their age. The calendar carried SPWS (PPW/MPW), EVF (PEW) and FIE
(MEW/MSW/PSW) events and nothing at all from Polski Związek Szermierczy, the national
federation — so a veteran planning to test themselves at a senior national competition
had to look somewhere else entirely.

The goal is to encourage veterans into harder fields. That splits into two deliverables
and this ADR records the first only: **PZSz as a fourth organizer, its senior calendar
scraped, its events shown in their own hue.** Ingesting and scoring veteran results from
those events is deliberately deferred — see §7.

### The source, measured

`pzszerm.pl/zawody/kalendarium-zawodow/` is WordPress, server-rendered, no JavaScript.
Rows are `td.tab-row` cells: name (linked to `…/zawody/?id=NNNN`), age category, weapons,
season, start date, end date, location, attachments. Detail pages additionally carry a
full weapon × gender tournament breakdown, so nothing like `evf_calendar.py`'s
invitation-PDF weapon archaeology is needed.

Six PPS events were verified live on 3 September 2026 — two rounds, three weapons. A PPS
round is three separate competitions in three cities, unlike PPW where a round is one
weekend in one hall.

| PZSz id | Round | Weapon | City | Dates | Code |
| --- | --- | --- | --- | --- | --- |
| 4588 | I | sabre | Poznań | 03.10.2026 | `PPS1s-2026-2027` |
| 4581 | I | foil | Gdańsk | 24–25.10.2026 | `PPS1f-2026-2027` |
| 4596 | I | épée | Szczecin | 24–25.10.2026 | `PPS1e-2026-2027` |
| 4591 | II | sabre | Konin | 21.11.2026 | `PPS2s-2026-2027` |
| 4599 | II | épée | Warszawa | 21–22.11.2026 | `PPS2e-2026-2027` |
| 4585 | II | foil | Wrocław | 05–06.12.2026 | `PPS2f-2026-2027` |

MPS is unannounced rather than missed: the name-only MPS query returns 10 rows spanning
2021–2026, the newest being last season's. Rounds III and IV are likewise unpublished. A
partially-published season is therefore normal, and later rounds are picked up on
subsequent runs — this is the ADR-086 lesson applied before it bites, where an unannounced
EVF stub fail-closed a whole season scrape for nine days from 19 August 2026.

### The finding that shapes the whole scraper

**The listing caps at 70 rows, with no pagination, no error and no outward sign — and
different filters return entirely different 70-row windows.**

| Query | Rows | Verdict |
| --- | --- | --- |
| no filter | 70 | capped; descending, earliest 14.11.2026 — Sept/Oct 2026 invisible |
| `Kategorie_wiekowe = Seniorzy (S)` | 70 | capped |
| `Nazwa = Puchar Polski senior` | 70 | capped |
| `SezonAutocomplete = 2026/2027` | 70 | capped |
| `Nazwa` + `SezonAutocomplete` | 6 | complete |

Reading the obvious default view would have silently lost all three round I events. The
cap truncates from the bottom of a descending render, and its earliest row is 14.11.2026.

### Source data quality

Live rows carry an end date of **11.05.0251** (id 4307), the typo **mężćzyzn** (id 4412),
and inconsistent `Seniorów`/`seniorów` casing inside one series. Every one of these fails
silently if handled wrongly — no exception, no error, just wrong data on a calendar a
fencer plans around.

## Decision

### 1 · PZSz is a fourth organizer, inserted by migration

`tbl_organizer` rows exist only in the PROD seed dumps (`supabase/seed_prod_*.sql:14-16`);
no migration has ever inserted one. Two constraints decide the vehicle:

- Migrations run **before** the seed dump on CI and on `db reset`, so the insert must be
  idempotent and must survive the seed re-inserting the other three codes.
- `python/pipeline/promote.py` resolves `id_organizer` to PROD **by code** and produces a
  NULL for an unresolved code, which a NOT NULL column then rejects (ADR-081).

```sql
INSERT INTO tbl_organizer (txt_code, txt_name)
VALUES ('PZSz', 'Polski Związek Szermierczy')
ON CONFLICT (txt_code) DO NOTHING;
```

`idx_organizer_code` (`20250301000001_enums_tables_indexes.sql:169`) backs the
`ON CONFLICT`. **The ordering is a constraint, not tidiness:** PZSz must exist on CERT and
PROD before the first calendar promote runs, or that promote fails outright.

The name stays Polish. *Związek* has no clean English equivalent, and the sibling row
*Stowarzyszenie Polskich Weteranów Szermierki* is already stored untranslated.

### 2 · `tbl_event.id_pzsz_event` is the durable identity

An INTEGER column with a **per-season** partial unique index
(`idx_tbl_event_pzsz_season`), mirroring `idx_tbl_event_evf_calendar_season`. It earns its
place three times:

- **Stable identity.** PZSz names drift and carry live typos. An id survives a rename; a
  name-based match would create a duplicate event.
- **The re-check key.** The fill-when-available pass needs to know which detail page
  belongs to which of our rows.
- **Change detection.** A row whose id we hold but which vanishes from the listing is a
  cancellation or a re-key, and is surfaced rather than silently dropped.

Matching is **by source id first, by code only as a fallback**. That order is load-bearing:
a round moving from I to II changes the code, and a code-first match would read that as
*delete one event, create another*, taking any registrations with it. The code fallback
exists for the other direction — adopting a row an admin entered by hand rather than
duplicating it.

### 3 · Our season window decides membership; theirs is pagination

PZSz does not define seasons the way we do, so **their season label decides nothing**. An
event belongs to `SPWS-2026-2027` if and only if its dates fall inside our own
`tbl_season.dt_start … dt_end`.

`SezonAutocomplete` is demoted to what it actually is: a pagination key for getting under
the 70-row cap — worthless as semantics, load-bearing as access. The scraper reads our
active season, derives the PZSz keys the window touches (`{2025/2026, 2026/2027,
2027/2028}` for 2026-07-13 … 2027-07-15), fetches each series × key, unions on the PZSz
id, and date-filters against our window. Verified live:

```
'Puchar Polski senior'      2025/2026 → 13    'Mistrzostwa Polski senior' 2025/2026 →  1
'Puchar Polski senior'      2026/2027 →  6    'Mistrzostwa Polski senior' 2026/2027 →  0
'Puchar Polski senior'      2027/2028 →  0    'Mistrzostwa Polski senior' 2027/2028 →  0

union 20 rows  →  date-filtered to SPWS-2026-2027  →  6 events
```

Three measured properties make this safe. A season key PZSz does not have returns **zero**
rows, not the unfiltered 70 (confirmed against 2027/2028) — which is what lets the
candidate set run a year ahead of publication. `Nazwa` matches case-insensitively as a
substring, so the ASCII-safe `Puchar Polski senior` catches both casings while excluding
`juniorów`, and removes the percent-encoding trap where a raw `ó` returns zero. And
`Nazwa` alone is not sufficient — it returns the capped 70, so the season key is required
as pagination even though it is ignored as meaning.

The `pzsz_season` cell is still captured, purely as provenance.

### 4 · Any response of exactly the cap is presumed truncated and raises

`assert_not_truncated()` is the one assertion that stops this scraper failing quietly. It
raises at `len(rows) >= 70` rather than `== 70`, so a source that later raises its own cap
does not sail past it. The cost is a false alarm on the day a query legitimately returns
70 rows; the alternative cost is missing events on a calendar veterans plan around.

The cap is not currently biting — the narrowed query returns 6 rows this season and 13
last. A third narrowing axis is held in reserve: `Bronie[0]`, giving `Nazwa` × season ×
weapon at roughly five rows apiece.

**A last-seen-id cursor does not replace this.** The listing exposes no offset parameter;
the detail page of a future event carries only name, start date, city and organizing club
(verified on id 4588), so the fields we need exist only on the listing row; and ids are
creation order, not date order (id 4637 is July 2027, id 4661 is December 2026), so
`last + 1` would find only newly created rows and never revisit an edited one — a moved
date, a changed venue, a cancellation. For a calendar that is precisely the wrong failure
mode.

### 5 · Event codes follow ADR-046, with an uppercase gender letter

Round number, then lowercase weapon letters, then the season suffix. MPS carries no round
(`MPSefs-2026-2027`), because a championship is not a round of anything.

A PPS round is occasionally split by gender, and the two halves are **separate
competitions, not one event over two days** — verified on both seasons that show it. Round
IV épée 2025/2026 ran men in Gliwice 16–17.05 and women in Warszawa 17.05; the 2024/2025
equivalent ran men in Gliwice under PIAST GLIWICE and women in Warszawa under AZS AWF
WARSZAWA — different cities, different organizing clubs, six days apart. Both collide on
`PPS4e`.

The rule is an uppercase gender letter before the weapon letters: **`PPS4We` for women and
`PPS4Me` for men.**

**W, not the F this codebase would otherwise imply.** Event-code weapon letters are English
(`_WEAPON_LETTERS = {"EPEE": "e", "FOIL": "f", "SABRE": "s"}`) while the project's gender
letters are M/F (`enum_gender_type AS ENUM ('M','F')`, and tournament codes read
`MPW-V0-F-EPEE`). Following that convention here would give `PPS4Fe` — one case-fold from
`PPS4fe`, in a scheme whose trailing lowercase run *is* the weapon list. **F is foil.** So
the existing gender convention cannot be inherited, and W is the letter carrying no weapon
meaning. The Polish `K` would dodge the clash too, but sets a Polish gender letter against
English weapon letters inside one code.

Uppercase also keeps the gender letter clear of the lowercase weapon run, so
`weaponLetters()`'s trailing `/[efs]+$/` still resolves `E`, and `panelLabel()` degrades to
a readable `PPS4W` / `PPS4M` on the 48px tile. No announced 2026/2027 event exercises this,
so it ships with a fail-loud collision guard: two events resolving to one code raise
(`PzszCodeCollisionError`) rather than overwrite, mirroring `evf_calendar.py`'s
`CalendarIntegrityError`.

### 6 · Events are created childless — no tournament rows

`tbl_tournament.enum_age_category` is NOT NULL over V0..V4, and a senior bracket has no
honest value for it. That question belongs to the scoring deliverable, so this creates no
tournament rows at all.

This is a supported state, not a workaround. ADR-081 records that the reconciler's CREATE
is childless, and ADR-084 deliberately reads weapons from the code (`weaponLetters()`)
rather than from `arr_weapons`, precisely because that column cannot express "unknown" —
86 of 96 CERT rows sit on its all-three default. Tiles and cards therefore render weapons
correctly with zero tournaments present, verified on LOCAL.

### 7 · What PZSz publishes per event, and what it does not

Measured 3 September 2026 across seven live komunikat PDFs and all thirteen PPS detail
pages of the 2025/2026 season.

| Field | Column | Source | Availability | Verdict |
| --- | --- | --- | --- | --- |
| Invitation letter | `url_invitation` | detail page, *Komunikaty organizatora* | 13/13 | build |
| Venue city | `txt_location` | listing, *Miejsce* | 6/6 | build |
| Venue street address | `txt_venue_address` | komunikat PDF | 7/7 | build |
| Registration deadline | — | — | 0/7 | not published |
| Registration link | — | — | 0/7 | not published |

**The invitation is a fill-when-available loop.** Every PPS event of 2025/2026 carries a
komunikat; none of the six 2026/2027 events does yet — their detail pages read *Brak
komunikatów*. The letter is published closer to the event, so the field cannot be filled at
first scrape. Each daily run re-visits the detail page of every PZSz event in the active
season and fills the field the first time the section stops being empty. **Fill-blank-only:**
an admin-entered URL is never overwritten, matching the reconciler's existing field-ownership
split (ADR-081).

**The EVF PDF heuristic does not transfer.** `parse_event_detail_html()` finds an EVF
invitation by testing `href.lower().endswith(".pdf")`. The PZSz URL is
`/test/fileDownload.php?fileId=…` — an opaque download endpoint with no extension at all,
so that rule finds nothing. PZSz anchors on the labelled *Komunikaty organizatora* section
instead, which is a statement about what the section *is* rather than a guess about how a
file happens to be named.

**`url_registration` and `dt_registration_deadline` stay NULL, asserted rather than merely
unset.** All seven komunikaty resolve entry to *"zgodnie z regulaminem PZS"*, the
federation's standing regulations; the only concrete cutoff any of them states is
confirmation to the Technical Committee 45 minutes before the start, which is a check-in
rule at the venue. Zero of seven reference a registration host. Entry runs through the
licence system behind `pzszerm.pl/logowanie/` — club-mediated and login-walled. A non-empty
`url_registration` plus `dt_end` is what lights the tile's live-registration dot (ADR-084
§G), so a plausible-looking value would tell a veteran they can enter when they cannot. An
empty field states the truth.

The deadline harvest ships **off**, behind the same `HARVEST_DEADLINE` flag EVF uses, for
the same recorded reason: EVF measured a live yield of 0 in 13, PZSz measures 0 in 7.

### 8 · A fifth panel type and a fourth registry — amending ADR-084

`panelType()` switches on `txt_code`, not on `id_organizer`, so the hue hangs off the new
prefix rather than the foreign key. `/^(PPS|MPS)/` is matched **before** the `ppw`
fallback and **after** the `MPW` branch: PPS shares its first two letters with PPW and MPS
with MPW, so the branch must be specific enough not to swallow them and early enough to be
reached at all.

| Surface | Change |
| --- | --- |
| `PanelType` | gains `'pzs'` |
| `panelType()` | `/^(PPS|MPS)/` before the `ppw` fallback |
| `registryOf()` | return union widens to `'SPWS' \| 'EVF' \| 'FIE' \| 'PZSz'` |
| `EventCard.svelte` | `.card.pzs` (`--edge`), `.ccd.pzs` registry chip |
| `CalendarBarrel.svelte` | `.p.pzs`, `.p.soon.pzs`, `.crt.pzs` |

Existing edges are `#2e7d52` green (SPWS), `#1f6fb0` blue (EVF), `#b1791d` amber (FIE).
PZSz's own brand red is `#c72626`; the desaturated `#c05555` keeps the family coherent
while staying recognisably theirs.

These events are domestic, so `isInternationalEvent()` is **untouched** and they appear in
the default `ppw` scope — which is the point. A veteran should see them without hunting for
a toggle.

### 9 · A separate workflow, the same cron, and `queue: max` across `prod-write`

`.github/workflows/pzsz-sync.yml` runs at `'0 6 * * *'`, the same minute as
`evf-sync.yml`. **Not a job inside `evf-sync.yml`:** a job there shares one run identity —
a single red/green, one re-run button, one set of EVF-specific `workflow_dispatch` inputs.
Job-level independence would be real; run-level independence would not, and the run is what
an operator looks at.

The scrape job carries **no** concurrency group — it touches nothing on PROD, so it runs
genuinely in parallel with the EVF scrape. Only the promote joins `prod-write`, with
`if: ${{ !cancelled() }}`, which is not cosmetic: `evf-sync.yml` documents that without it
an upstream failure silently *skips* the promote, costing 13 unpromoted events on
14 July 2026.

**`queue: max` goes on every member of `prod-write`, not only the new job.** GitHub's
documented default is that only one job may be pending per group, and a newly queued job
*cancels* the already-pending one; `cancel-in-progress: false` does not cover this.
Protecting only the new job would leave it cancellable by the others, and cancelled is not
failed, so nothing would alert. The plan named four jobs; the group actually has eight
members, and all eight now carry the setting:

`evf-parity-sweep.yml::parity-sweep`, `evf-sync.yml::promote-calendar-pre`,
`evf-sync.yml::promote-calendar`, `ftl-seed.yml::deadline-sweep`,
`promote-season.yml` (workflow-level), `promote.yml` (workflow-level),
`pzsz-sync.yml::promote-calendar`, `recompute-drain-prod.yml::drain`.

If `queue: max` proves unavailable on this runner it fails as a workflow validation error
on the first run — loudly, immediately, cheap to detect. The fallback is a 15-minute
stagger (`45 5 * * *`), which costs nothing real.

**Same-minute scheduling is safe because the two promotes are mutually redundant by
construction.** `promote --mode calendar` is a whole-active-season create/update/delete
reconciler keyed on `txt_code` (ADR-081): it converges everything in CERT, not just the
rows the calling workflow scraped. If the PZSz promote fails, EVF's converges the PZSz rows
minutes later, and vice versa. CERT is the source of truth for the calendar and is never
left wrong by a promote failure.

## Alternatives considered

1. **Generalise `evf_calendar.py` to a second source.** Rejected: its 1536 lines are
   EVF-specific pathology — invitation-PDF weapon extraction, slug dedup, future-COMPLETED
   healing — none of which applies to a clean server-rendered HTML table. Generalising it
   now would drag all of that in for no benefit.
2. **Persist the highest PZSz id and start the next run at `id + 1`.** Rejected on three
   independent grounds, set out in §4: no offset parameter exists, detail pages lack the
   fields, and ids are creation order rather than date order.
3. **Trust `SezonAutocomplete` as the season.** Rejected: PZSz seasons are not ours, and
   boundary events would be filed wrongly in both directions. Demoted to pagination (§3).
4. **Reuse `python/tools/_backends.py` for Management API access.** Rejected: it is framed
   for one-shot operator tools and has no retry. A workflow running unattended on a cron
   needs the retry-on-429/503 that `evf_sync.py` already carried, so those helpers moved to
   `python/scrapers/_supabase.py` instead.
5. **Follow the project's M/F gender letters.** Rejected: `PPS4Fe` is one case-fold from
   `PPS4fe` in a scheme where the trailing lowercase run is the weapon list, and F is foil
   (§5).
6. **Point `url_registration` at the PZSz licence-system login.** Rejected: it would light
   the tile's live-registration dot and tell a veteran they can enter when entry is
   club-mediated (§7).
7. **Delete a CERT row when its PZSz id vanishes from the listing.** Rejected: a
   disappearance is a cancellation or a re-key, and a delete would take any registrations
   with it. Reported instead, for a human.
8. **Add a job to `evf-sync.yml` rather than a new workflow.** Rejected on run identity
   (§9).

## Consequences

**New files**

- `supabase/migrations/20260903000001_pzsz_organizer_and_event_id.sql`
- `supabase/tests/70_pzsz_organizer_and_event_id.sql` — plan-test-ID 70, 11 assertions
- `python/scrapers/pzsz_calendar.py` — pure parsing and planning
- `python/scrapers/pzsz_sync.py` — the CLI, with `--dry-run`
- `python/scrapers/_supabase.py` — shared Management API + Telegram access
- `python/tests/test_pzsz_calendar.py` — pzsz.1–pzsz.24
- `python/tests/test_pzsz_sync.py` — pzsz.25–pzsz.34
- `python/tests/fixtures/pzsz_*` — four listing responses, two detail pages, one komunikat PDF
- `.github/workflows/pzsz-sync.yml`

**Changed files**

- `python/scrapers/evf_sync.py` — `_management_query`, `_telegram` and `_get_active_season`
  moved to `_supabase.py`; behaviour-preserving, with the EVF tests unedited
- `frontend/src/lib/calendarMonths.ts`, `EventCard.svelte`, `CalendarBarrel.svelte` — §8
- six workflow files — `queue: max` (§9)

**One seam worth recording.** Moving `_get_active_season` out of `evf_sync.py` moved its
bare-name lookup of `_management_query` with it, silently redirecting the call away from
the name the EVF tests patch — nine tests failed by issuing a *real* HTTP request.
`_supabase._get_active_season` therefore takes an optional `query` callable, and `evf_sync`
keeps a three-line wrapper pinning it to its own module global. Any future extraction of a
patched helper faces the same hazard.

**Fixtures are committed and the tests never touch the network.** The six 2026/2027 events
carry no komunikat today and that will change, probably before this ships — which is the
whole point of the fill-when-available pass, but it also means the `no_komunikat` fixture
must stay a saved copy rather than be re-fetched.

**No change to the shared spine.** CERT, `promote.py` and PROD take none: the reconciler is
organizer-agnostic and keys on `txt_code`. `id_pzsz_event` is not carried to PROD, which is
correct — the enrichment pass runs against CERT.

**Defects found and deliberately not fixed here.** `PSW` was added to
`enum_tournament_type` and to the scoring function in March 2025 but never to the lifecycle
trigger (`20250301000003_lifecycle_triggers.sql:48-53`), so PSW tournaments carry a NULL
`num_multiplier` today. Real, unrelated, untouched — recorded so the scoring deliverable
starts from it rather than rediscovering it.

## Open items

1. **Scoring PPS/MPS results.** Out of scope by decision, not by omission. The rule as
   discussed is that results score with the raw senior placing — 12th of 120 is 12th of 120
   — with the ranklist capping how many count (best 1 or best 2, unsettled).
   `tbl_scoring_config.json_ranking_rules` is already shaped as `{"best": N, "types": [...]}`
   and needs no new machinery for the cap. A sixth `enum_tournament_type` is **not** a
   one-line change: three hardcoded `CASE enum_type` blocks resolve the multiplier and none
   has an `ELSE`. `enum_age_category` would need a `SENIOR` member, and
   `parse_tournament_name()` (`python/tools/scrape_ftl_event_urls.py:289`) maps a bracket
   named *Senior* to `V0`, which on a genuinely senior event silently mis-tags every
   bracket. **Recommendation:** sequence the season's planned scoring-formula change first,
   so PPS results are not scored under a formula about to be replaced.
2. **Whether PZSz hosts its own results.** Each tournament has a page at
   `/zawody/kalendarium-zawodow/turniej/?id=NNNNN` carrying tabs for *Lista startowa*,
   *Grupy*, *Ranking Grupowy*, *Tabela* and *Klasyfikacja końcowa*, with pool-sheet markup
   already present. The one sampled (id 10520) was empty, so this is a lead rather than a
   finding. **Recommendation:** measure coverage across completed events before designing
   the results path — if PZSz populates it, the scoring deliverable may not need
   FencingTimeLive for PPS and MPS at all.
3. **Backfill.** Current season only; no historical PZSz events are imported.
   **Recommendation:** leave it that way unless the scoring deliverable needs a baseline.
4. ~~**`queue: max` availability.**~~ **Resolved 2026-09-04.** The key is documented
   (`single` the default, `max` allowing up to 100 pending) and it is accepted by this
   runner: every `prod-write` job carrying it has since run clean — both promotes in
   `evf-sync.yml`, the new `pzsz-sync.yml` promote, and two full releases. One constraint
   the plan did not mention surfaced in the documentation and was checked before shipping:
   `queue: max` combined with `cancel-in-progress: true` is a workflow validation error.
   All eight members are on `cancel-in-progress: false`, so none is affected. The
   15-minute stagger fallback is not needed.
