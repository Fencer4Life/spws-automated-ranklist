# ADR-034: Cross-Gender Tournament Scoring

**Status:** Deferred (documented, enforcement not implemented)  
**Date:** 2026-04-11  
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

**Deferred** — the system does not currently check or reassign points automatically. The admin must:
1. Identify gender mismatches via the Identity Manager UI (ADR-033 adds gender mismatch highlighting)
2. Manually verify whether a corresponding women's tournament exists at the event
3. Take appropriate action (dismiss the result, or ensure it's counted in the women's ranklist)

Future implementation should add automated gender-aware scoring at ingestion or scoring time.

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

- No code changes in this ADR (documentation only)
- Admin must manually review gender mismatches flagged in the Identity Manager
- Future work: automated scoring reassignment based on sibling tournament check at event level (analogous to ADR-024's category splitting)
