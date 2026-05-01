# Phase 6 — Drop tbl_match_candidate + remove old UI + finalize + promote (M)

**Prerequisites:** Phase 5 ([p5-execute.md](p5-execute.md)) — operational rebuild complete, all events committed or marked `FROZEN_SNAPSHOT`.

## Goal

Finalize the rebuild. Drop the obsolete `tbl_match_candidate` infrastructure. Remove the old identity UI. Update Claude-guidance modules. Promote LOCAL → CERT → PROD.

## Deliverables

### Database — drop obsolete infrastructure

- Migration: `supabase/migrations/2026MMDD_drop_match_candidate.sql`
  - `DROP TABLE tbl_match_candidate CASCADE`
  - Drop `vw_match_candidates`
  - Drop the four identity RPCs:
    - `fn_approve_match`
    - `fn_dismiss_match`
    - `fn_create_fencer_from_match`
    - `fn_undismiss_match`
- Rewrite [supabase/tests/11_identity_resolution.sql](../../../supabase/tests/11_identity_resolution.sql) against the new model (alias-based assertions).

### Frontend — remove old identity UI surface

- Delete [frontend/src/components/IdentityManager.svelte](../../../frontend/src/components/IdentityManager.svelte).
- Remove old API wrappers from [frontend/src/lib/api.ts](../../../frontend/src/lib/api.ts):
  - `getMatchCandidates`
  - `approveMatch`
  - `dismissMatch`
  - `createFencerFromMatch`
  - `undismissMatch`
- Remove `MatchCandidate` types from [frontend/src/lib/types.ts](../../../frontend/src/lib/types.ts).
- Remove route from [frontend/src/App.svelte](../../../frontend/src/App.svelte).
- Update/delete affected tests in [frontend/tests/api.test.ts](../../../frontend/tests/api.test.ts).
- Archive `doc/mockups/m8_identity_resolution.html` → `doc/mockups/archive/`.

### Seed files

- Update remaining seed files to remove `COPY tbl_match_candidate`.
- Re-export LOCAL → `seed_local_<date>.sql`.

### Promotion

- Promote to CERT (validate); promote to PROD (validate).

### ADRs

- Finalize ADRs **050-054**.
- Mark superseded ADRs **024, 025, 039, 049** with header.

### Memory

- **Reactivate "no delete without per-row approval"** memory rule — waiver from ADR-051 expires here.

### Claude-guidance modules — finalize (post-rebuild)

- [doc/claude/conventions.md](../../claude/conventions.md) — remove rebuild waiver note; affirm `tbl_match_candidate` removal as permanent; URL-validation enforced; alias write-back canonical.
- [doc/claude/architecture.md](../../claude/architecture.md) — drop rebuild-active banner; document final unified pipeline architecture; remove all references to old per-source orchestration; drop draft-tables-as-temporary section (or note them as standard infra for future ingests).
- [doc/claude/testing.md](../../claude/testing.md) — finalize test commands for new pipeline; remove migration-period notes.
- [doc/claude/documenting.md](../../claude/documenting.md) — verify ADR registry shows 050-054 as accepted, 024/025/039/049 as superseded.
- [doc/claude/key-references.md](../../claude/key-references.md) — update file paths reflecting Phase 6 deletions (IdentityManager, m8 mockup archived). Update "49 ADRs" → "54 ADRs". Remove REBUILD-ACTIVE rows for plan file, overrides directory, and `cert_ref` script.
- Update root CLAUDE.md if any module-level summaries changed.

## Risk gate

- All tests pass with `tbl_match_candidate` absent.
- Old `IdentityManager` removed without dangling imports.
- New `FencerAliasManager` remains functional.
- Seed round-trip works.
- CERT and PROD reflect rebuild output.

## Cross-references

- Master plan: [now-we-have-a-precious-wren.md](/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
- Predecessor: [p5-execute.md](p5-execute.md)
- Successor: [p7-carryover.md](p7-carryover.md) — Phase 7 carry-over completion runs against the now-clean rebuilt data
- ADRs finalized: 050, 051, 052, 053; 054 stub committed (Phase 7 completes it)
- Memory waiver from ADR-051 expires here
