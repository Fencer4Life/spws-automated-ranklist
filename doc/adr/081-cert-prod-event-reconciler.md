# ADR-081: CERT→PROD Event Reconciler

**Status:** Accepted (2026-07-11, shipped to CERT+PROD)
**Date:** 2026-07-11
**Source:** CERT→PROD calendar promotion (spec §; migrations `20260711000001`, `20260711000002`). Supersedes the calendar-delta half of ADR-026; amends ADR-028, ADR-039 (rev 3), ADR-077.

## Context

The CERT→PROD calendar-promotion path (`python/pipeline/promote.py::promote_calendar` →
`fn_import_evf_events`, the ADR-026 amendment) was written as an **EVF special-case**
and carried three coupled defects, all from the same assumption — "this path only ever
sees EVF":

1. **Hardcoded organizer.** The function ran `SELECT id_organizer ... WHERE txt_code = 'SPWS'`
   once and stamped it on every promoted event — never verified. Confirmed live: 7 Samorin
   rows on PROD mis-tagged SPWS instead of EVF.
2. **Insert-or-refresh only, no DELETE.** It could introduce divergence from CERT but never
   remove it. When CERT's own dedup bug (ADR-039 rev 2 / migration `20260710000001`) minted 7
   Samorin duplicates and they were promoted, then CERT was collapsed back to 1, the 6 dead
   PROD rows had **no route to removal** and needed manual surgery.
3. **`PEW/MEW` code-prefix filter.** The only *incremental* CERT→PROD event path excluded
   domestic PPW/MPW — a domestic event added after season go-live could never reach PROD.

A fourth, upstream defect fed the duplicates in: `fn_allocate_evf_event_code`'s
location-matching Steps A/B are gated `IF v_loc_key <> ''`, so a venue-less future event
(blank location) skipped both and Step C minted a fresh code on every scrape.

The root realization: **"one-time bulk event copy" (season skeleton, ADR-077) and
"incremental delta" (calendar promote) are the same operation at two points in time** — a
reconcile of PROD's event set to CERT's. Written as one reconciler, both the organizer bug
and the duplicate accumulation disappear, and the domestic gap closes.

## Decision

Replace `fn_import_evf_events` with **`fn_mirror_events_to_prod(p_creates, p_updates,
p_deletes JSONB)`** — a full **Create / Update / Delete reconciler** over the *whole*
active-season event set, keyed on `txt_code`. `promote_calendar` becomes the diff engine.

### 1. Organizer-agnostic, verified from source

`id_organizer` is never hardcoded. `promote_calendar` reads each CERT event's real organizer
**code** and resolves it to a PROD id **by `txt_code`** (via the shared `_prod_code_to_id`,
the same helper `promote_season.py` uses — raw ids diverge across environments). The SQL
`RAISE`s if a code doesn't resolve — **fail loud, never guess**. Same rule for `id_prior_event`.

### 2. Whole-set diff, no code filter

`_read_cert_promotable_events` reads **all** active-season events (no `PEW/MEW` filter), joins
`tbl_organizer` for the code. Diff by `txt_code`: CERT∖PROD → CREATE, CERT∩PROD → UPDATE,
PROD∖CERT → DELETE.

### 3. Field-ownership split (UPDATE)

- **Source-owned identity** (`txt_name`, dates, location, country, `id_organizer`,
  `arr_weapons`, `id_evf_event`, `txt_evf_slug`) → overwrite from CERT (this is the mis-tag
  repair). Empty CERT values collapse to "keep current" via `NULLIF` — never write `''` into
  the uniquely-indexed `txt_evf_slug` (migration `20260711000002`, live-caught crash).
- **Admin-owned URL/fee/registration** fields → **fill-blank-only** (never clobber a hand
  entry — reuses the `fn_refresh_evf_event_urls` contract; `feedback_urls_admin_managed`).
- **`enum_status`, tournaments, results** → never touched (owned by the results lifecycle /
  `promote_event`).

### 4. Guarded DELETE

Delete a PROD event only if `enum_status = 'PLANNED'` **and** it has zero `tbl_result` rows
(empty tournaments dropped first, transactional). A results-bearing event absent from CERT is
returned in `delete_skipped` for investigation — **never erased**. Once an event has results
its status leaves PLANNED, so it is structurally untouchable here.

### 5. CREATE is childless

New events are created without tournament children (results-promotion creates tournaments on
demand; skeleton-promoted domestic events are already childless).

### 6. Active-season-mismatch guard

`promote_calendar` refuses when CERT and PROD are on **different** active seasons — comparing
CERT's new-season events against PROD's old-season set would misfile creates under the wrong
`id_season` and propose deleting PROD's entire outgoing season. This cross-season misfiling is
exactly how the 7 PROD Samorin duplicates (coded `-2026-2027`) came to sit under the
`2025-2026` season id. The active season is a live admin toggle, so this guard is essential.

### 7. Run log

Every reconcile writes a human-readable `.md` run log (like the per-event scrape log) to
`doc/staging/reconcile/{season}.{ts}Z.md` (committed by the workflow) + the CERT
`staging-reports` bucket. Column-agnostic: it diffs `to_jsonb(row)` minus env-local noise
(raw ids/timestamps, organizer→code), so URLs, fees, registration flags, and any future
column appear with no code change. Two sections — *Changes applied* (PROD before→after, real
changes only) and *Divergences NOT synced* (CERT vs PROD-after: admin-owned kept,
lifecycle status, or an UNMAPPED new column) — plus a Summary (RPC counts + convergence).

## Consequences

- **Self-healing:** the reconciler removes divergence from CERT, not just adds to it — the
  first live PROD run auto-deleted the 6→7 Samorin orphans and re-tagged the survivor EVF.
- **Domestic events** now reach PROD incrementally (no code filter).
- **Organizer mis-tag is structurally impossible** — no literal survives anywhere.
- **`fn_import_evf_events` retired.** `fn_promote_season_skeleton` slimmed to season +
  scoring_config only (ADR-077 amendment); event C/U/D is owned entirely by the reconciler.
- **Two rollout gotchas, both guarded + regression-tested:** the season mismatch (§6) and the
  `txt_evf_slug` `''`-vs-NULL unique-index crash (§3, migration `20260711000002`). The
  reconciler's single-transaction design meant the crash rolled PROD back cleanly — no data
  lost.
- Cost: the reconcile is season-scoped and reads the full event set on both sides plus two
  PROD snapshots for the run log; the tables are small (tens of rows).

Tests: pgTAP `51_prod_event_reconcile.sql` (51.1–51.8), `18` evf.56 (ingest pre-check);
pytest `test_promote.py`, `test_promote_season.py`, `test_reconcile_report.py`.

## See also

- **System explainer:** `doc/plans/evf-calendar-sync-how-it-works.html` — end-to-end
  walkthrough of how EVF calendar sync works now (architecture diagram, the three-job
  `evf-sync.yml` bracket, the reconciler's create/update/delete diff, the active-season
  guard, and the 2026-07-14 incident that hardened both).
