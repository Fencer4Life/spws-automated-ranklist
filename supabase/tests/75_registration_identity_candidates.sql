-- =============================================================================
-- pgTAP — the registration-identity block (FR-124 extension; ADR-079 reversal)
-- =============================================================================
-- Verifies migration 20260912000001_registration_identity_candidates.sql:
-- fn_registration_identity_candidates (the lookup, four classifications) and
-- fn_confirm_registration_identity (the write, three actions).
--
-- WHY THIS EXISTS. fn_match_registration_fencer matches the exact tuple
-- (upper(surname), upper(first name), birth year). That strictness is
-- deliberate — it can never merge two different people — but it leaves no
-- near-miss path at all, so every discrepancy falls into the unmatched bucket
-- silently and the same fencer reaches the organizer's software twice. On PROD
-- on 2026-09-12, PPW1-2026-2027 had 43 registrations, 36 matched, and all 7
-- misses were near-misses rather than newcomers:
--
--   BUJKO Paulina 1982      vs #30  1979 (confirmed)   → BY_DIFFERS, D prompt
--   STAŃCZYK MARCIN 1979    vs #280 1980 (confirmed)   → BY_DIFFERS, D prompt
--   KRZYSZTOF Łęcki 1991    vs #168 ŁĘCKI Krzysztof    → SWAPPED,    B prompt
--   KANIECKI / PERKOWSKI / SIEJKOWSKI / ZANEUSKAYA     → nothing,    rung 6
--
-- THE INVARIANT THIS FILE PROTECTS ABOVE ALL OTHERS. The 36 that already match
-- must keep taking the existing fast path byte-for-byte. Neither new function
-- touches fn_match_registration_fencer or fn_create_registration, and 75.1
-- asserts that directly rather than by inspection.
--
-- THE GUARD THAT MATTERS. tbl_fencer carries no uniqueness constraint on
-- name + birth year — only the primary key and the non-unique idx_fencer_name.
-- PROD holds two live same-name pairs (#197 MŁYNEK Janusz 1951 with 19 results
-- vs #356 …1984; #354 KRAWCZYK Paweł 1989 vs #355 …1954). A name-based rule
-- that acted on "the" matching row could therefore write a birth year onto the
-- wrong person, unrecoverably. Every rule here is guarded by the resolution
-- ORDER itself — exactly-one-EXACT wins before any name-only rule is reached —
-- and the MŁYNEK pair is carried as a fixture so the guard is exercised, not
-- assumed.
--
-- Plan-test-ID 75 (this file).
-- =============================================================================

BEGIN;

SELECT plan(42);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  v_season := fn_create_season('REG75', '2098-09-01', '2099-06-30');
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('REGORG75', 'Reg org 75') RETURNING id_organizer INTO v_org;
  PERFORM fn_create_event('REG75EVT', 'Reg 75', v_season, v_org);

  -- (a) The clean exact match — the 36-of-43 population.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          enum_gender, bool_birth_year_estimated)
    VALUES ('PGTAP75EXACT', 'Anna', 1970, 'F', FALSE);

  -- (b) The swap fixture, modelled on ŁĘCKI Krzysztof #168.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          enum_gender, bool_birth_year_estimated)
    VALUES ('PGTAP75SWAP', 'Krzysztof', 1991, 'M', FALSE);

  -- (c) Confirmed birth year that differs — the BUJKO/STAŃCZYK fixture. She is
  --     given a RESULT as well, because the point of 75.8d is that correcting
  --     a birth year re-queues the events that fencer actually played. A
  --     result-less fixture would enqueue nothing and the assertion would pass
  --     or fail for the wrong reason.
  --     enum_source_age_category is set deliberately: that is the splitter's
  --     own path, and fn_assert_result_vcat returns early for it (ADR-056
  --     revision, bracket-label wins), so the fixture does not have to satisfy
  --     a BY-derived V-cat in a synthetic 2098/99 season.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          enum_gender, bool_birth_year_estimated)
    VALUES ('PGTAP75CONF', 'Paulina', 1979, 'F', FALSE);

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
                              enum_weapon, enum_gender, enum_age_category,
                              enum_import_status, num_multiplier)
    SELECT id_event, 'REG75T', 'Reg 75 tournament', 'PPW',
           'EPEE', 'F', 'V4', 'SCORED', 1.0
      FROM tbl_event WHERE txt_code = 'REG75EVT';

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place,
                          enum_fencer_age_category, enum_source_age_category)
    SELECT f.id_fencer, t.id_tournament, 1, 'V4', 'V4'
      FROM tbl_fencer f, tbl_tournament t
     WHERE f.txt_surname = 'PGTAP75CONF' AND t.txt_code = 'REG75T';

  -- (d) Estimated birth year that differs — overwritten by policy.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          enum_gender, bool_birth_year_estimated)
    VALUES ('PGTAP75EST', 'Marek', 1960, 'M', TRUE);

  -- (e) NULL birth year — structurally unreachable through the exact matcher,
  --     because NULL is never equal to anything. PROD holds 9 such rows.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          enum_gender, bool_birth_year_estimated)
    VALUES ('PGTAP75NULL', 'Ewa', NULL, 'F', FALSE);

  -- (f) THE MŁYNEK FIXTURE — two people, one name, both confirmed, 33 years
  --     apart, one of them carrying results.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          enum_gender, bool_birth_year_estimated)
    VALUES ('PGTAP75TWIN', 'Janusz', 1951, 'M', FALSE);
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          enum_gender, bool_birth_year_estimated)
    VALUES ('PGTAP75TWIN', 'Janusz', 1984, 'M', FALSE);
END $setup$;

-- ---------------------------------------------------------------------------
-- 75.1 — THE REGRESSION THAT MATTERS MOST. The existing fast path is
-- untouched: a clean exact match still resolves through the original matcher,
-- and the original matcher still refuses a near-miss. If this fails, nothing
-- else in this file is worth reading.
-- ---------------------------------------------------------------------------
SELECT is(
  fn_match_registration_fencer('PGTAP75EXACT', 'Anna', 1970::SMALLINT),
  (SELECT id_fencer FROM tbl_fencer
    WHERE txt_surname = 'PGTAP75EXACT' AND int_birth_year = 1970),
  '75.1a exact tuple still resolves through the untouched fast path');

SELECT is(
  fn_match_registration_fencer('PGTAP75CONF', 'Paulina', 1982::SMALLINT),
  NULL,
  '75.1b the fast path still refuses a birth-year near-miss — not loosened');

-- ---------------------------------------------------------------------------
-- 75.2 — EXACT classification. The lookup scans by name, so it must still
-- report the exact row as EXACT rather than as a birth-year difference.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT string_agg(enum_kind, ',' ORDER BY enum_kind)
     FROM fn_registration_identity_candidates(
            'PGTAP75EXACT', 'Anna', 1970::SMALLINT)),
  'EXACT',
  '75.2 a clean match classifies as EXACT and nothing else');

-- ---------------------------------------------------------------------------
-- 75.3 — SWAPPED. Surname and given name exchanged hits the ŁĘCKI case.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT enum_kind FROM fn_registration_identity_candidates(
            'Krzysztof', 'PGTAP75SWAP', 1991::SMALLINT)),
  'SWAPPED',
  '75.3a swapped name fields classify as SWAPPED');

SELECT is(
  (SELECT id_fencer FROM fn_registration_identity_candidates(
            'Krzysztof', 'PGTAP75SWAP', 1991::SMALLINT)),
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PGTAP75SWAP'),
  '75.3b and point at the real fencer, so the B prompt can name them');

-- ---------------------------------------------------------------------------
-- 75.4 — BY_NULL. Problem 2: the existing matcher structurally cannot find
-- these rows, because NULL is never equal to anything.
-- ---------------------------------------------------------------------------
SELECT is(
  fn_match_registration_fencer('PGTAP75NULL', 'Ewa', 1988::SMALLINT),
  NULL,
  '75.4a the exact matcher cannot reach a NULL-birth-year fencer at all');

SELECT is(
  (SELECT enum_kind FROM fn_registration_identity_candidates(
            'PGTAP75NULL', 'Ewa', 1988::SMALLINT)),
  'BY_NULL',
  '75.4b but the candidate lookup does, classified BY_NULL');

-- ---------------------------------------------------------------------------
-- 75.5 — BY_DIFFERS, and it must report BOTH twins, not one of them. This is
-- the MŁYNEK case: rung 5 shows every candidate and lets the human choose,
-- which is safe precisely because it never picks.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT count(*)::INT FROM fn_registration_identity_candidates(
            'PGTAP75TWIN', 'Janusz', 1999::SMALLINT)),
  2,
  '75.5a a name borne by two fencers returns BOTH candidates, never one');

SELECT is(
  (SELECT string_agg(DISTINCT enum_kind, ',')
     FROM fn_registration_identity_candidates(
            'PGTAP75TWIN', 'Janusz', 1999::SMALLINT)),
  'BY_DIFFERS',
  '75.5b both classified BY_DIFFERS, so rung 5 asks rather than acting');

-- ---------------------------------------------------------------------------
-- 75.6 — the MŁYNEK case that does NOT reach rung 5. Registering as the 1984
-- Janusz hits an exact match, so the ambiguity with the 19-result 1951 Janusz
-- never arises. The resolution ORDER is the guard.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT string_agg(enum_kind, ',' ORDER BY enum_kind)
     FROM fn_registration_identity_candidates(
            'PGTAP75TWIN', 'Janusz', 1984::SMALLINT)),
  'BY_DIFFERS,EXACT',
  '75.6a an exact twin is reported alongside the other, both classified');

SELECT is(
  (SELECT count(*)::INT FROM fn_registration_identity_candidates(
            'PGTAP75TWIN', 'Janusz', 1984::SMALLINT)
    WHERE enum_kind = 'EXACT'),
  1,
  '75.6b exactly one EXACT — rung 1 wins and the caller never reaches rung 5');

-- ---------------------------------------------------------------------------
-- 75.7 — rung 6. A name absent from tbl_fencer yields nothing at all. NAGY
-- Orsolya is the live instance: a first-time international entrant whom the
-- swap retry cannot help, because the swap needs a fencer already in the table.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT count(*)::INT FROM fn_registration_identity_candidates(
            'PGTAP75ABSENT', 'Nobody', 1975::SMALLINT)),
  0,
  '75.7 an unknown name returns no candidates — rung 6, a genuinely new person');

-- ---------------------------------------------------------------------------
-- 75.8 — ADOPT_DECLARED. The registration links to the fencer AND the master
-- birth year is corrected to the declared value, marked confirmed.
-- ---------------------------------------------------------------------------
DO $adopt$
DECLARE v_e INT; v_r INT; v_f INT; v_tok UUID := gen_random_uuid();
BEGIN
  SELECT id_event INTO v_e FROM tbl_event WHERE txt_code = 'REG75EVT';
  SELECT id_fencer INTO v_f FROM tbl_fencer WHERE txt_surname = 'PGTAP75CONF';

  v_r := fn_create_registration(v_e, 'PGTAP75CONF', 'Paulina', 'F',
           1982::SMALLINT, ARRAY['EPEE']::enum_weapon_type[],
           NULL, NULL, 'v1.0', v_tok);

  PERFORM fn_confirm_registration_identity(v_r, v_tok, v_f, 'ADOPT_DECLARED');

  CREATE TEMP TABLE t75_adopt AS
    SELECT v_r AS id_registration, v_f AS id_fencer, v_e AS id_event;
END $adopt$;

SELECT is(
  (SELECT r.id_fencer FROM tbl_registration r
     JOIN t75_adopt a ON a.id_registration = r.id_registration),
  (SELECT id_fencer FROM t75_adopt),
  '75.8a ADOPT_DECLARED links the registration to the chosen fencer');

-- THE EXPOSURE THIS CLOSES. ADOPT_DECLARED is a PARAMETER, not a click: the
-- server cannot tell a fencer pressing the button from a crafted RPC call, and
-- the edit token is no obstacle to a caller who mints it for a row they just
-- created. Demonstrated on a PROD mirror 2026-09-12 — an anonymous caller
-- knowing only the name "BUJKO Paulina" moved a CONFIRMED 1979 to 1900.
-- So a confirmed year is no longer applied here at all. It is PROPOSED.
SELECT is(
  (SELECT f.int_birth_year FROM tbl_fencer f
     JOIN t75_adopt a ON a.id_fencer = f.id_fencer),
  1979::SMALLINT,
  '75.8b the confirmed master birth year is NOT changed by the public call');

SELECT is(
  (SELECT o.enum_status FROM tbl_registration_identity_override o
     JOIN t75_adopt a ON a.id_fencer = o.id_fencer),
  'PENDING',
  '75.8c it is recorded as a proposal awaiting an administrator');

-- 75.8d/e — nothing was written to tbl_fencer, so neither the recompute queue
-- nor the audit log may show anything yet. Both fire on the APPLY, not here.
SELECT ok(
  NOT EXISTS (SELECT 1 FROM tbl_recompute_queue q
                JOIN t75_adopt a ON a.id_event = q.id_event),
  '75.8d nothing is queued for recompute — no master row moved');

SELECT ok(
  NOT EXISTS (SELECT 1 FROM tbl_audit_log l
                JOIN t75_adopt a ON a.id_fencer = l.id_row
               WHERE l.txt_table_name = 'tbl_fencer' AND l.txt_action = 'UPDATE'),
  '75.8e and trg_audit_fencer has nothing to record');

-- ---------------------------------------------------------------------------
-- 75.9 — FIX_REGISTRATION. The mirror image: the registration is corrected to
-- the table's year and the fencer row is left completely alone.
-- ---------------------------------------------------------------------------
DO $fix$
DECLARE v_e INT; v_r INT; v_f INT; v_tok UUID := gen_random_uuid();
BEGIN
  SELECT id_event INTO v_e FROM tbl_event WHERE txt_code = 'REG75EVT';
  SELECT id_fencer INTO v_f FROM tbl_fencer
    WHERE txt_surname = 'PGTAP75EST' AND txt_first_name = 'Marek';

  v_r := fn_create_registration(v_e, 'PGTAP75EST', 'Marek', 'M',
           1963::SMALLINT, ARRAY['FOIL']::enum_weapon_type[],
           NULL, NULL, 'v1.0', v_tok);

  PERFORM fn_confirm_registration_identity(v_r, v_tok, v_f, 'FIX_REGISTRATION');

  CREATE TEMP TABLE t75_fix AS
    SELECT v_r AS id_registration, v_f AS id_fencer;
END $fix$;

SELECT is(
  (SELECT r.int_birth_year FROM tbl_registration r
     JOIN t75_fix x ON x.id_registration = r.id_registration),
  1960::SMALLINT,
  '75.9a FIX_REGISTRATION corrects the registration to the table''s year');

SELECT is(
  (SELECT f.int_birth_year FROM tbl_fencer f JOIN t75_fix x ON x.id_fencer = f.id_fencer),
  1960::SMALLINT,
  '75.9b and leaves the fencer row untouched, even though it was estimated');

SELECT is(
  (SELECT r.id_fencer FROM tbl_registration r
     JOIN t75_fix x ON x.id_registration = r.id_registration),
  (SELECT id_fencer FROM t75_fix),
  '75.9c linking the registration — it is now an ordinary exact match');

-- ---------------------------------------------------------------------------
-- 75.10 — THE AUTHORISATION GUARDS. Each closes a specific hole, and the
-- second is the one without which a caller could name any fencer in the table
-- and rewrite their birth year.
-- ---------------------------------------------------------------------------
DO $guards$
DECLARE v_e INT; v_r INT; v_tok UUID := gen_random_uuid();
BEGIN
  SELECT id_event INTO v_e FROM tbl_event WHERE txt_code = 'REG75EVT';
  v_r := fn_create_registration(v_e, 'PGTAP75CONF', 'Paulina', 'F',
           1982::SMALLINT, ARRAY['SABRE']::enum_weapon_type[],
           NULL, NULL, 'v1.0', v_tok);
  CREATE TEMP TABLE t75_guard AS SELECT v_r AS id_registration, v_tok AS tok;
END $guards$;

SELECT throws_ok(
  $$ SELECT fn_confirm_registration_identity(
       (SELECT id_registration FROM t75_guard),
       '00000000-0000-0000-0000-000000000000'::UUID,
       (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PGTAP75CONF'),
       'ADOPT_DECLARED') $$,
  NULL,
  '75.10a a wrong edit token is refused — the capability gates the write');

-- The guard that matters most: p_id_fencer must lie in the candidate set
-- RECOMPUTED SERVER-SIDE from this registration's own declared name. The
-- caller does not get to nominate an arbitrary fencer.
SELECT throws_ok(
  $$ SELECT fn_confirm_registration_identity(
       (SELECT id_registration FROM t75_guard),
       (SELECT tok FROM t75_guard),
       (SELECT id_fencer FROM tbl_fencer
         WHERE txt_surname = 'PGTAP75TWIN' AND int_birth_year = 1951),
       'ADOPT_DECLARED') $$,
  NULL,
  '75.10b a fencer outside the registration''s own candidate set is refused');

SELECT is(
  (SELECT int_birth_year FROM tbl_fencer
    WHERE txt_surname = 'PGTAP75TWIN' AND int_birth_year = 1951),
  1951::SMALLINT,
  '75.10c the 19-result Janusz was not written to — the refusal held');

-- ---------------------------------------------------------------------------
-- 75.11 — DIFFERENT_PERSON writes nothing anywhere. The registration stays
-- unmatched and the fencer is created at scraping time exactly as today.
-- ---------------------------------------------------------------------------
DO $diff$
DECLARE v_e INT; v_r INT; v_f INT; v_tok UUID := gen_random_uuid();
BEGIN
  SELECT id_event INTO v_e FROM tbl_event WHERE txt_code = 'REG75EVT';
  SELECT id_fencer INTO v_f FROM tbl_fencer WHERE txt_surname = 'PGTAP75NULL';

  v_r := fn_create_registration(v_e, 'PGTAP75NULL', 'Ewa', 'F',
           1988::SMALLINT, ARRAY['EPEE']::enum_weapon_type[],
           NULL, NULL, 'v1.0', v_tok);

  PERFORM fn_confirm_registration_identity(v_r, v_tok, v_f, 'DIFFERENT_PERSON');

  CREATE TEMP TABLE t75_diff AS
    SELECT v_r AS id_registration, v_f AS id_fencer;
END $diff$;

SELECT is(
  (SELECT r.id_fencer FROM tbl_registration r
     JOIN t75_diff d ON d.id_registration = r.id_registration),
  NULL,
  '75.11a DIFFERENT_PERSON leaves the registration unmatched');

SELECT is(
  (SELECT f.int_birth_year FROM tbl_fencer f JOIN t75_diff d ON d.id_fencer = f.id_fencer),
  NULL,
  '75.11b and does NOT populate the NULL birth year it declined to claim');

-- ---------------------------------------------------------------------------
-- 75.12 — LOUD, NOT SILENT. Overwriting a CONFIRMED birth year is different in
-- kind from the other two writes. A NULL is a gap and an estimate is a guess;
-- both are overwritten by policy and neither contradicts anything we verified.
-- A confirmed year is a value somebody already checked, and a member of the
-- public just changed it. That must not pass unremarked: it leaves a durable,
-- queryable record that an operator is alerted from.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT count(*)::INT FROM tbl_registration_identity_override o
     JOIN t75_adopt a ON a.id_fencer = o.id_fencer),
  1,
  '75.12a overwriting a confirmed birth year records a loud override row');

SELECT is(
  (SELECT o.int_birth_year_before||' -> '||o.int_birth_year_after
     FROM tbl_registration_identity_override o
     JOIN t75_adopt a ON a.id_fencer = o.id_fencer),
  '1979 -> 1982',
  '75.12b carrying both years, so the operator sees what actually changed');

-- The record has to survive the registration that caused it: ADR-079 makes
-- tbl_registration EPHEMERAL — purged once results are ingested — so a plain
-- FK would take the evidence with it exactly when someone asks what happened.
SELECT is(
  (SELECT o.txt_surname||' '||o.txt_first_name
     FROM tbl_registration_identity_override o
     JOIN t75_adopt a ON a.id_fencer = o.id_fencer),
  'PGTAP75CONF Paulina',
  '75.12c and the declared identity denormalised, so a purge cannot erase it');

SELECT ok(
  (SELECT o.ts_notified IS NULL
     FROM tbl_registration_identity_override o
     JOIN t75_adopt a ON a.id_fencer = o.id_fencer),
  '75.12d unnotified when written — the drain claims it and alerts');

-- ---------------------------------------------------------------------------
-- 75.13 — and the quiet cases stay quiet. Alerting on a populate or an estimate
-- correction would bury the one case that matters in noise nobody reads.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT count(*)::INT FROM tbl_registration_identity_override o
     JOIN t75_diff d ON d.id_fencer = o.id_fencer),
  0,
  '75.13a populating a NULL birth year raises nothing — it contradicts nothing');

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration_identity_override o
     JOIN t75_fix x ON x.id_fencer = o.id_fencer),
  0,
  '75.13b nor does FIX_REGISTRATION, which never touches the fencer at all');

-- ---------------------------------------------------------------------------
-- 75.14 — the administrator applies the proposal. This is where the master row
-- finally moves, and where the self-heal fires.
-- ---------------------------------------------------------------------------
DO $apply$
DECLARE v_o INT;
BEGIN
  SELECT o.id_override INTO v_o FROM tbl_registration_identity_override o
    JOIN t75_adopt a ON a.id_fencer = o.id_fencer;
  -- RLS keys on auth.role(), which reads the JWT claim rather than the
  -- database role, so the claim must be set too or the admin sees nothing
  -- (same shape as 01_database_foundation.sql:227).
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated"}', TRUE);
  SET LOCAL ROLE authenticated;
  PERFORM fn_apply_identity_override(v_o);
  RESET ROLE;
END $apply$;

SELECT is(
  (SELECT f.int_birth_year FROM tbl_fencer f JOIN t75_adopt a ON a.id_fencer = f.id_fencer),
  1982::SMALLINT,
  '75.14a applying the proposal corrects the master birth year');

SELECT is(
  (SELECT f.bool_birth_year_estimated FROM tbl_fencer f JOIN t75_adopt a ON a.id_fencer = f.id_fencer),
  FALSE,
  '75.14b and leaves it marked confirmed');

-- The apply must be a PLAIN UPDATE for the same reason the original write was:
-- trg_assert_result_vcat does not fire on tbl_fencer, so without this enqueue
-- every old result keeps its old V-cat with no error raised anywhere.
SELECT ok(
  EXISTS (SELECT 1 FROM tbl_recompute_queue q JOIN t75_adopt a ON a.id_event = q.id_event),
  '75.14c and re-queues the event she actually played');

SELECT is(
  (SELECT o.enum_status FROM tbl_registration_identity_override o
     JOIN t75_adopt a ON a.id_fencer = o.id_fencer),
  'APPLIED',
  '75.14d and the proposal is closed, so it cannot be applied twice');

-- ---------------------------------------------------------------------------
-- 75.15 — rejecting one writes nothing at all. This is the attacker's path,
-- and it must leave the fencer exactly as they were.
-- ---------------------------------------------------------------------------
DO $reject$
DECLARE v_e INT; v_r INT; v_f INT; v_o INT; v_tok UUID := gen_random_uuid();
BEGIN
  SELECT id_event INTO v_e FROM tbl_event WHERE txt_code = 'REG75EVT';
  SELECT id_fencer INTO v_f FROM tbl_fencer WHERE txt_surname = 'PGTAP75TWIN' AND int_birth_year = 1951;

  v_r := fn_create_registration(v_e,'PGTAP75TWIN','Janusz','M',1902::SMALLINT,
           ARRAY['FOIL']::enum_weapon_type[], NULL, NULL, 'v1.0', v_tok);
  PERFORM fn_confirm_registration_identity(v_r, v_tok, v_f, 'ADOPT_DECLARED');

  SELECT id_override INTO v_o FROM tbl_registration_identity_override
   WHERE id_fencer = v_f AND enum_status = 'PENDING';
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated"}', TRUE);
  SET LOCAL ROLE authenticated;
  PERFORM fn_reject_identity_override(v_o);
  RESET ROLE;
  CREATE TEMP TABLE t75_reject AS SELECT v_f AS id_fencer, v_o AS id_override;
END $reject$;

SELECT is(
  (SELECT f.int_birth_year FROM tbl_fencer f JOIN t75_reject x ON x.id_fencer = f.id_fencer),
  1951::SMALLINT,
  '75.15a rejecting leaves the 19-result Janusz exactly as he was');

SELECT is(
  (SELECT o.enum_status FROM tbl_registration_identity_override o
     JOIN t75_reject x ON x.id_override = o.id_override),
  'REJECTED',
  '75.15b and the proposal is closed');

-- ---------------------------------------------------------------------------
-- 75.16 — and the whole fix is worthless if the public can apply its own
-- proposal, so the apply path is administrator-only.
-- ---------------------------------------------------------------------------
SELECT ok(
  NOT has_function_privilege('anon', 'fn_apply_identity_override(int)', 'EXECUTE'),
  '75.16 anon cannot apply a proposal — that would restore the exposure');

-- ---------------------------------------------------------------------------
-- 75.17 — the lookup normalises names the way the INGESTION matcher does.
--
-- MACIEJ Splawa - Neyman entered PPW1-2026-2027 with the two name fields
-- exchanged. #276 SPLAWA-NEYMAN Maciej has been on the roster for 14 results,
-- so rung 3 should have offered the swap. It never fired, because the lookup
-- compared with upper(btrim(...)) and nothing else:
--
--   typed first name  'SPLAWA - NEYMAN'   (plain L, spaces around the hyphen)
--   fencer surname    'SPLAWA-NEYMAN'     (L-with-stroke, no spaces)
--
-- Two differences, either one fatal. The lookup returned ZERO candidates, so
-- the form skipped every rung and echoed the canonical form back as a brand-new
-- person -- which, for a swapped name, looks perfectly correct to the reader.
--
-- python/matcher/fuzzy_match.py has handled both for years:
-- fold_diacritics special-cases L-stroke because NFD does not decompose it,
-- and canonicalize_scraped_name collapses 'A - B' to 'A-B' (the SAMECKA
-- -NACZYNSKA case). The registration half of the system simply never got the
-- same treatment. fn_fold_name is that normalisation, shared by both sides.
-- ---------------------------------------------------------------------------
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                        bool_birth_year_estimated, enum_gender, txt_nationality)
VALUES ('SPŁAWA-NEYMAN', 'PGTAP75Maciej', 1991, FALSE, 'M', 'PL');

SELECT is(
  (SELECT count(*)::INT FROM fn_registration_identity_candidates(
     'PGTAP75MACIEJ', 'SPLAWA - NEYMAN', 1988::SMALLINT)
    WHERE enum_kind = 'SWAPPED'),
  1,
  '75.17a a swapped name is found across BOTH a folded diacritic and hyphen spacing'
);

SELECT is(
  (SELECT txt_surname FROM fn_registration_identity_candidates(
     'PGTAP75MACIEJ', 'SPLAWA - NEYMAN', 1988::SMALLINT)
    WHERE enum_kind = 'SWAPPED'),
  'SPŁAWA-NEYMAN',
  '75.17b and it returns the stored spelling, not the typed one'
);

-- 75.18 — the folding must not collapse two genuinely different people.
SELECT is(
  (SELECT count(*)::INT FROM fn_registration_identity_candidates(
     'PGTAP75NOSUCH', 'Nobody', 1970::SMALLINT)),
  0,
  '75.18 an unrelated name still matches nobody'
);

-- 75.19 — folding is applied to the typed-order branch too, not only SWAPPED.
SELECT is(
  (SELECT count(*)::INT FROM fn_registration_identity_candidates(
     'SPLAWA - NEYMAN', 'PGTAP75Maciej', 1991::SMALLINT)
    WHERE enum_kind = 'EXACT'),
  1,
  '75.19 the same normalisation finds an exact match typed in the right order'
);

SELECT * FROM finish();
ROLLBACK;
