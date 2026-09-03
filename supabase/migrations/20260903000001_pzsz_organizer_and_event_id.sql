-- =============================================================================
-- PZSz as a fourth organizer, and the PZSz source id on tbl_event
-- =============================================================================
-- Polish veterans also enter senior national competitions -- fencing the same
-- pools as people half their age -- run by Polski Zwiazek Szermierczy, the
-- national federation. The calendar carried SPWS (PPW/MPW), EVF (PEW) and FIE
-- (MEW/MSW/PSW) events and nothing at all from PZSz, so a veteran planning to
-- test themselves at a senior national competition had to look elsewhere. This
-- migration makes those events storable. Scoring them is a separate, later
-- deliverable and nothing here anticipates it.
--
-- WHY A MIGRATION AND NOT A SEED EDIT. tbl_organizer rows exist only in the
-- PROD seed dumps (supabase/seed_prod_*.sql:14-16); no migration has ever
-- inserted one. Two constraints decide the vehicle:
--
--   * Migrations run BEFORE the seed dump on CI and on `db reset`, so this
--     insert has to be idempotent and has to survive the seed re-inserting the
--     other three codes moments later. ON CONFLICT (txt_code) DO NOTHING,
--     backed by idx_organizer_code (20250301000001:169), gives both.
--   * python/pipeline/promote.py resolves id_organizer to PROD by code and
--     raises when the code is unresolved (ADR-081).
--
-- The second constraint is an ordering constraint, not a preference: PZSz must
-- exist on CERT and on PROD before the first calendar promote runs, or that
-- promote fails outright. That is why this ships ahead of the scraper.
--
-- THE NAME STAYS POLISH. "Zwiazek" has no clean English equivalent, and the
-- sibling row Stowarzyszenie Polskich Weteranow Szermierki is already stored
-- untranslated.
--
-- WHY id_pzsz_event EARNS A COLUMN. It mirrors the EVF identity columns
-- (id_evf_calendar_event, id_evf_competition, id_evf_event, txt_evf_slug) and
-- pays for itself three times:
--
--   * Stable identity. PZSz names drift -- casing changes between "Seniorow"
--     and "seniorow" inside one series, and one live row reads "mezczyzn". An
--     id survives a rename; a name-based match would create a duplicate event.
--   * The re-check key. Invitation letters and venue addresses are published
--     closer to the event, so a later pass has to know which PZSz detail page
--     belongs to which of our rows.
--   * Change detection. A row whose id we hold but which vanishes from the
--     listing is a cancellation or a re-key, and should surface rather than be
--     dropped in silence.
--
-- INTEGER, not BIGINT: live PZSz ids are four digits (4581..4599), and the
-- listing has carried ids in that range for years. id_evf_calendar_event is a
-- BIGINT because it is a WordPress post id, which is a different animal.
--
-- Uniqueness is per season rather than global, exactly as
-- idx_tbl_event_evf_calendar_season already is: one PZSz id may legitimately
-- recur across our season windows, but never twice inside one. The index is
-- partial so the overwhelming majority of events -- every SPWS, EVF and FIE row
-- -- may leave the column NULL without colliding.
--
-- No grant change is needed: ADR-083's grants are table-level (20260723000001
-- BLOCK 3), and anon retains SELECT on tbl_event and tbl_organizer for the
-- public calendar.
--
-- Plan-test-ID 70 (supabase/tests/70_pzsz_organizer_and_event_id.sql).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- 1. The organizer. Idempotent, so the seed dump that follows on a fresh
--    bootstrap cannot duplicate it and a replay is a no-op.
INSERT INTO tbl_organizer (txt_code, txt_name)
VALUES ('PZSz', 'Polski Związek Szermierczy')
ON CONFLICT (txt_code) DO NOTHING;


-- 2. The source id.
ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS id_pzsz_event INTEGER;

COMMENT ON COLUMN tbl_event.id_pzsz_event IS
  'PZSz calendar event id, from pzszerm.pl/zawody/kalendarium-zawodow/zawody/?id=N. '
  'The stable identity for a source whose event names drift in casing and carry '
  'live typos, and the key the enrichment pass uses to re-find a detail page. '
  'NULL for every event from another organizer.';

CREATE UNIQUE INDEX IF NOT EXISTS idx_tbl_event_pzsz_season
  ON tbl_event (id_season, id_pzsz_event)
  WHERE id_pzsz_event IS NOT NULL;

COMMIT;
