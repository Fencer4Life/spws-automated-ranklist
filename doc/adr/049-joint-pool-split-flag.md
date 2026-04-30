# ADR-049: Joint-pool split flag on tbl_tournament

**Status:** Accepted; implemented LOCAL/CERT/PROD 2026-04-30. Backfill executed on all three; ingester contract enforced by pytest.
**Date:** 2026-04-30
**Relates to:** ADR-024 (Combined Category Splitting), ADR-038 (per-cat field count), ADR-047 (V-cat invariant trigger), ADR-048 (Source-vs-DB audit). Supersedes the "Joint-pool reference field — also deferred" subsection of ADR-048.

## Context

A "joint pool" is a competition that physically runs N veteran fencers in one shared pool but is RANKED per V-cat. Each V-cat slice must be a separate `tbl_tournament` row because scoring and ranklists are per V-cat. Two related bugs surfaced 2026-04-30:

1. **PPW4 women epee** — V0 + V1 ran as one 7-fencer pool; both rows had the same `url_results`. The splitter ran but `int_participant_count` on each row stored the V-cat slice (4 and 3) instead of the full pool (7). Gabriela KAMIŃSKA's V1 ranking points came out 96.35 instead of 97.22.
2. **PPW5 women epee** — V0/V1/V2/V4 ran as one 11-fencer pool, but the source published separate FTL URLs per V-cat slice. The splitter never ran (no shared-URL signal) and counts were V-cat-slice only.

Pre-this-ADR there was no explicit schema relationship saying "these sibling rows are the same physical pool." Pool membership had to be inferred from URL equality — works for case 1, fails for case 2.

## Decision

### Schema

`tbl_tournament.bool_joint_pool_split BOOLEAN NOT NULL DEFAULT FALSE`

- TRUE on every sibling row that is one V-cat slice of a physically combined pool.
- Siblings are identified by the tuple `(id_event, enum_weapon, enum_gender, url_results)` — all four equal across all members of the pool.
- `int_participant_count` on every sibling = full physical pool size (sum of `tbl_result` rows across all siblings of that pool).
- All siblings are equal — there is no parent row, no FK, no asymmetry.

Partial index `idx_tbl_tournament_joint_split` on `(id_event, enum_weapon, enum_gender) WHERE bool_joint_pool_split = TRUE`.

Migration: `supabase/migrations/20260430000003_joint_pool_split.sql`.

### Ingester contract (`scrape_tournament.py`)

When `len(siblings) > 1` (joint pool):

1. After the V-cat split, every sibling whose bucket is empty is **DELETEd** (admin-registration mistake — admin pasted the URL on a row that has zero fencers in the actual source). A Telegram alert is sent per delete.
2. Each remaining sibling has the same `url_results` (already true at this stage — that's how siblings were identified) and is PATCHed to `bool_joint_pool_split = TRUE`.
3. `fn_ingest_tournament_results` is called per remaining sibling with `p_participant_count = len(parsed_rows)` (the full physical pool size, from the single source scrape).

When `len(siblings) == 1` (solo tournament): legacy behaviour unchanged — `p_participant_count = len(bucket_rows)` (which equals `len(parsed_rows)` modulo unresolveds).

The pure decision logic lives in [`plan_joint_pool_actions`](../../python/tools/scrape_tournament.py) so it is unit-testable independently of the HTTP layer.

### Backfill function (one-shot remediation)

`fn_backfill_joint_pool_split()` flips the flag and recomputes the count on pre-existing PPW4-class rows that share `url_results` with a sibling under the same `(id_event, enum_weapon, enum_gender)`. Idempotent — the WHERE clauses skip rows already in the target state. Migration: `supabase/migrations/20260430000004_fn_backfill_joint_pool_split.sql`.

PPW5-class rows (per-V-cat URLs, single physical pool) cannot be detected from existing DB state. They will be fixed naturally on the from-scratch re-scrape, where the ingester contract above sets the flag directly.

## Alternatives considered

- **Self-referential FK** (`id_joint_pool_parent INT REFERENCES tbl_tournament`). Drafted and applied to LOCAL earlier in the same session; reverted. Reasons rejected: introduces parent/child asymmetry where none exists in the domain (every V-cat slice is equally a "child" of the physical pool); arbitrary "lowest id_tournament wins" tie-break; more complex backfill (requires regex on scraped names for marker detection); harder admin UI (which row is the parent?).
- **Separate join table** `tbl_joint_pool (id_pool, id_tournament)`. Rejected as overkill — every tournament sits in at most one joint pool, so a 1-N relationship encoded with a flag + the existing `url_results` column is sufficient.
- **Inferring joint-ness at query time from `url_results` equality alone** (no flag). Rejected: the flag is a positive intent signal recorded by the ingester at write time, distinguishing a real joint pool from a coincidental URL collision. It also simplifies admin UI predicates.
- **Keep empty siblings of a joint pool** (Option B in the implementation discussion). Rejected: the row is a registration-time mistake (admin pasted the URL on a V-cat with zero entrants in the actual source); leaving it pollutes the calendar and ranklists with an empty sub-tournament. Auto-delete is the cleaner invariant ("every sibling has fencers").

## Consequences

- **Backfill ran 2026-04-30 on all three envs.** 86 PPW4-class joint-pool groups detected on each, 206 sibling rows flagged TRUE, 186 `int_participant_count` values rewritten on CERT/PROD (LOCAL was already at 0 net rewrites because the rejected FK-design backfill had already done the count fix earlier the same day). 206 affected tournaments re-scored on each via `fn_calc_tournament_scores`. Gabriela's PPW4-V1-F-EPEE-2025-2026 row: N=7, points=97.22 on LOCAL, CERT, PROD.
- **PPW5-class is NOT fixed by the backfill** — those rows will be corrected on the from-scratch re-scrape next.
- **Empty-sibling auto-delete** is a behaviour change relative to the prior ingester. It is gated on `len(siblings) > 1` so solo tournaments are never affected. The Telegram alert per deletion ensures admin is notified.
- **Admin UI** can surface a single read-only "joint pool" badge per tournament row from the boolean. No parent/child navigation needed.
- **Scoring engine** (`fn_calc_tournament_scores`) is unchanged — it consumes `int_participant_count`, which is now correct on every sibling.
- **The deferred "joint-pool reference field" subsection of ADR-048 is superseded** by this ADR; the FK design proposed there is rejected.

## Tests

- pgTAP `25_joint_pool_split.sql` — 7 tests:
  - 25.1 column shape
  - 25.2 partial index
  - 25.3 backfill function exists
  - 25.4 siblings flagged
  - 25.5 counts rewritten to full pool size
  - 25.6 standalone with unique URL untouched
  - 25.7 backfill is idempotent
- pytest `test_scrape_tournament_joint_pool.py` — 4 tests:
  - 26.1 plan: joint, both buckets non-empty → flag both, delete none
  - 26.2 plan: joint, V2 bucket empty → V2 in to_delete, V0/V1 in to_flag
  - 26.3 plan: solo → is_joint=False, no actions
  - 26.4 main(): full integration on joint pool with empty sibling — DELETE on V2, PATCH `bool_joint_pool_split=TRUE` on V0/V1, POST `p_participant_count = len(parsed_rows)` on each non-empty sibling

Coverage updates: pgTAP totals +7; pytest totals +4 (354 passing, 9 skipped).
