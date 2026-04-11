# ADR-033: Fencer Gender Column + Identity Manager Enhancement

**Status:** Implemented  
**Date:** 2026-04-11  
**Source:** FR-07, FR-56, FR-92

## Context

The `tbl_fencer` table had no gender column. Gender was only tracked at the tournament level (`tbl_tournament.enum_gender`). This caused two problems:

1. **No gender validation** — a woman could appear in men's rankings (and vice versa) with no system-level guard. This happened in practice: a woman's result in a men's V1 sabre tournament appeared in the men's sabre ranklist.
2. **Limited Identity Manager UI** — the admin view only allowed approving PENDING matches (not AUTO_MATCHED), "Create new fencer" was restricted to UNMATCHED domestic tournaments, there was no way to reassign a match to a different existing fencer, and the auto-parse name split had no form for correction.

## Decision

1. **Add `enum_gender` to `tbl_fencer`** — nullable column using existing `enum_gender_type`. Backfilled from tournament participation via majority vote (fencer gets the gender of the tournament type they appeared in most). The fencer's gender in `tbl_fencer` is the **authoritative source** and must never be overwritten by import processes.

2. **Widen identity RPCs** — `fn_approve_match`, `fn_dismiss_match`, and `fn_create_fencer_from_match` now accept `AUTO_MATCHED` status in addition to `PENDING`/`UNMATCHED`.

3. **Add `fn_update_fencer_gender` RPC** — allows admin to set/correct fencer gender.

4. **Update `fn_create_fencer_from_match`** — accepts optional `p_gender` parameter, stored on the new fencer.

5. **Redesign Identity Manager UI**:
   - New **Gender column** with inline M/F dropdown for linked fencers; red highlight on gender mismatch (fencer gender ≠ tournament gender)
   - **"Create new fencer"** button on all <100% confidence rows (removed domestic-only restriction), opens a form modal with editable surname, first name, gender (pre-selected from tournament), and birth year
   - **"Assign fencer"** button opens a searchable modal to pick from all existing fencers
   - **Error messages** displayed inline in the Identity Manager view
   - **Approve/Dismiss** now available for AUTO_MATCHED rows

## Alternatives

- **Add gender as NOT NULL** — rejected because existing fencers lack gender data; nullable allows gradual backfill.
- **Derive gender at query time from tournament** — rejected because fencer gender should be authoritative (see ADR-034 for cross-gender tournament scenarios).
- **Server-side fencer search** — deferred; client-side filtering with max 50 displayed results is sufficient for current data volume.

## Related ADRs

- **ADR-003** (Identity by FK) — gender is a new attribute on the fencer entity, supplementing the FK-based identity model.
- **ADR-014** (Delete-Reimport Strategy) — reimport does not touch `tbl_fencer.enum_gender`; the fencer's gender is authoritative and preserved across reimports.
- **ADR-024** (Combined Category Splitting) — analogous problem for age categories; this ADR addresses gender dimension.
- **ADR-025** (Event-Centric Ingestion + Telegram Admin) — the ingestion pipeline creates match candidates but never sets fencer gender; gender is admin-managed only.
- **ADR-034** (Cross-Gender Tournament Scoring) — documents the scoring rules for cross-gender participation; depends on this ADR's gender column for mismatch detection.

## Consequences

- `tbl_fencer` gains `enum_gender` column (nullable)
- `vw_match_candidates` returns `enum_tournament_gender` and `enum_fencer_gender`
- Gender mismatches are now visible in the admin UI for manual review
- Two new frontend components: `CreateFencerModal.svelte`, `FencerSearchModal.svelte`
- Test count: pgTAP 246→254 (+8), vitest 229→241 (+12)
