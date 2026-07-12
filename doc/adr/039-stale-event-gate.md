# ADR-039: EVF Scraper Dedup Algorithm + Stale-Event Gate

**Status:** Accepted (revised 2026-06-13 rev 2 — Step 0 self-heals from FTL before halting)
**Date:** 2026-04-25
**Relates to:** ADR-028 (EVF Calendar + Results Import — amended by this ADR), ADR-025 (Event-Centric Ingestion + Telegram), ADR-014 (Delete-Reimport Strategy), ADR-069 (FTL URL validator / authed FTL session reuse)

## Context

The first version of the EVF dedup logic ([commit `e440299`](https://github.com/Fencer4Life/spws-automated-ranklist/commit/e440299)) used `(dt_start exact, canonical country)` as the primary key with a `±N day window + fuzzy-name ≥ 80%` fallback. EVF actively renames events mid-season — the canonical incident was "EVF Circuit Napoli" → "EVF Circuit – Naples (ITA)", which scored ~73% on `token_set_ratio` and slipped below the 80% threshold. Three duplicate event rows were inserted into CERT and propagated to PROD via the calendar-promote cron:

- `PEW-PALAVESUVI-2025-2026` (vs seed-numbered `PEW4-2025-2026` Naples)
- `PEW-OSRODEKSPO-2025-2026` (vs `PEW6-2025-2026` Jabłonna)
- `PEW-CHANIAKLAD-2025-2026` (vs `PEW8-2025-2026` Chania)

All three duplicates had 0 results — the calendar scrape created the row, but the results scrape continued to match the seed-numbered keeper (because of an unrelated `EXISTS(tbl_tournament)` filter in the results-side query). The calendar UI displayed both rows side-by-side. The cleanup itself was a one-line `fn_delete_event` call per dup. The remaining work is to ensure the scraper never produces another such duplicate.

Two architectural problems the original design did not address:

1. **EVF retroactively edits old results.** When the cron ran on 2026-04-25 it observed Budapest 2025-09-20 (7 months past) growing 6 new "EVF-only" fencers vs CERT. Without a stale-event gate, the scraper kept syncing changes to long-finished events, opening surface area for further drift.
2. **Future events marked COMPLETED is data corruption.** Nothing in the original design caught this; the scraper would happily proceed on top of a broken state and propagate the error.

## Decision

The EVF scraper applies a **5-step algorithm** for every cron run. Steps are evaluated in order; an earlier step's verdict is binding.

### Step 0 — Logical-integrity guard

Before any matching, scan the active-season CERT events for the invariant:

```
NOT (dt_start > today AND enum_status = 'COMPLETED')
```

Any row violating it is, in the original design (rev 1), a hard halt: raise `LogicalIntegrityError`, send the **EVF Sync HALT** Telegram alert, exit non-zero, and wait for a manual SQL fix.

#### rev 2 (2026-06-13) — self-heal, never hard-halt

Rev 1 halted the *entire* daily pipeline for the most common cause of a Step 0 violation: an event already scored from FTL that was left with a **placeholder date** (e.g. `PEW63e`/`PEW64s`, scored from the BVF 6-Weapon International — Guildford GBR — but stamped `2026-10-01`/`2026-11-11`). This is recoverable, yet it took the cron down daily and demanded hand-written SQL.

Rev 2 replaces the halt with a **self-heal pass** keyed on the **event URL** (`tbl_event.url_event`), the authoritative source for an event's real date. Per violator:

1. **Recover the event date** (`_resolve_event_date`), in priority order:
   - **(a)** the row's own `url_event`;
   - **(b) primary — EVF calendar:** match the violator to the event the sync already scraped that run (via `match_scraped_to_existing` with the **date gate disabled** — the date is the broken field — so it keys on country/location per Steps 3–4) and take that event's URL + date;
   - **(c) fallback — FTL:** the event's tournament results pages.
   The event URL (FTL `eventSchedule` or `events/results`) is fetched with the authed ADR-069 session (`get_authed_ftl_client` → `fetch_ftl_event_metadata`, which now accepts both URL forms).
2. **Date-healable** (a valid date `≤ today` was recovered) → rewrite `dt_start`/`dt_end` + the FTL-backed `dt_tournament`, and **populate `url_event`** with the resolved URL. Status stays `COMPLETED`.
3. **Not date-healable** (no event URL, no calendar match, no FTL date, or auth failure) → **demote `enum_status` `COMPLETED` → `PLANNED`** so the row is no longer future-COMPLETED. `url_event`/date get populated later by the calendar / `populate_tournament_urls` flow; the demotion is logged via the informational **EVF Sync self-heal** Telegram notice.

The status demotion must bypass `fn_validate_event_transition` (Section 3 of `lifecycle_triggers`), which makes `COMPLETED` terminal — the heal disables `trg_event_transition` for that single `UPDATE` (a deliberate system-level reconciliation; the everyday lifecycle contract is unchanged).

**Consequence — the sync no longer hard-halts on this class.** A future-COMPLETED row is either date-healed or demoted; either way the guard clears. `assert_no_future_completed` is retained only as a post-heal belt-and-braces assertion. FTL/calendar remain the sole date authorities — the heal never invents a date. The decision of corrections-vs-flips is a pure function (`compute_future_completed_corrections` → `(corrections, status_flips)`); DB/HTTP side-effects live in `evf_sync._heal_future_completed`.

### Step 1 — Stale-event gate

For every event (scraped or existing):

```
in_scope(event) iff
    event.enum_status != 'COMPLETED'
  AND
    (today − event.dt_end) < 30 days       (dt_end NULL → use dt_start)
```

For scraped rows from EVF (no `enum_status` field), only the date clause applies. Out-of-scope events are **never auto-created and never auto-updated** — admin handles them via `fn_delete_event` / manual SQL.

### Step 2 — Date gate (BLOCKING for dedup)

`|S.dt_start − e.dt_start| ≤ 7 days`. Wide enough to absorb HTML-vs-API one-day skews and 6-day team championships; tight enough that EVF's own scheduling (no two of its events in the same country within a week) guarantees no false merges.

### Step 3 — Country corroboration (STRONG)

`canon_country(S) == canon_country(e)` (both non-empty) → match. Stop. The alias table at [python/scrapers/evf_calendar.py:45](../../python/scrapers/evf_calendar.py#L45) handles 18+ language variants (Polska/Poland, Italia/Italy, Österreich/Austria, etc).

### Step 4 — Location corroboration (MEDIUM, fallback)

When country is missing on either side: `fuzz.token_set_ratio(diacritic_fold(S.location), diacritic_fold(e.txt_location)) ≥ 70` → match. Punctuation is stripped and case is normalised before tokenisation so `"Stockholm, Sweden"` matches `"Stockholm"`.

### Step 5 — No match → return None

Caller decides: in-scope no-match → auto-create. Out-of-scope no-match → log + skip.

### Deliberately removed: name comparison

EVF actively renames events mid-season (the Napoli↔Naples incident). Date + country + location are *physical* properties that cannot be renamed away. Re-introducing fuzzy-name matching would re-open the duplicate-creation surface area.

## Alternatives considered

1. **Lower the name-fuzzy threshold to 70%.** Rejected: the same threshold that catches Napoli↔Naples also accidentally merges adjacent same-country events with overlapping vocabulary. We have no upper bound on rename creativity — solving the symptom widens the bug class.

2. **Merge rather than delete legacy duplicates** (via a hypothetical `fn_merge_event` RPC). Rejected: in the actual incident, the venue-coded duplicates were all empty (0 results). A re-parenting RPC was solving a problem we did not have; `fn_delete_event` was sufficient. Speculative tooling carrying its own test surface, ADR registry burden, and cleanup logic for a future event-collision case nobody has observed yet violates YAGNI.

3. **Embed `is_in_scope` inside `_find_existing_match`.** Rejected: the matcher should be a pure function of inputs. Pushing the gate to the caller (`evf_sync.sync_calendar` / `sync_results`) keeps the matcher composable and decision-pure, which simplifies tests (`evf.22` tests `is_in_scope` directly; `evf.24` tests the caller-pre-filter pattern).

## Consequences

### Positive

- **Single source of truth** for event identity matching — `_find_existing_match` is shared between calendar and results paths. The previous divergent ad-hoc queries in `_compare_and_ingest` are gone.
- **Bounded scrape surface** — the 30-day window means each cron run only ever touches at most ~2-3 events (the in-flight ones). Stale event noise is eliminated.
- **Loud failure on data corruption** — Step 0 surfaces invariant violations to Telegram immediately rather than silently propagating broken state.
- **Deterministic decisions** — no fuzzy name scoring means the same scrape always produces the same result. No more "scraper is non-deterministic" mysteries.

### Negative

- **Stale events require manual creation.** If EVF publishes an event into the API > 30 days after it ran, the admin must manually create the CERT row before the next cron will sync results. Acceptable because such retroactive publishes are rare and admin-flagged is safer than auto-create-and-hope.
- **Two new outbound Telegram messages** (one new failure mode + one informational summary). Documented in [`doc/cicd-operations-manual.md`](../cicd-operations-manual.md) §10.

### Outbound Telegram surface (new, this ADR)

| Trigger | Template |
|---|---|
| Step 0 self-heal applied (informational, rev 2) | `<b>EVF Sync self-heal (Step 0)</b>\n<pre>healed dates: {codes} \| demoted→PLANNED: {codes}</pre>` |
| Step 1 events filtered (informational) | Logged to stdout; no separate Telegram unless wanted by future iteration. |

> rev 2 removed the **EVF Sync HALT** message for this class — a future-COMPLETED row is now always either date-healed or demoted, so the sync no longer halts (and no longer needs manual SQL) on it.

The full outbound-message catalogue lives in the operations manual.

## Test plan

| Test ID | Assertion |
|---|---|
| `evf.19` | Renamed event with name-similarity but no country/location → NO match (regression guard for the name-fallback removal). |
| `evf.20` | Country missing on either side, location overlap ≥ 70% → match via Step 4. |
| `evf.21` | Date drift edge: ±7d matches, ±8d does not. |
| `evf.22` | `is_in_scope` correctly classifies stale-PLANNED, stale-COMPLETED, fresh-PLANNED, fresh-COMPLETED, future-PLANNED. |
| `evf.23` | `assert_no_future_completed` raises `LogicalIntegrityError` when given a future-COMPLETED row. |
| `evf.24` | Caller-side `is_in_scope` pre-filter excludes COMPLETED rows from `deduplicate_events` candidates. |
| `evf.44` | rev 2: `compute_future_completed_corrections` heals a violator from a recovered past date (earliest→dt_start, latest→dt_end); no status flip. |
| `evf.45` | rev 2: no date recovered → violator returned as a `status_flip` (not a halt). |
| `evf.46` | rev 2: recovered date still in the future → `status_flip` (no swapping one bad date for another). |
| `evf.47` | rev 2: `_heal_future_completed` heals from the **event URL** — `UPDATE tbl_event` sets dt + populates `url_event`; no flip. |
| `evf.48` | rev 2: no recoverable date → no date `UPDATE`; the row's status is demoted instead. |
| `evf.49` | rev 2: the demotion bypasses the lifecycle trigger (`DISABLE`/`ENABLE TRIGGER trg_event_transition` around `enum_status='PLANNED'`). |
| `evf.50` | rev 2: `fetch_ftl_event_metadata` parses the date from a `/tournaments/eventSchedule/` event URL (not only `/events/results/`). |

(Plus existing `evf.4`, `evf.5`, `evf.13`, `evf.14`–`evf.18` updated to align with the new ladder.)

## References

- [python/scrapers/evf_calendar.py:614](../../python/scrapers/evf_calendar.py#L614) — `_find_existing_match` (rev 2)
- [python/scrapers/evf_calendar.py:`is_in_scope`](../../python/scrapers/evf_calendar.py)
- [python/scrapers/evf_calendar.py:`assert_no_future_completed`](../../python/scrapers/evf_calendar.py)
- [python/scrapers/evf_sync.py:77](../../python/scrapers/evf_sync.py#L77) (`sync_calendar`) and [:222](../../python/scrapers/evf_sync.py#L222) (`sync_results`) — both invoke Step 0 and Step 1 at entry.
- ADR-028 amended by this ADR (rev 2 section).

## Amendment — rev 3 (2026-07-11, ADR-081)

The `id_evf_event → txt_evf_slug → date+country+location` dedup ladder (rev 2, migration
`20260710000001`, Python `_find_existing_match`) is now also enforced at the **SQL layer** in
the CERT ingest: `fn_ingest_evf_calendar` (renamed from `fn_import_evf_events_v2`) does an
identity-first pre-check on `id_evf_event`/`txt_evf_slug` before the location-gated allocator,
so a venue-less repeat scrape can never mint a second row even if the Python dedup is bypassed
(regression evf.56). Closes `fn_allocate_evf_event_code`'s blank-location blind spot. See ADR-081.
