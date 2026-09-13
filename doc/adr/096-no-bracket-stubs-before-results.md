# ADR-096: A bracket is created by results ingestion, never by calendar discovery

**Status:** Accepted (proposed 2026-09-13, accepted 2026-09-13). Implemented, deployed and verified on LOCAL, CERT and PROD: the migration ran clean via the standard `main` release pipeline, a manually-dispatched **EVF Calendar + Results Sync** completed with zero errors (Athens synced at `PEW13es-2026-2027`, `0 new, 18 already in CERT`), and a direct query confirmed all 31 non-terminal events on both CERT and PROD hold zero child tournaments.
**Date:** 2026-09-13
**Amends:** [ADR-028](028-evf-calendar-results-import.md) §Calendar Scraping (the calendar RPC no longer creates a child `tbl_tournament` row for each weapon × gender; that sentence, dated April 2026, is superseded by the decision below), [ADR-046](046-pew-weapon-suffix.md) (the canonical tournament-code formula gains one shared implementation, `fn_rebuild_tournament_codes`, instead of two independently-drifting copies)
**Relates to:** [ADR-091](091-no-season-skeletons-for-scraped-events.md) (the same "a skeleton is a PREDICTION of a row that is going to arrive anyway" ruling, one layer up, for events instead of brackets), [ADR-081](081-cert-prod-event-reconciler.md) (the CERT→PROD reconciler's CREATE path is already childless — test 51.1b — and needed no change here), [ADR-083](083-server-enforced-authorization.md) (the new functions stay off the anon-EXECUTEable allowlist)
**Source:** `supabase/migrations/20260913000002_no_bracket_stubs.sql`

## Context

The **EVF Sync** GitHub Actions job failed from 2026-09-10:

```
ERROR: calendar sync failed: Management API error (400):
  23505: duplicate key value violates unique constraint "idx_tournament_code"
  DETAIL:  Key (txt_code)=(PEW13es-2026-2027-V2-M-EPEE) already exists.
```

The scrape itself was healthy — 18 competitions found, `0 new, 18 already in CERT`.
It fired because EVF moved Athens (calendar id 3438) from 2027-05-22 to
2027-03-27, which shifts three events' chronological PEW numbers. Athens held 8
child `tbl_tournament` rows where a real bracket set would hold 4, and the
renumbering step tried to collapse each duplicate pair onto one code.

**Root cause.** `fn_import_evf_events` (ADR-028, April 2026) inserted one stub
tournament per weapon × gender at calendar-import time — hardcoded
`enum_age_category = 'V2'`, `int_participant_count = 0`,
`enum_import_status = 'PLANNED'`. That block was copied forward through nine
rewrites of the calendar ingest. Querying every live `plpgsql` function's
definition on CERT for the stub-code pattern found exactly one survivor: the
2-arg `fn_ingest_evf_calendar(p_events jsonb, p_id_season integer)` in
`20260711000001_prod_event_reconciler.sql`.

Every original justification for the stub loop has expired:

- **The dedup marker it existed to serve is gone.** ADR-028's own text records
  the old matcher as `BETWEEN ±3 days AND EXISTS(tournament)` — a child row was
  the only signal an event had been imported. That matcher was replaced by
  Python's `_find_existing_match` id→slug→fuzzy ladder in the 2026-04-25
  rev 3 amendment.
- **The weapon/type facts it carried now live on the event.**
  `tbl_event.arr_weapons` is maintained for every family, derived from the
  event code (migration `20260904000001`, test 71), and the frontend calendar
  reads weapons from `arr_weapons`, never from children.
- **`vw_calendar.bool_has_international`'s only consumer already has a
  fallback.** `isInternationalEvent()` in `calendarMonths.ts` falls back to the
  code prefix when the bool is false.

And the predicted **shape** was always wrong, not merely premature. A real EVF
weekend ends with 10–23 brackets across V1–V4 (PROD 2025-2026: `PEW6efs` 23
brackets, `PEW4efs` 10 brackets with 389 participants). The stub set is
weapons × 2 genders at V2 only; when results land, `fn_find_or_create_tournament`
reuses the V2 stub and mints V1/V3/V4 fresh regardless. This is the same defect
class ADR-091 ruled on seven days earlier one level up — a skeleton is a
prediction of a row that is going to arrive anyway — applied one layer down, to
brackets instead of events.

**It is worse than a shape mismatch.** `fn_ingest_evf_calendar_identity_v1`
delegates every pre-terminal event to the 2-arg function on **every** sync, not
only newly-created ones. An event that already holds a real, results-backed
bracket gets two more stub rows injected alongside it on every single calendar
refresh, guarded only by a string match against the stub's own code shape
(`code || '-M-' || weapon`), which the real bracket never has, so the guard
never fires. The stub and the real bracket then collide the next time the event
renumbers, because the rebuild rewrites every child of that event to the same
canonical formula in one `UPDATE` — two rows landing on the identical target
string in the same statement. Reproduced locally in `79_no_bracket_stubs.sql`
79.3b; observed live as run 34468447030.

**Audit trail for the specific bracket the failing run died on** (Athens,
tournament row 1921; `trg_audit_tournament` fires on UPDATE/DELETE but not
INSERT, which is why the two halves of the pair are visible separately):

```
07-14 05:41  INSERT  PEW79-2026-2027-M-EPEE            <- 2-arg delegate, stub
08-08 06:55  UPDATE  PEW79-2026-2027-M-EPEE      -> __evfcal_1921
08-08 06:55  UPDATE  __evfcal_1921               -> PEW14es-2026-2027-V2-M-EPEE
08-28 16:43  UPDATE  PEW14es-2026-2027-V2-M-EPEE -> __evfcal_1921
08-28 16:43  UPDATE  __evfcal_1921               -> PEW15es-2026-2027-V2-M-EPEE
08-28 16:43  (no audit rows)  id 2065 = PEW15es-2026-2027-M-EPEE   <- the duplicate
```

The reflow rebuild also wrote a **third code dialect**,
`<event-code-with-season>-<Vcat>-<gender>-<weapon>` (e.g.
`PEW14es-2026-2027-V2-M-EPEE`), used nowhere else in the codebase. Canonical is
`<base>-<Vcat>-<gender>-<weapon>-<season>` (`fn_find_or_create_tournament`,
`fn_pew_recompute_event_code`, this ADR's own §2 below); the stub shape is
`<event-code-with-season>-<gender>-<weapon>`. After the dialect drifted, the
2-arg delegate's `NOT EXISTS` guard tested a string the rebuild had just
changed, and stopped seeing the row it was meant to protect.

A manual cleanup deleted 62 duplicate rows on 2026-08-28 at 15:50; the 16:43
sync recreated 68. **A data-only repair does not hold** while the function that
creates the collision is still live.

## Decision

### 1 · A `CREATED`/`PLANNED` event carries event-level facts only

The 2-arg `fn_ingest_evf_calendar`'s entire weapon-loop `INSERT INTO
tbl_tournament` block is deleted. A bracket is created by exactly one thing:
results ingestion, via `fn_find_or_create_tournament`. Calendar discovery never
creates one. This is the whole behavioral change; everything else in the
function (identity pre-check, `fn_allocate_evf_event_code`,
`CURRENT_SLOT_REUSE`/`CREATE`) is unchanged.

This closes the defect completely rather than containing it: there is no
longer a stub for a real bracket to collide with, on the first sync or the
fiftieth.

### 2 · One shared implementation of the ADR-046 code formula

`fn_rebuild_tournament_codes(p_id_event, p_new_event_code)` is extracted from
`fn_update_event`'s existing shape-sniffing block (migration `20260902000002`),
which already distinguishes canonical (`-V\d-` present) from placeholder
dialect and rebuilds accordingly. Two hardenings over **both** prior
copies — `fn_update_event`'s own block and
`fn_ingest_evf_calendar_identity_v1`'s inline one:

- the sniff is `bool_or()` across **all** of an event's children instead of an
  unordered `LIMIT 1` sample, which could pick the wrong dialect when a stub
  and a real bracket briefly coexisted;
- every child is parked on a neutral placeholder (`'__tcode_' ||
  id_tournament`) **before** any of them is rebuilt, so an A→B, B→C shuffle
  within one event cannot have one child's new code collide with a sibling's
  still-old one.

`fn_update_event` and `fn_ingest_evf_calendar_identity_v1` both call the shared
helper now, so the admin rename path and the calendar reflow path agree by
construction rather than by two people remembering to keep two copies in sync.

### 3 · The existing stubs are pruned, guarded exactly as measured

`fn_prune_bracket_stubs()` deletes a `tbl_tournament` row only when **all** of:
its event is non-terminal (`CREATED/PLANNED/SCHEDULED/CHANGED/CANCELLED`);
`enum_import_status = 'PLANNED'`; `int_participant_count` is 0 or NULL;
`url_results IS NULL`; no `tbl_result` row references it; no
`tbl_tournament_ingest_history` row references it. Measured reach 2026-09-12:
**CERT 154 rows / 19 events, PROD 82 rows / 18 events**, zero rows anywhere
failing only one of these six guards — the predicate is neither accidentally
narrow nor accidentally wide.

Called from the migration for CERT/PROD, and from `seed_post_backfill.sql` for
a fresh bootstrap — migrations run **before** the seed dump on CI and
`scripts/reset-dev.sh` (the ADR-036 amendment of 2026-07-14), so a
migration-only delete would be reinstated by the dump. Same pattern as
ADR-091's `fn_prune_unclaimed_evf_skeletons`, one layer up.

### 4 · No uniqueness index — considered, deliberately not added

A `UNIQUE` index on `(id_event, enum_age_category, enum_gender, enum_weapon)`
would convert a recurrence of this defect into a local insert failure instead
of a delayed renumber-time collision, and the tuple is already the natural key
`fn_find_or_create_tournament` treats it as — PROD has zero violations across
all 788 scored rows, including all three joint-pool splits.

It was not added. At least four pre-existing pgTAP fixtures
(`01_database_foundation`, `02_scoring_engine`, `03_views_api`,
`05_calendar_view`) deliberately share **one** throwaway event across several
synthetic tournaments distinguished only by `enum_type` — all at
`(V2, M, EPEE)` — to exercise the scoring formula for different tournament
types and participant counts without creating six throwaway events. The index
broke all four the first time it was tried. Decisions 1–3 above already remove
the defect completely without it; the index would have been pure hardening
against a class of bug that can no longer occur through the code path it
guarded. Worth reconsidering if those fixtures are ever untangled from their
shared-event convention.

## Alternatives considered

1. **Fix only the code-rebuild dialect and the delegate's string guard, keep
   the stub loop.** This was the plan's first framing. Rejected once measured
   against the design's own stated purposes: every one had already expired
   (§Context), the predicted shape was provably wrong regardless of dialect,
   and containing the collision would still leave every future EVF event
   acquiring 4–6 fictional V2 rows — the same class ADR-091 had just ruled
   against for events.
2. **Canonicalize the placeholder dialect everywhere instead of removing the
   stubs.** Rejected: PROD's entire current season (2026-2027) is
   placeholder-shaped and every settled season is canonical; rewriting 82 live
   PROD rows to fix a bug in the rebuild formula would be disproportionate,
   and the placeholder shape only existed to serve the stub creation this ADR
   removes.
3. **Add the uniqueness index despite the fixture conflict, and fix the four
   fixtures.** Rejected as out of scope: those fixtures test the scoring
   engine and unrelated views, not the calendar ingest, and untangling their
   shared-event convention across four files is a separate piece of work with
   its own risk, for a hardening this fix does not need.

## Consequences

**New:**

- `supabase/migrations/20260913000002_no_bracket_stubs.sql` — redefines the
  2-arg `fn_ingest_evf_calendar` and `fn_ingest_evf_calendar_identity_v1`,
  refactors `fn_update_event`, adds `fn_rebuild_tournament_codes` and
  `fn_prune_bracket_stubs()`.
- `supabase/tests/79_no_bracket_stubs.sql` — plan-test-IDs 79.1–79.6.

**Changed:**

- `supabase/seed_post_backfill.sql` — calls `fn_prune_bracket_stubs()` after
  the dump loads, mirroring the season-skeleton prune's own ordering fix.
- `supabase/tests/18_evf_event_allocator.sql` — evf.37 reversed in place
  (2 tournaments → 0 tournaments), no assertion-count change.
- `frontend/src/lib/calendarMonths.ts` — `INTL_PREFIXES` gains `DMEW`, so
  `DMEW-2025-2026` keeps its international calendar styling once it is
  childless and `bool_has_international` can no longer supply it.
- `frontend/tests/calendarMonths.test.ts` — CQ.20 extended with the `DMEW`
  case.

**Test impact.** pgTAP 1019 → 1026 assertions, all passing on a database
rebuilt from scratch (`./scripts/reset-dev.sh`) so the seed-ordering fix in
`fn_prune_bracket_stubs()`'s second call site is exercised, not assumed.
pytest 1245 passed (unchanged — no Python file touched; `evf_sync.py`'s call
contract to `fn_ingest_evf_calendar` is unchanged). vitest 875 passed (unchanged
file count; 122 in `calendarMonths.test.ts` including the new case).
`svelte-check` 0 errors. `postgrestools check` 0 findings on the migration and
seed files (pgTAP test files carry a pre-existing baseline of pgtap-extension
typecheck noise unrelated to this change, reproduced identically on an
untouched file).

**Deployed and verified (2026-09-13).** The migration ran on CERT and PROD
through the standard `main` release pipeline (`integration/main` → `main`,
CI green, `deploy-cert`/`deploy-prod` both green, security posture verified
on both). A direct query against each confirms zero non-terminal event holds
a child tournament: CERT 31/31 events (`PLANNED`/`CREATED`) at `n_children =
0`, PROD the same 31/31. The manually-dispatched **EVF Calendar + Results
Sync** workflow (`workflow_dispatch`, `mode=calendar`) completed with no
`23505` and Athens correctly synced at `PEW13es-2026-2027` among `0 new, 18
already in CERT` — the exact regression this ADR fixes, reproduced clean.

**Noted, not fixed here.** PROD's mirror never rebuilds child tournament
codes on a CERT→PROD sync (it copies event fields only), so PROD still carries
a second generation of duplicate-shaped rows under stale numbers (e.g.
`PEW7efs-*` beneath current event `PEW7es`) from before this fix landed. It has
not collided because PROD never renumbers. Worth its own look if PROD's mirror
is ever asked to.
