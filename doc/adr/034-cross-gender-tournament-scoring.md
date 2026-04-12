# ADR-034: Cross-Gender Tournament Scoring

**Status:** Implemented (automated enforcement via `fn_effective_gender`)  
**Date:** 2026-04-11 (documented) · 2026-04-12 (implemented)  
**Source:** FR-92, ADR-033

## Context

In veterans fencing, tournaments are sometimes joined across genders when there are insufficient participants for a separate women's category. This means a woman may appear in a men's tournament result. The system needs rules for how to handle scoring in these cases.

## Decision

Cross-gender tournament participation has **asymmetric** scoring rules:

### Man in women's tournament
Points **never count** for any ranklist. Dropped entirely, no exceptions.

### Woman in men's tournament
Depends on whether a corresponding women's tournament exists at the same event for that weapon:

1. **No corresponding women's tournament exists** (inter-gender joined tournament due to insufficient participants) — the woman's points are **moved to the women's ranklist** (removed from men's ranklist).
2. **A corresponding women's tournament exists** at the event for that weapon — the woman's points from the men's tournament are **dropped entirely** (not counted for any ranklist — she should have competed in the women's tournament).

### Enforcement

**Automated** at ranking query time via `fn_effective_gender` helper function. The function is called inline in every ranking function (`fn_ranking_ppw`, `fn_ranking_kadra`, `fn_fencer_scores_rolling`, `fn_category_ranking`), replacing the raw `t.enum_gender = p_gender` filter.

Scores are not recalculated — `num_final_score` stays as computed at import time (ADR-002). Only the ranklist assignment changes.

Admin can still review gender mismatches via the Identity Manager UI (ADR-033).

## Alternatives

- **Automated enforcement at ingest time** — deferred due to complexity; requires checking sibling tournaments at the same event, which the ingest pipeline doesn't currently do.
- **Block cross-gender results entirely** — rejected; joined tournaments are legitimate and the woman's points should count when no women's alternative exists.
- **Symmetric rules (both genders same)** — rejected; men in women's tournaments never earn points per federation rules.

## Related ADRs

- **ADR-024** (Combined Category Splitting) — handles mixed age categories (V0V1) in the same tournament; this ADR handles mixed genders. Both share the pattern of needing to split/reassign results when the source data doesn't match the ranking model's per-category/per-gender structure.
- **ADR-033** (Fencer Gender + Identity Enhancements) — adds `enum_gender` to `tbl_fencer` and the Identity Manager UI that surfaces gender mismatches for admin review. Prerequisite for future automated enforcement of this ADR's rules.
- **ADR-003** (Identity by FK) — fencer identity is tracked by FK, not name. Gender is a new attribute on the fencer entity that supplements identity resolution.
- **ADR-025** (Event-Centric Ingestion + Telegram Admin) — the ingestion pipeline that creates tournament results. Future enforcement of cross-gender rules would be added at this layer.

## Consequences

- Admin can still review gender mismatches flagged in the Identity Manager (ADR-033)
- Automated enforcement via `fn_effective_gender` helper + ranking function filters (see implementation plan below)

---

## Implementation Plan (2026-04-12)

### Approach: `fn_effective_gender` helper function

A pure SQL function that computes the "effective gender" for a single result row, encoding all four ADR-034 rules:

```sql
fn_effective_gender(
  p_fencer_gender    enum_gender_type,   -- from tbl_fencer.enum_gender
  p_tournament_gender enum_gender_type,  -- from tbl_tournament.enum_gender
  p_id_event         INT,               -- tournament's parent event
  p_weapon           enum_weapon_type,   -- for sibling check
  p_age_category     enum_age_category   -- for sibling check
) RETURNS enum_gender_type  -- NULL = dropped, 'F'/'M' = effective ranklist
```

Logic:
1. `fencer_gender IS NULL OR matches tournament` → return tournament gender (normal)
2. `fencer = M, tournament = F` → return NULL (always dropped)
3. `fencer = F, tournament = M` → check for sibling F tournament at same event/weapon/category:
   - Sibling exists → NULL (dropped — she should have competed there)
   - No sibling → `'F'` (reassigned to women's ranklist)

The EXISTS subquery only fires for the rare cross-gender case; normal results short-circuit.

### Filter replacement (10 sites → 1-line change each)

Every `AND t.enum_gender = p_gender` becomes:

```sql
AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
```

### Files to modify

**New migration:** `supabase/migrations/20260412000002_cross_gender_scoring.sql`

Contains:
1. `fn_effective_gender` — new helper function (STABLE, SECURITY DEFINER)
2. `fn_ranking_ppw` — DROP + CREATE replacing 3 gender filters (lines 81, 186, 209)
3. `fn_ranking_kadra` — DROP + CREATE replacing 3 gender filters (lines 96, 209, 232)
4. `fn_fencer_scores_rolling` — DROP + CREATE replacing 2 gender filters (lines 109, 136)
5. `fn_category_ranking` — CREATE OR REPLACE replacing 1 gender filter (line 40)

Note: `fn_category_ranking` does not join `tbl_fencer` today — must add the join.

**Return columns unchanged:** `fn_fencer_scores_rolling` still returns `t.enum_gender` (the original tournament gender) so the UI shows the actual tournament code. Only the filtering uses effective gender.

### pgTAP tests

New test file: `supabase/tests/04_cross_gender_scoring.sql`

Tests:
1. `fn_effective_gender` unit tests — all 4 rules (match, M-in-F, F-in-M-no-sibling, F-in-M-with-sibling)
2. Woman in M tournament with no F sibling → appears in F ranking, not M ranking
3. Woman in M tournament with F sibling → appears in neither ranking
4. Man in F tournament → appears in neither ranking
5. Fencer with NULL gender → appears in tournament's declared gender ranking (backwards-compatible)
6. Rolling carry-over: carried-over cross-gender result still filtered correctly
7. Kadra: cross-gender filter applies to international results too

### Verification

```sql
-- After reset: Martyna in F sabre V1 ranking (via PPW5-V1-M-SABRE reassignment)
SELECT * FROM fn_ranking_ppw('SABRE', 'F', 'V1');
-- Expected: SAMECKA-NACZYŃSKA appears

SELECT * FROM fn_ranking_ppw('SABRE', 'M', 'V1');
-- Expected: SAMECKA-NACZYŃSKA does NOT appear

-- Direct helper check
SELECT fn_effective_gender('F', 'M', 
  (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW5-2025-2026'),
  'SABRE', 'V1');
-- Expected: 'F' (no sibling F tournament)
```

### Seed data prerequisite

PPW5-V1-M-SABRE-2025-2026 must exist in local seed data (`supabase/data/2025_2026/v1_m_sabre.sql`) with Martyna's result for verification to work. Add it as part of implementation.
