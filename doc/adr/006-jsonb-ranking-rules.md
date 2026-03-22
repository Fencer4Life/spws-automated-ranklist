# ADR-006: JSONB Bucket-Based Ranking Rules

**Status:** Accepted
**Date:** 2025-03-05 (M5/M6)

## Context

The ranking aggregation logic (best-K PPW, always-include MPW, best-J international pool) was initially hardcoded as integer columns in `tbl_scoring_config` (`int_ppw_best_count`, `bool_mpw_droppable`, `int_pew_best_count`, `bool_mew_droppable`). Adding PSW as a new tournament type would have required a schema migration to add columns for every new type.

## Decision

Add `json_ranking_rules JSONB` to `tbl_scoring_config`. The JSONB value defines **buckets** — groups of tournament types with a selection rule (`best: N` or `always: true`). The ranking functions (`fn_ranking_ppw`, `fn_ranking_kadra`) iterate buckets dynamically via `jsonb_array_elements`.

```json
{
  "domestic": [
    {"types": ["PPW"], "best": 4},
    {"types": ["MPW"], "always": true}
  ],
  "international": [
    {"types": ["PPW"], "best": 4},
    {"types": ["MPW"], "always": true},
    {"types": ["PEW", "MEW", "MSW"], "best": 3}
  ]
}
```

## Dual Code Path

- `json_ranking_rules = NULL` (SPWS-2023-2024): legacy hardcoded K/J logic
- `json_ranking_rules` populated (SPWS-2024-2025+): JSONB bucket selection

Both paths coexist — historical seasons keep their NULL value and legacy behaviour.

## Consequences

- Adding new tournament types (PSW, future types) requires no schema migration — just edit the JSONB
- Rules are version-controlled per season in `supabase/data/{season}/season_config.sql`
- No redeployment needed when rules change — pure data update
- Trade-off: JSONB is less strictly typed than dedicated columns — validation is at application level
- Trade-off: two code paths in ranking functions (legacy + JSONB) increase complexity
