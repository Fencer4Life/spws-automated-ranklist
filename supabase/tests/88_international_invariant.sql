-- =============================================================================
-- INTL.INV — a standing check on stored international results (ADR-105 §5.8)
-- =============================================================================
-- An international tournament's N is the whole source bracket and each place
-- is the fencer's own place in it, so no stored place can be above N. The
-- ingest RPC refuses such a write (INTL.RPC.04); this checks the data itself,
-- whichever path wrote it, including the draft commit.
--
-- It cannot see the older damage, where N was recounted to the Polish rows and
-- the places renumbered to fit (1..K of K). That is found against the source:
-- the Phase 5 staging summary flags a bracket whose N equals its Polish rows.
-- =============================================================================

BEGIN;

SELECT plan(1);

SELECT is(
  (SELECT count(*)
     FROM tbl_result r
     JOIN tbl_tournament t USING (id_tournament)
    WHERE t.enum_type IN ('PEW', 'MEW', 'MSW', 'PSW')
      AND r.int_place > t.int_participant_count),
  0::BIGINT,
  'INTL.INV.01 no international result has a place above its tournament''s N');

SELECT * FROM finish();
ROLLBACK;
