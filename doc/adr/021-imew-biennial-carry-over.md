# ADR-021: IMEW Biennial Carry-Over

**Status:** Accepted; **amended 2026-04-26 by ADR-042** (mechanism updated to FK-based when EVENT_FK_MATCHING engine is active)
**Date:** 2026-04-04 (M10)

## Amendment (2026-04-26 — ADR-042 Phase 1B)

This ADR's *rule* — "IMEW results carry biennially" — is unchanged.

The *mechanism* is now engine-dependent (per `tbl_season.enum_carryover_engine`):

- **EVENT_CODE_MATCHING** (legacy, default): rules-based prefix matching as documented below. Type in `rules_types` AND prefix not in `completed_positions` → carry. Works automatically for biennial events because off-year seasons have no event with the matching prefix.
- **EVENT_FK_MATCHING** (Phase 1B opt-in): explicit `tbl_event.id_prior_event` FK linkage. Biennial carry requires a placeholder current-season event whose `id_prior_event` points to last season's IMEW. Until Phase 3 ships `fn_init_season` (which auto-creates these placeholders), admin must manually insert/link placeholders for biennial events. Without the explicit link, biennial carry-over does NOT fire under FK engine.

The A/B comparison helper (`fn_compare_carryover_engines`) surfaces this divergence pre-flip so admin can fix data first.

## Context

IMEW (Indywidualne Mistrzostwa Europy Weteranów / Individual European Veterans Championships, tournament type `MEW`) is a **biennial** event — it takes place every two years. It occurred in the 2024-25 season and will **not** occur in 2025-26. In off years, DMEW (Drużynowe Mistrzostwa Europy Weteranów / Team European Veterans Championships) takes place instead, but SPWS does not track team results.

The seed data regeneration from Excel workbooks incorrectly included IMEW-2025-2026 tournament data extracted from carry-over columns in the ranking spreadsheets. This data represents results that were carried forward in the Excel-based system, not actual 2025-26 tournament results. The automated system handles carry-over via the rolling score mechanism (ADR-018), making these phantom tournament entries both incorrect and redundant.

ADR-018's original carry-over constraint required a **declared event** (any status) in the current season for position-matched carry-over. This meant IMEW results would only carry over if a dummy SCHEDULED IMEW event existed in the off-year season — semantically wrong (IMEW is not scheduled) and an operator burden.

## Decision

**Rules-based carry-over:** Change the rolling score carry-over constraint from "position must be declared as an event in the current season" to "tournament type must appear in the season's `json_ranking_rules` buckets."

### Modified carry-over logic

Previous (ADR-018 original):
```sql
-- Carry over if position is declared but not completed
AND fn_event_position(e.txt_code) IN (SELECT pos FROM declared_positions)
AND fn_event_position(e.txt_code) NOT IN (SELECT pos FROM completed_positions)
```

New:
```sql
-- Carry over if tournament type is in ranking rules AND position is not completed
AND t.enum_type::TEXT IN (SELECT type_code FROM rules_types)
AND fn_event_position(e.txt_code) NOT IN (SELECT pos FROM completed_positions)
```

Where `rules_types` extracts all tournament types from the relevant `json_ranking_rules` section (`'domestic'` for `fn_ranking_ppw`, `'international'` for `fn_ranking_kadra`, both for `fn_fencer_scores_rolling`).

### Concrete effect

| Scenario | Previous behavior | New behavior |
|----------|------------------|--------------|
| IMEW in off year (no event declared) | Dropped — no declared position | **Carried over** — MEW is in international rules |
| PPW5 not yet played (SCHEDULED event) | Carried over — declared position | Carried over — PPW in rules, PPW5 not completed |
| PPW1 already played (COMPLETED) | Not carried — position completed | Not carried — PPW1 completed |
| Random type not in rules | Not carried — no declared position | Not carried — type not in rules |

### Implementation

1. **Strip IMEW-2025-2026** from 16 seed files in `supabase/data/2025_26/` — no IMEW tournament took place this season
2. **Modify 3 migration files** to replace `declared_positions` with `rules_types`:
   - `20260330000001_ranking_ppw_rolling.sql` — `fn_ranking_ppw` (domestic rules)
   - `20260330000002_ranking_kadra_rolling.sql` — `fn_ranking_kadra` (international rules)
   - `20260330000003_fencer_scores_rolling.sql` — `fn_fencer_scores_rolling` (both)
3. **No SCHEDULED event needed** — carry-over is automatic when type is in rules

## Alternatives Considered

1. **SCHEDULED event placeholder** — Add a dummy SCHEDULED IMEW event in off-year seasons. Works with existing code but semantically wrong (IMEW is not scheduled), creates operator burden, and clutters the calendar view with events that won't happen.

2. **Don't carry over IMEW in off years** — Rejected. International fencers who competed in IMEW would lose significant ranking points during the off year, creating an unfair gap in kadra rankings. The Excel-based system carried these results forward, and the automated system should maintain parity.

3. **Keep IMEW-2025-2026 as COMPLETED with Excel carry-over data** — Rejected. This conflates carry-over with actual results, making it impossible to distinguish real tournament participation from inherited scores.

## Consequences

- IMEW scores from the previous season automatically contribute to rolling kadra rankings during off years — no operator action needed
- Carry-over is now driven by `json_ranking_rules` rather than event declarations — more robust and self-documenting
- `declared_positions` CTE removed from all 3 rolling functions, replaced by `rules_types`
- `completed_positions` CTE retained — completed events still block carry-over (correct behavior)
- ADR-018's three-state table updated: "not declared → dropped" becomes "type not in rules → dropped"
- Pattern is fully automatic for any biennial/triennial event whose type is in the rules
- 16 seed files stripped of phantom IMEW-2025-2026 data
- 3 new pgTAP tests (R.19–R.21) verify IMEW biennial carry-over behavior
