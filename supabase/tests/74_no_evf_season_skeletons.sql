-- =============================================================================
-- pgTAP — a season is bootstrapped only with skeletons nobody discovers for us
-- =============================================================================
-- Verifies migration 20260906000001_no_evf_season_skeletons.sql.
--
-- `fn_init_season` provisioned a skeleton for the whole EVF circuit — PEW1-n
-- plus the IMEW/DMEW singleton. Those events are not scheduled by SPWS; EVF
-- publishes them and `evf_calendar.py` / `evf_sync.py` discover them within the
-- same season. The skeleton is therefore a PREDICTION of a row that is going to
-- arrive anyway, and it carries none of the four identities the ADR-039 dedup
-- ladder can use: no date, no EVF calendar id, no EVF results id, no slug.
--
-- Its only handle is the prior season's city, copied at bootstrap, which is
-- what `fn_allocate_evf_event_code` Step A matches on. Measured on PROD
-- 2026-09-05: all 23 skeletons had an EMPTY location, because the season was
-- bootstrapped on 2026-06-28 and ADR-088 — the work that made txt_location
-- reliably hold a city — was accepted on 2026-09-04. Step A could never fire,
-- the allocator fell through to Step C (next-free PEW{N+1}), and every scrape
-- minted a fresh row beside the skeleton: 8 duplicate pairs, with 15 more due
-- as EVF published the rest of the season.
--
-- Even with cities present the guess is only as good as EVF staying put, and
-- EVF moves its circuit between seasons. So the rule is not "keep skeletons for
-- SPWS events" but "keep skeletons for events nobody will discover for us":
--
--   PPW1-n  SPWS  no scraper  -> kept
--   MPW     SPWS  no scraper  -> kept
--   MSW     FIE   no scraper  -> kept (organiser is FIE, but nothing creates it)
--   PEW1-n  EVF   evf_sync    -> dropped
--   IMEW    EVF   evf_sync    -> dropped
--   DMEW    EVF   evf_sync    -> dropped
--
-- Amends ADR-077 §3. Plan-test-ID 74.
-- =============================================================================

BEGIN;

SELECT plan(9);

-- ---------------------------------------------------------------------------
-- A freshly initialised season: what fn_init_season provisions now.
-- Mirrors the 19_phase3_wizard.sql fixture — SPWS-2026-2027 exists in the seed
-- (ADR-077 Phase C promoted skeleton), so remove it and let the wizard rebuild.
-- ---------------------------------------------------------------------------
SAVEPOINT s_init;

DELETE FROM tbl_event          WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027');
DELETE FROM tbl_scoring_config WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027');
DELETE FROM tbl_season         WHERE txt_code = 'SPWS-2026-2027';
INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2026-2027', '2026-09-01', '2027-07-31', 'IMEW');

CREATE TEMP TABLE _init74 AS
  SELECT * FROM fn_init_season(
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
  );

-- 74.1 — the EVF circuit is no longer predicted.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code ~ '^PEW\d+[efs]*-'),
  0,
  '74.1 — fn_init_season creates no PEW skeleton; evf_sync discovers the circuit'
);

-- 74.2 — nor the European singleton, even in an IMEW year. This is the case
-- that would slip through a PEW-only fix: the fixture season is declared IMEW.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND (txt_code LIKE 'IMEW%' OR txt_code LIKE 'DMEW%')),
  0,
  '74.2 — no IMEW/DMEW skeleton either, in a season declared IMEW'
);

-- 74.3 — what is kept, stated positively rather than by absence. PPW is the
-- one whose count varies with the prior season, so assert the relationship.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code ~ '^PPW\d+-'),
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
       AND txt_code ~ '^PPW\d+-'),
  '74.3 — PPW skeletons still provisioned, one per prior-season PPW'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code ~ '^MPW-'),
  1,
  '74.4 — the MPW skeleton is kept: SPWS runs it, nothing discovers it'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code ~ '^MSW-'),
  1,
  '74.5 — the MSW skeleton is kept although FIE organises it: no FIE scraper exists'
);

-- 74.6 — the return contract does not change shape. Callers read by_kind by
-- key (the season wizard renders the breakdown from it), so PEW keeps its key
-- and reports zero rather than disappearing.
SELECT is(
  ((SELECT by_kind FROM _init74) ->> 'PEW'),
  '0',
  '74.6 — by_kind still carries the PEW key, reporting 0 (callers read by key)'
);

-- 74.7 — the rule restated at the level that actually matters: no skeleton is
-- provisioned for an organiser whose events arrive by scrape.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e
     JOIN tbl_organizer o USING (id_organizer)
    WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
      AND o.txt_code = 'EVF'),
  0,
  '74.7 — no EVF-organised skeleton is provisioned at all'
);

-- 74.8 — ADR-077 §3's childless doctrine still holds for what remains.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')),
  0,
  '74.8 — the kept skeletons stay childless (ADR-077 §3)'
);

ROLLBACK TO SAVEPOINT s_init;

-- ---------------------------------------------------------------------------
-- 74.9 — the migration also clears the skeletons already provisioned, so the
-- environments do not carry a generation of unmatchable rows forward. Scoped
-- deliberately: only a CREATED, dateless, childless EVF row is removable.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e
     JOIN tbl_organizer o USING (id_organizer)
    WHERE e.enum_status = 'CREATED'
      AND e.dt_start IS NULL
      AND o.txt_code = 'EVF'),
  0,
  '74.9 — no dateless CREATED EVF skeleton is left anywhere after the migration'
);

SELECT * FROM finish();

ROLLBACK;
