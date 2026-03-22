# ADR-002: Calculate Once, Store Forever

**Status:** Accepted
**Date:** 2025-03-01 (M2)

## Context

When tournament results are imported, points must be calculated from the scoring formula. The question was whether to compute points on-the-fly (at query time) or compute once and persist.

## Decision

Points are computed **once** at import time by `fn_calc_tournament_scores` and persisted in `tbl_result` (`num_place_pts`, `num_de_bonus`, `num_podium_bonus`, `num_final_score`). `ts_points_calc` records the calculation timestamp.

## Rationale

1. **Historical integrity** — Multipliers, MP values, or formulas may change between seasons. Stored scores represent the official result under the rules in effect at computation time. On-the-fly recalculation would silently rewrite history.

2. **Audit trail** — `ts_points_calc` shows exactly when scoring happened and under which parameters.

3. **Decoupled pipeline** — Import (Step 1: raw places) and scoring (Step 2: compute points) are separate operations. This allows importing results before the scoring config is finalized.

4. **Explicit recalculation** — If an admin corrects `int_participant_count` or `int_place`, they must explicitly trigger a recalculation. Accidental recalcs are prevented.

## Consequences

- Ranking views simply `SUM(num_final_score)` — no formula logic at query time
- Changing scoring config does NOT retroactively change already-scored tournaments
- Recalculation requires explicit admin action per tournament
- `num_final_score IS NULL` means "imported but not yet scored" — ranking views exclude these rows
