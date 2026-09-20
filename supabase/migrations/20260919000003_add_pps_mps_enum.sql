-- =============================================================================
-- Add PPS and MPS to enum_tournament_type
-- =============================================================================
-- Delivery step 6 of doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html,
-- pulled forward per doc/plans/did-you-plan-to-optimized-penguin.md: the Admin
-- UI has no way to enter PPS/MPS multipliers, and design steps 2-3a already
-- removed the hardcoded six-way CASE blocks that made a new type expensive
-- (ADR-087 open item 1 is now partially stale — see its amendment note).
--
-- PPS = Puchar Polski Seniorów (Polish Seniors Cup)
-- MPS = Mistrzostwa Polski Seniorów (Polish Seniors Championship)
-- Both are PZSz national senior events; a veteran fencer's result in one
-- scores as a voluntary senior bonus (§07). SENIOR-bracket ingestion itself is
-- delivery step 6's PZSz flow, not this migration.
--
-- SPLIT INTO TWO MIGRATIONS ON PURPOSE (§11). A new enum value cannot be used
-- in the transaction that adds it — PSW's own precedent
-- (20250305000002:20) only appears to use 'PSW' immediately because that use
-- is inside a function body, parsed at CALL time, never evaluated during this
-- transaction. This migration adds ONLY the two enum values. Everything that
-- USES them — the multiplier columns, the type-config rows, the readers —
-- is 20260919000004.
-- =============================================================================

ALTER TYPE enum_tournament_type ADD VALUE IF NOT EXISTS 'PPS';
ALTER TYPE enum_tournament_type ADD VALUE IF NOT EXISTS 'MPS';
