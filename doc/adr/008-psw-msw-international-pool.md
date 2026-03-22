# ADR-008: PSW and MSW in International Ranking Pool

**Status:** Accepted
**Date:** 2025-03-05 (M6)

## Context

The original spec defined the international ranking pool (Kadra) as PEW + MEW only. Two additional tournament types needed inclusion:
- **MSW** (World Veterans Championship) — high-prestige, multiplier 2.0
- **PSW** (Polish Veterans Championship) — national championship, multiplier 2.0

## Decision

Include MSW and PSW in the international ranking pool alongside PEW and MEW. All four types compete together in a single `best-J` bucket via `json_ranking_rules`:

```json
{"types": ["PEW", "MEW", "MSW", "PSW"], "best": 3}
```

This was enabled by ADR-006 (JSONB bucket rules) — no schema migration was needed, only a data change in `season_config.sql`.

## Schema Changes

- `enum_tournament_type`: added `PSW` value
- `tbl_scoring_config`: added `num_psw_multiplier` column (default 2.0)

## Consequences

- PSW and MSW results scored with 2.0 multiplier appear in Kadra ranking automatically
- The combined pool means PEW, MEW, MSW, and PSW results compete for the same best-J slots
- No change to `fn_ranking_kadra` SQL — the JSONB bucket path handles arbitrary type lists
- V0 guard remains: no Kadra ranking for V0 (no EVF equivalent regardless of tournament types)
