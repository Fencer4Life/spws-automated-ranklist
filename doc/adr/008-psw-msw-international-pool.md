# ADR-008: PSW and MSW in International Ranking Pool

**Status:** Amended (2026-04-05)
**Date:** 2025-03-05 (M6)

## Context

The original spec defined the international ranking pool (Kadra) as PEW + MEW only. Two additional tournament types needed inclusion:
- **MSW** (World Veterans Championship) — high-prestige, multiplier 2.0
- **PSW** (FIE Veterans World Cup) — announced by FIE but **not yet held**; enum value reserved

## Decision

Include MSW in the international ranking pool alongside PEW and MEW. All three types compete together in a single `best-J` bucket via `json_ranking_rules`:

```json
{"types": ["PEW", "MEW", "MSW"], "best": 3}
```

**PSW is reserved but not active.** FIE has announced a Veterans World Cup (PSW) but no event has taken place yet. The `PSW` enum value exists in `enum_tournament_type` for forward compatibility. When PSW events begin, add `"PSW"` to the international bucket in `season_config.sql` — no code changes needed thanks to ADR-006 (JSONB bucket rules).

**EVF Criterium Mondial (formerly coded as PS/PSW)** is actually an EVF event, not FIE. It uses tournament type `PEW` and event code `PEW10` (2025-26 season onward).

This was enabled by ADR-006 (JSONB bucket rules) — no schema migration was needed, only a data change in `season_config.sql`.

## Schema Changes

- `enum_tournament_type`: `PSW` value exists (reserved for future FIE events)
- `tbl_scoring_config`: `num_psw_multiplier` column (default 2.0, unused until PSW events occur)

## Consequences

- MSW results scored with 2.0 multiplier appear in Kadra ranking automatically
- The combined pool means PEW, MEW, and MSW results compete for the same best-J slots
- PSW can be activated per-season by adding it to `json_ranking_rules` when FIE starts the World Cup
- No change to `fn_ranking_kadra` SQL — the JSONB bucket path handles arbitrary type lists
- V0 guard remains: no Kadra ranking for V0 (no EVF equivalent regardless of tournament types)
- EVF Criterium Mondial uses PEW type, not PSW — it is an EVF circuit event