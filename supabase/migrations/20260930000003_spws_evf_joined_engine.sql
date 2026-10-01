-- =============================================================================
-- SPWS_EVF_JOINED_V1_2026_2027: EVF with a joined-bracket premium and a
-- whole-bracket cap, for PPW and MPW from 2026/2027
-- =============================================================================
-- ADR-104 §§2-7. doc/plans/adr-104-joined-engine-implementation-plan-2026-09-30.html
-- step 6. Flips JB27.ENG, CAP, ORD, PRE, TYPE and STORE in
-- supabase/tests/85_spws_evf_joined_engine.sql, and the re-pointed assertions
-- in 02, 80 and 82, from RED to GREEN.
--
-- THE RULE (Załącznik nr 1, § 3, locked 30 September 2026)
--
--   By the size N of the whole bracket, fenced as one listing:
--   * 1-3 fencers are a meeting, not a competition: N - place + 1 (TABLE);
--   * a single category of 4 or more, or any bracket of 16 or more: EVF classic
--     on the joined place and N (EVF_CLASSIC);
--   * a joined bracket of 4-15 (EVF_JOINED): the youngest category scores EVF;
--     a category d steps older scores max(EVF x (1 + 0.05 d), EVF + d);
--     everyone is capped 1 point below the fencer directly ahead, of any
--     category, before the type coefficient is applied.
--
-- WHAT THIS ADDS
--
--   1. The registry row, paired with JOINED_BRACKET_CATEGORY_PLACE.
--   2. The strategy fn_score_spws_evf_joined_v1_2026_2027 (one row, no cap)
--      and a dispatcher that passes d and the joined flag to every engine.
--   3. fn_score_joined_bracket: the whole bracket from its category order,
--      with the cap. The writer, the preview and the tests all read it, so the
--      cap exists in one function.
--   4. tbl_tournament(_draft).txt_joined_order, one digit per place; and on
--      tbl_result(_draft) num_joined_premium, num_cap_reduction and
--      int_category_steps, -1 where the method does not use them.
--   5. The writer, the preview, the ingest RPC (p_joined_order), the draft
--      commit, vw_score and the rolling functions, with the new columns.
--   6. tbl_joining_check, where the pipeline stores its § 2 verdict (§7).
--   7. The assignment: SPWS-2026-2027's default, PPW and MPW.
--
-- THE §11 GATE
--
--   SPWS-2026-2027 is moved only while it holds no scored result and no
--   scoring revision (ADR-097 §11: a scored season is never reassigned). If it
--   does, this migration still registers the engine but leaves the season as
--   it stands and raises a NOTICE; moving it then takes a privileged revision
--   (ADR-104 Consequences). D3 holds 2026/2027 ingestion until the release, and
--   the preflight's SSP-06 reports the case before the deploy.
--
-- BOOTSTRAP ORDER (ADR-036 amendment)
--
--   On LOCAL and in CI this runs against empty tables; the seed arrives after
--   it, and supabase/seed_post_backfill.sql calls fn_backfill_scoring_engines()
--   again, which assigns the engine then.
-- =============================================================================

SET LOCAL lock_timeout = '2s';

-- =============================================================================
-- 1 · The registry row
-- =============================================================================
INSERT INTO tbl_scoring_engine (txt_code, txt_label, txt_base_shape, txt_joined_bracket_module)
VALUES (
  'SPWS_EVF_JOINED_V1_2026_2027',
  'SPWS — punkty EVF i premia w stawce łączonej (od sezonu 2026/2027)',
  'By the size N of the whole bracket: N <= 3 scores N - place + 1; a single '
  'category of 4 or more, or any bracket of 16 or more, scores '
  'EVF_CLASSIC_V1_2025_2026 on the joined place and N; in a joined bracket of '
  '4-15 the youngest category scores EVF and a category d steps older '
  'max(EVF x (1 + 0.05 d), EVF + d), each capped 1 point below the fencer '
  'directly ahead.',
  'JOINED_BRACKET_CATEGORY_PLACE'
)
ON CONFLICT (txt_code) DO NOTHING;

-- =============================================================================
-- 2 · The breakdown gains the premium
-- =============================================================================
ALTER TYPE typ_score_breakdown ADD ATTRIBUTE num_joined_premium NUMERIC;

COMMENT ON TYPE typ_score_breakdown IS
  'What every strategy returns: the raw, unrounded components and the method. '
  'A component the method does not use is NULL here; the writer stores it as '
  '-1. num_joined_premium is used by EVF_JOINED only. The final score is the '
  'non-NULL components summed (capped in a joined bracket), multiplied by the '
  'type coefficient and rounded once.';

-- =============================================================================
-- 3 · The stored order and the new components
-- =============================================================================
-- The order: one digit per place (0 = V0 ... 4 = V4), exactly N of them.
ALTER TABLE tbl_tournament
  ADD COLUMN txt_joined_order TEXT,
  ADD CONSTRAINT chk_tournament_joined_order
    CHECK (txt_joined_order IS NULL
      OR (txt_joined_order ~ '^[0-4]+$' AND length(txt_joined_order) = int_participant_count));

ALTER TABLE tbl_tournament_draft
  ADD COLUMN txt_joined_order TEXT,
  ADD CONSTRAINT chk_tournament_draft_joined_order
    CHECK (txt_joined_order IS NULL
      OR (txt_joined_order ~ '^[0-4]+$' AND length(txt_joined_order) = int_participant_count));

COMMENT ON COLUMN tbl_tournament.txt_joined_order IS
  'The category of each place of the listing this tournament was fenced in, '
  'best place first: one digit per place, 0 = V0 ... 4 = V4 (ADR-104 §3). '
  'Every category tournament of the listing stores the same order; the writer '
  'scores the whole bracket from it. NULL for a type whose engine splits a '
  'joined bracket per category (PER_CATEGORY_RENUMBER).';

-- The premium, the cap reduction and d: >= 0 when used, -1 when not. The cap
-- reduction is stored as a positive amount, so it never collides with -1.
ALTER TABLE tbl_result
  ADD COLUMN num_joined_premium NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN num_cap_reduction  NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN int_category_steps INT     NOT NULL DEFAULT -1,
  ADD CONSTRAINT chk_result_joined_premium CHECK (num_joined_premium >= 0 OR num_joined_premium = -1),
  ADD CONSTRAINT chk_result_cap_reduction  CHECK (num_cap_reduction  >= 0 OR num_cap_reduction  = -1),
  ADD CONSTRAINT chk_result_category_steps CHECK (int_category_steps BETWEEN 0 AND 4 OR int_category_steps = -1),
  DROP CONSTRAINT chk_result_components_match_method,
  ADD CONSTRAINT chk_result_components_match_method
    CHECK (enum_score_method IS NULL
      OR (enum_score_method = 'TABLE'
          AND num_de_bonus = -1 AND num_podium_bonus = -1
          AND num_joined_premium = -1 AND num_cap_reduction = -1 AND int_category_steps = -1)
      OR (enum_score_method = 'EVF_CLASSIC'
          AND num_joined_premium = -1 AND num_cap_reduction = -1 AND int_category_steps = -1)
      OR (enum_score_method = 'EVF_JOINED'
          AND num_joined_premium >= 0 AND num_cap_reduction >= 0 AND int_category_steps >= 0));

ALTER TABLE tbl_result_draft
  ADD COLUMN num_joined_premium NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN num_cap_reduction  NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN int_category_steps INT     NOT NULL DEFAULT -1,
  ADD CONSTRAINT chk_result_draft_joined_premium CHECK (num_joined_premium >= 0 OR num_joined_premium = -1),
  ADD CONSTRAINT chk_result_draft_cap_reduction  CHECK (num_cap_reduction  >= 0 OR num_cap_reduction  = -1),
  ADD CONSTRAINT chk_result_draft_category_steps CHECK (int_category_steps BETWEEN 0 AND 4 OR int_category_steps = -1);

COMMENT ON COLUMN tbl_result.num_joined_premium IS
  'EVF_JOINED only: max(EVF x (1 + 0.05 d), EVF + d) - EVF, rounded to 2 '
  'decimals; 0 for the youngest category. -1 when the method does not use it.';
COMMENT ON COLUMN tbl_result.num_cap_reduction IS
  'EVF_JOINED only: how much the cap took off, before the coefficient, '
  'rounded to 2 decimals; 0 where it did not bite. -1 when not used.';
COMMENT ON COLUMN tbl_result.int_category_steps IS
  'EVF_JOINED only: d, the row''s category minus the youngest category of its '
  'bracket (0-4). -1 when not used.';

-- =============================================================================
-- 4 · The strategy: one row, without the cap
-- =============================================================================
CREATE FUNCTION fn_score_spws_evf_joined_v1_2026_2027(
  p_n              INT,
  p_place          INT,
  p_category_steps INT,
  p_joined         BOOLEAN,
  p_mp_value       NUMERIC,
  p_de_round       NUMERIC,
  p_podium_gold    NUMERIC,
  p_podium_silver  NUMERIC,
  p_podium_bronze  NUMERIC
)
RETURNS typ_score_breakdown
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_out  typ_score_breakdown;
  v_evf  typ_score_components;
  v_base NUMERIC;
BEGIN
  IF p_joined IS NULL OR p_category_steps IS NULL
     OR p_category_steps NOT BETWEEN 0 AND 4
     OR (p_category_steps > 0 AND NOT p_joined) THEN
    RAISE EXCEPTION
      'Invalid category steps % (joined: %): d is 0-4 in a joined bracket and 0 in a single category',
      p_category_steps, p_joined;
  END IF;

  -- 1-3 fencers: a meeting, not a competition.
  IF p_n <= 3 THEN
    v_out.num_place_pts     := p_n - p_place + 1;
    v_out.enum_score_method := 'TABLE';
    RETURN v_out;
  END IF;

  v_evf := fn_score_evf_classic_v1_2025_2026(
    p_n, p_place, p_mp_value, 10, p_de_round,
    p_podium_gold, p_podium_silver, p_podium_bronze);
  v_out.num_place_pts    := v_evf.num_place_pts;
  v_out.num_de_bonus     := v_evf.num_de_bonus;
  v_out.num_podium_bonus := v_evf.num_podium_bonus;

  -- A single category, or a bracket of 16 or more: plain EVF.
  IF NOT p_joined OR p_n >= 16 THEN
    v_out.enum_score_method := 'EVF_CLASSIC';
    RETURN v_out;
  END IF;

  -- A joined bracket of 4-15: 5% per category step, at least 1 point per step.
  v_base := COALESCE(v_evf.num_place_pts, 0) + COALESCE(v_evf.num_de_bonus, 0)
          + COALESCE(v_evf.num_podium_bonus, 0);
  v_out.num_joined_premium :=
    GREATEST(v_base * (1 + 0.05 * p_category_steps), v_base + p_category_steps) - v_base;
  v_out.enum_score_method := 'EVF_JOINED';
  RETURN v_out;
END;
$$;

COMMENT ON FUNCTION fn_score_spws_evf_joined_v1_2026_2027(INT, INT, INT, BOOLEAN, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) IS
  'Released strategy SPWS_EVF_JOINED_V1_2026_2027 (ADR-104 §2): one row of a '
  'bracket of N, d category steps above its youngest category, without the '
  'cap. Its constants (the meeting up to 3, the premium up to 15, 5% per step) '
  'belong to this engine version. Never edited once released.';

-- =============================================================================
-- 5 · The dispatcher passes d and the joined flag
-- =============================================================================
DROP FUNCTION IF EXISTS fn_score_by_engine(TEXT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC);

CREATE FUNCTION fn_score_by_engine(
  p_engine_code    TEXT,
  p_n              INT,
  p_place          INT,
  p_category_steps INT,
  p_joined         BOOLEAN,
  p_mp_value       NUMERIC,
  p_de_round       NUMERIC,
  p_podium_gold    NUMERIC,
  p_podium_silver  NUMERIC,
  p_podium_bronze  NUMERIC
)
RETURNS typ_score_breakdown
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_out     typ_score_breakdown;
  v_classic typ_score_components;
BEGIN
  CASE p_engine_code
    WHEN 'EVF_CLASSIC_V1_2025_2026' THEN
      -- d and the joined flag are not inputs of this engine.
      v_classic := fn_score_evf_classic_v1_2025_2026(
        p_n, p_place, p_mp_value, 10, p_de_round,
        p_podium_gold, p_podium_silver, p_podium_bronze);
      v_out.num_place_pts     := v_classic.num_place_pts;
      v_out.num_de_bonus      := v_classic.num_de_bonus;
      v_out.num_podium_bonus  := v_classic.num_podium_bonus;
      v_out.enum_score_method := 'EVF_CLASSIC';
      RETURN v_out;
    WHEN 'SPWS_EVF_JOINED_V1_2026_2027' THEN
      RETURN fn_score_spws_evf_joined_v1_2026_2027(
        p_n, p_place, p_category_steps, p_joined, p_mp_value, p_de_round,
        p_podium_gold, p_podium_silver, p_podium_bronze);
    ELSE
      RAISE EXCEPTION 'Unknown scoring engine: %', p_engine_code;
  END CASE;
END;
$$;

COMMENT ON FUNCTION fn_score_by_engine(TEXT, INT, INT, INT, BOOLEAN, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) IS
  'Static dispatcher over released scoring strategies (ADR-042/ADR-045 '
  'precedent). Adding an engine edits THIS function and adds a new strategy; '
  'it never edits an existing strategy. An unknown code raises.';

-- =============================================================================
-- 6 · The whole bracket, with the cap
-- =============================================================================
-- capped(p) = min(raw(p), capped(p - 1) - 1) from 1st place down, on
-- unrounded values, over the rows the engine scores EVF_JOINED. A meeting, a
-- single category and a bracket of 16 or more are not capped.
CREATE FUNCTION fn_score_joined_bracket(
  p_engine_code   TEXT,
  p_order         TEXT,
  p_mp_value      NUMERIC,
  p_de_round      NUMERIC,
  p_podium_gold   NUMERIC,
  p_podium_silver NUMERIC,
  p_podium_bronze NUMERIC
)
RETURNS TABLE (
  int_place          INT,
  int_category       INT,
  int_category_steps INT,
  enum_score_method  enum_score_method,
  num_place_pts      NUMERIC,
  num_de_bonus       NUMERIC,
  num_podium_bonus   NUMERIC,
  num_joined_premium NUMERIC,
  num_raw            NUMERIC,
  num_cap_reduction  NUMERIC,
  num_capped         NUMERIC
)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_n        INT;
  v_youngest INT;
  v_joined   BOOLEAN;
  v_d        INT;
  v_prev     NUMERIC;
  c          typ_score_breakdown;
BEGIN
  IF p_order IS NULL OR p_order !~ '^[0-4]+$' THEN
    RAISE EXCEPTION 'Invalid category order %: one digit 0-4 per place, best place first', p_order;
  END IF;

  v_n := length(p_order);
  SELECT min(substr(p_order, k, 1)::INT), count(DISTINCT substr(p_order, k, 1)) > 1
    INTO v_youngest, v_joined
    FROM generate_series(1, v_n) k;

  FOR i IN 1..v_n LOOP
    int_place    := i;
    int_category := substr(p_order, i, 1)::INT;
    v_d          := CASE WHEN v_joined THEN int_category - v_youngest ELSE 0 END;

    c := fn_score_by_engine(p_engine_code, v_n, i, v_d, v_joined,
                            p_mp_value, p_de_round, p_podium_gold, p_podium_silver, p_podium_bronze);

    enum_score_method  := c.enum_score_method;
    num_place_pts      := c.num_place_pts;
    num_de_bonus       := c.num_de_bonus;
    num_podium_bonus   := c.num_podium_bonus;
    num_joined_premium := c.num_joined_premium;
    num_raw := COALESCE(c.num_place_pts, 0) + COALESCE(c.num_de_bonus, 0)
             + COALESCE(c.num_podium_bonus, 0) + COALESCE(c.num_joined_premium, 0);

    IF c.enum_score_method = 'EVF_JOINED' THEN
      int_category_steps := v_d;
      num_capped         := CASE WHEN v_prev IS NULL THEN num_raw ELSE LEAST(num_raw, v_prev - 1) END;
      num_cap_reduction  := num_raw - num_capped;
    ELSE
      int_category_steps := NULL;
      num_capped         := num_raw;
      num_cap_reduction  := NULL;
    END IF;

    v_prev := num_capped;
    RETURN NEXT;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION fn_score_joined_bracket(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) IS
  'The whole bracket from its category order (ADR-104 §2): every place through '
  'the dispatcher, then the cap from 1st place down on unrounded values, over '
  'EVF_JOINED rows. Unused components are NULL. The single home of the cap: '
  'the writer, the preview and the tests all read it.';

-- =============================================================================
-- 7 · The writer and the preview
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_calc_tournament_scores(p_tournament_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  p          RECORD;
  v_season   INT;
  v_revision INT;
  v_module   TEXT;
  v_order    TEXT;
  v_category TEXT;
  v_code     TEXT;
  v_bad      INT;
BEGIN
  SELECT * INTO p FROM fn_resolve_scoring_params(p_tournament_id);

  SELECT e.id_season, t.txt_joined_order, t.enum_age_category::TEXT, t.txt_code
    INTO v_season, v_order, v_category, v_code
    FROM tbl_tournament t JOIN tbl_event e ON e.id_event = t.id_event
   WHERE t.id_tournament = p_tournament_id;

  SELECT se.txt_joined_bracket_module INTO v_module
    FROM tbl_scoring_engine se WHERE se.txt_code = p.engine_code;

  -- The refusals come before the revision, which locks the season.
  IF v_module = 'JOINED_BRACKET_CATEGORY_PLACE' THEN
    IF v_order IS NULL THEN
      RAISE EXCEPTION
        'Tournament % (%) is scored by % and has no category order (txt_joined_order): ingest the whole listing so every category tournament stores it',
        p_tournament_id, v_code, p.engine_code;
    END IF;

    SELECT min(r.int_place) INTO v_bad
      FROM tbl_result r
     WHERE r.id_tournament = p_tournament_id
       AND 'V' || substr(v_order, r.int_place, 1) IS DISTINCT FROM v_category;
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION
        'Tournament % (%): in the category order %, place % carries category V%, not %',
        p_tournament_id, v_code, v_order, v_bad, NULLIF(substr(v_order, v_bad, 1), ''), v_category;
    END IF;
  END IF;

  v_revision := fn_ensure_active_scoring_revision(v_season);

  IF v_module = 'JOINED_BRACKET_CATEGORY_PLACE' THEN
    -- The whole bracket is scored from the order; only this tournament's rows
    -- are written, so scoring never reads a sibling's rows.
    UPDATE tbl_result r
       SET num_place_pts       = COALESCE(ROUND(b.num_place_pts, 2),      -1),
           num_de_bonus        = COALESCE(ROUND(b.num_de_bonus, 2),       -1),
           num_podium_bonus    = COALESCE(ROUND(b.num_podium_bonus, 2),   -1),
           num_joined_premium  = COALESCE(ROUND(b.num_joined_premium, 2), -1),
           num_cap_reduction   = COALESCE(ROUND(b.num_cap_reduction, 2),  -1),
           int_category_steps  = COALESCE(b.int_category_steps,           -1),
           enum_score_method   = b.enum_score_method,
           -- The coefficient multiplies the capped value; rounded ONCE.
           num_final_score     = ROUND(b.num_capped * p.multiplier, 2),
           ts_points_calc      = NOW(),
           id_scoring_revision = v_revision
      FROM fn_score_joined_bracket(p.engine_code, v_order, p.mp_value, p.de_round,
                                   p.podium_gold, p.podium_silver, p.podium_bronze) b
     WHERE r.id_tournament = p_tournament_id
       AND r.int_place = b.int_place;
  ELSE
    UPDATE tbl_result r
       SET num_place_pts      = COALESCE(ROUND(c.num_place_pts, 2),    -1),
           num_de_bonus       = COALESCE(ROUND(c.num_de_bonus, 2),     -1),
           num_podium_bonus   = COALESCE(ROUND(c.num_podium_bonus, 2), -1),
           num_joined_premium = -1,
           num_cap_reduction  = -1,
           int_category_steps = -1,
           enum_score_method  = c.enum_score_method,
           -- Rounded ONCE, from the raw terms. An unused component is NULL in
           -- the breakdown and adds nothing; -1 is never summed.
           num_final_score    = ROUND(
             (COALESCE(c.num_place_pts, 0) + COALESCE(c.num_de_bonus, 0)
              + COALESCE(c.num_podium_bonus, 0))
             * p.multiplier, 2),
           ts_points_calc      = NOW(),
           id_scoring_revision = v_revision
      FROM (
        SELECT r2.id_result, (x.comp).*
          FROM tbl_result r2
          CROSS JOIN LATERAL (
            SELECT fn_score_by_engine(
                     p.engine_code, p.n, r2.int_place, 0, FALSE,
                     p.mp_value, p.de_round,
                     p.podium_gold, p.podium_silver, p.podium_bronze) AS comp
          ) x
         WHERE r2.id_tournament = p_tournament_id
      ) c
     WHERE r.id_result = c.id_result;
  END IF;

  UPDATE tbl_tournament
     SET enum_import_status = 'SCORED',
         ts_updated = NOW()
   WHERE id_tournament = p_tournament_id;
END;
$$;

COMMENT ON FUNCTION fn_calc_tournament_scores(INT) IS
  'The stable transactional scoring writer. Resolves the engine of the '
  'tournament''s type; under JOINED_BRACKET_CATEGORY_PLACE scores the whole '
  'bracket from txt_joined_order through fn_score_joined_bracket and refuses a '
  'missing order or a row the order places in another category; otherwise '
  'dispatches per row. Holds no formula of its own. Stores every component, '
  '-1 where the method does not use it, and the method itself.';

DROP FUNCTION IF EXISTS fn_preview_tournament_score(INT, INT);

CREATE FUNCTION fn_preview_tournament_score(p_tournament_id INT, p_place INT)
RETURNS TABLE (
  txt_engine_code    TEXT,
  num_place_pts      NUMERIC,
  num_de_bonus       NUMERIC,
  num_podium_bonus   NUMERIC,
  enum_score_method  TEXT,
  num_final_score    NUMERIC,
  num_joined_premium NUMERIC,
  num_cap_reduction  NUMERIC,
  int_category_steps INT
)
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  p        RECORD;
  v_module TEXT;
  v_order  TEXT;
  b        RECORD;
  c        typ_score_breakdown;
BEGIN
  SELECT * INTO p FROM fn_resolve_scoring_params(p_tournament_id);
  SELECT se.txt_joined_bracket_module INTO v_module
    FROM tbl_scoring_engine se WHERE se.txt_code = p.engine_code;

  IF v_module = 'JOINED_BRACKET_CATEGORY_PLACE' THEN
    SELECT t.txt_joined_order INTO v_order FROM tbl_tournament t WHERE t.id_tournament = p_tournament_id;
    IF v_order IS NULL THEN
      RAISE EXCEPTION 'Tournament % is scored by % and has no category order (txt_joined_order)',
        p_tournament_id, p.engine_code;
    END IF;

    SELECT x.* INTO b
      FROM fn_score_joined_bracket(p.engine_code, v_order, p.mp_value, p.de_round,
                                   p.podium_gold, p.podium_silver, p.podium_bronze) x
     WHERE x.int_place = p_place;

    RETURN QUERY SELECT
      p.engine_code,
      COALESCE(ROUND(b.num_place_pts, 2),      -1),
      COALESCE(ROUND(b.num_de_bonus, 2),       -1),
      COALESCE(ROUND(b.num_podium_bonus, 2),   -1),
      b.enum_score_method::TEXT,
      ROUND(b.num_capped * p.multiplier, 2),
      COALESCE(ROUND(b.num_joined_premium, 2), -1),
      COALESCE(ROUND(b.num_cap_reduction, 2),  -1),
      COALESCE(b.int_category_steps,           -1);
    RETURN;
  END IF;

  c := fn_score_by_engine(p.engine_code, p.n, p_place, 0, FALSE,
                          p.mp_value, p.de_round,
                          p.podium_gold, p.podium_silver, p.podium_bronze);

  RETURN QUERY SELECT
    p.engine_code,
    COALESCE(ROUND(c.num_place_pts, 2),    -1),
    COALESCE(ROUND(c.num_de_bonus, 2),     -1),
    COALESCE(ROUND(c.num_podium_bonus, 2), -1),
    c.enum_score_method::TEXT,
    ROUND((COALESCE(c.num_place_pts, 0) + COALESCE(c.num_de_bonus, 0)
           + COALESCE(c.num_podium_bonus, 0))
          * p.multiplier, 2),
    -1::NUMERIC,
    -1::NUMERIC,
    -1;
END;
$$;

COMMENT ON FUNCTION fn_preview_tournament_score(INT, INT) IS
  'Read-only preview over the same resolver, chain, dispatcher and strategies '
  'the writer uses. STABLE, so it cannot write. Returns the capped final score '
  'and rounds exactly as the writer stores.';

-- =============================================================================
-- 8 · The ingest RPC takes the order; the draft commit carries it
-- =============================================================================
DROP FUNCTION IF EXISTS fn_ingest_tournament_results(INT, JSONB, INT);

CREATE FUNCTION public.fn_ingest_tournament_results(
  p_tournament_id     integer,
  p_results           jsonb,
  p_participant_count integer DEFAULT NULL::integer,
  p_joined_order      text    DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_count           INT;
  v_row             JSONB;
  v_result_id       INT;
  v_fencer_id       INT;
  v_event_id        INT;
  v_legacy_status   TEXT;
  v_method_text     TEXT;
  v_method          enum_match_method;
  v_source_vcat     enum_age_category;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = p_tournament_id) THEN
    RAISE EXCEPTION 'Tournament % does not exist', p_tournament_id;
  END IF;

  IF p_results IS NULL OR jsonb_array_length(p_results) = 0 THEN
    RAISE EXCEPTION 'Results array is empty';
  END IF;

  SELECT id_event INTO v_event_id
    FROM tbl_tournament WHERE id_tournament = p_tournament_id;

  DELETE FROM tbl_match_candidate
  WHERE id_result IN (
    SELECT id_result FROM tbl_result WHERE id_tournament = p_tournament_id
  );

  DELETE FROM tbl_result WHERE id_tournament = p_tournament_id;

  -- ADR-104 §3: the order has one digit per place of the whole listing, so it
  -- also gives N when no count is passed.
  v_count := COALESCE(p_participant_count, length(p_joined_order), jsonb_array_length(p_results));

  UPDATE tbl_tournament
  SET int_participant_count = v_count,
      txt_joined_order      = p_joined_order,
      enum_import_status    = 'IMPORTED',
      ts_updated            = NOW()
  WHERE id_tournament = p_tournament_id;

  FOR v_row IN SELECT jsonb_array_elements(p_results)
  LOOP
    v_fencer_id := (v_row ->> 'id_fencer')::INT;
    IF NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = v_fencer_id) THEN
      RAISE EXCEPTION 'Fencer % does not exist', v_fencer_id;
    END IF;

    -- NEW: direct enum_match_method from payload (preserves NULL).
    -- When the key is present in the payload object, trust it verbatim —
    -- even if the value is JSON null or empty string (both map to NULL).
    -- When the key is absent, fall back to legacy enum_match_status with
    -- the historical default of AUTO_MATCH.
    IF v_row ? 'enum_match_method' THEN
      v_method_text := v_row ->> 'enum_match_method';
      IF v_method_text IS NULL OR v_method_text = '' THEN
        v_method := NULL;
      ELSE
        v_method := v_method_text::enum_match_method;
      END IF;
    ELSE
      v_legacy_status := COALESCE(v_row ->> 'enum_match_status', 'AUTO_MATCHED');
      v_method := CASE v_legacy_status
        WHEN 'AUTO_MATCHED' THEN 'AUTO_MATCH'::enum_match_method
        WHEN 'APPROVED'     THEN 'USER_CONFIRMED'::enum_match_method
        WHEN 'NEW_FENCER'   THEN 'AUTO_CREATED'::enum_match_method
        ELSE 'AUTO_MATCH'::enum_match_method
      END;
    END IF;

    -- For the legacy tbl_match_candidate row, derive a status from the
    -- (possibly NULL) method. Match-candidate enum has no NULL value, so
    -- a NULL method maps to AUTO_MATCHED (workflow-state best guess) —
    -- this preserves prior behavior for that table since it's slated for
    -- removal in Phase 6.
    v_legacy_status := COALESCE(v_row ->> 'enum_match_status',
      CASE v_method::TEXT
        WHEN 'AUTO_MATCH'      THEN 'AUTO_MATCHED'
        WHEN 'USER_CONFIRMED'  THEN 'APPROVED'
        WHEN 'AUTO_CREATED'    THEN 'NEW_FENCER'
        ELSE 'AUTO_MATCHED'
      END);

    v_source_vcat := CASE
      WHEN v_row ? 'enum_source_age_category' AND NULLIF(v_row ->> 'enum_source_age_category', '') IS NOT NULL
        THEN (v_row ->> 'enum_source_age_category')::enum_age_category
      ELSE NULL
    END;

    INSERT INTO tbl_result (
      id_fencer, id_tournament, int_place,
      txt_scraped_name, num_match_confidence, enum_match_method,
      enum_source_age_category
    )
    VALUES (
      v_fencer_id,
      p_tournament_id,
      (v_row ->> 'int_place')::INT,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC(5,2), 100),
      v_method,
      v_source_vcat
    )
    RETURNING id_result INTO v_result_id;

    INSERT INTO tbl_match_candidate (
      id_result, id_fencer,
      txt_scraped_name, num_confidence, enum_status
    ) VALUES (
      v_result_id,
      v_fencer_id,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC, 100),
      v_legacy_status::enum_match_status
    );
  END LOOP;

  PERFORM fn_calc_tournament_scores(p_tournament_id);

  UPDATE tbl_event
  SET enum_status = 'IN_PROGRESS', ts_updated = NOW()
  WHERE id_event = v_event_id
    AND enum_status = 'PLANNED';

  RETURN jsonb_build_object(
    'tournament_id',     p_tournament_id,
    'results_count',     jsonb_array_length(p_results),
    'participant_count', v_count,
    'status',            'IMPORTED'
  );
END;
$function$;

COMMENT ON FUNCTION fn_ingest_tournament_results(INT, JSONB, INT, TEXT) IS
  'Replaces one tournament''s results atomically and scores them. '
  'p_joined_order (ADR-104 §3) is the listing''s category order, stored on the '
  'tournament; the joined engine scores the whole bracket from it.';

CREATE OR REPLACE FUNCTION public.fn_commit_event_draft(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_committed_tournaments INT := 0;
    v_committed_results     INT := 0;
    v_joint_flagged         INT := 0;
    v_history_rows          INT := 0;
    v_tournaments_scored    INT := 0;
    v_t                     INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tbl_tournament_draft WHERE txt_run_id = p_run_id) THEN
        RETURN jsonb_build_object(
            'run_id', p_run_id,
            'tournaments_committed', 0,
            'results_committed',     0,
            'joint_pool_siblings_flagged', 0,
            'history_rows',          0,
            'tournaments_scored',    0
        );
    END IF;

    CREATE TEMP TABLE _commit_map (
        id_tournament_draft INT NOT NULL,
        id_tournament       INT NOT NULL
    ) ON COMMIT DROP;

    WITH ins AS (
        INSERT INTO tbl_tournament (
            id_event, txt_code, txt_name, enum_type, num_multiplier,
            enum_age_category, enum_weapon, enum_gender, dt_tournament,
            int_participant_count, txt_import_status_reason,
            enum_import_status, url_results, txt_source_url_used,
            enum_parser_kind, dt_last_scraped, bool_joint_pool_split,
            txt_joined_order
        )
        SELECT id_event, txt_code, txt_name, enum_type, num_multiplier,
               enum_age_category, enum_weapon, enum_gender, dt_tournament,
               int_participant_count, txt_import_status_reason,
               enum_import_status, url_results, txt_source_url_used,
               enum_parser_kind, dt_last_scraped, bool_joint_pool_split,
               txt_joined_order
          FROM tbl_tournament_draft
         WHERE txt_run_id = p_run_id
        RETURNING id_tournament, txt_code
    )
    INSERT INTO _commit_map (id_tournament_draft, id_tournament)
    SELECT td.id_tournament_draft, ins.id_tournament
      FROM ins
      JOIN tbl_tournament_draft td ON td.txt_code = ins.txt_code
     WHERE td.txt_run_id = p_run_id;

    GET DIAGNOSTICS v_committed_tournaments = ROW_COUNT;

    -- 5.18.B — added enum_source_age_category to BOTH sides so the source
    -- V-cat survives draft → live commit (alias-modal pre-fill needs it).
    INSERT INTO tbl_result (
        id_fencer, id_tournament, int_place, enum_fencer_age_category,
        txt_cross_cat, num_place_pts, num_de_bonus, num_podium_bonus,
        num_final_score, ts_points_calc,
        txt_scraped_name, num_match_confidence, enum_match_method,
        enum_source_age_category, enum_score_method,
        num_joined_premium, num_cap_reduction, int_category_steps
    )
    SELECT rd.id_fencer, m.id_tournament, rd.int_place, rd.enum_fencer_age_category,
           rd.txt_cross_cat, rd.num_place_pts, rd.num_de_bonus, rd.num_podium_bonus,
           rd.num_final_score, rd.ts_points_calc,
           rd.txt_scraped_name, rd.num_match_confidence, rd.enum_match_method,
           rd.enum_source_age_category, rd.enum_score_method,
           rd.num_joined_premium, rd.num_cap_reduction, rd.int_category_steps
      FROM tbl_result_draft rd
      JOIN _commit_map m ON m.id_tournament_draft = rd.id_tournament_draft
     WHERE rd.txt_run_id = p_run_id;

    GET DIAGNOSTICS v_committed_results = ROW_COUNT;

    UPDATE tbl_tournament t
       SET bool_joint_pool_split = TRUE
      FROM (
        SELECT t1.id_event, t1.enum_weapon, t1.enum_gender, t1.url_results
          FROM tbl_tournament t1
          JOIN _commit_map m ON m.id_tournament = t1.id_tournament
         WHERE t1.url_results IS NOT NULL AND t1.url_results <> ''
         GROUP BY t1.id_event, t1.enum_weapon, t1.enum_gender, t1.url_results
        HAVING COUNT(*) > 1
      ) g
     WHERE t.id_event    = g.id_event
       AND t.enum_weapon = g.enum_weapon
       AND t.enum_gender = g.enum_gender
       AND t.url_results = g.url_results
       AND t.bool_joint_pool_split = FALSE;

    GET DIAGNOSTICS v_joint_flagged = ROW_COUNT;

    -- ADR-049 AMENDED 2026-06-04: per-V-cat own count, NOT the full-pool sum.
    -- Group by id_tournament so each joint sibling stores ONLY its own result
    -- rows (was: GROUP BY url_results, which summed across all siblings).
    -- ADR-104 §3: a tournament that carries a category order keeps the joined
    -- N; the order's length is N and the joined engine scores by it.
    UPDATE tbl_tournament t
       SET int_participant_count = ps.sz
      FROM (
        SELECT tt.id_tournament,
               COUNT(r.id_result)::INT AS sz
          FROM tbl_tournament tt
          JOIN _commit_map m ON m.id_tournament = tt.id_tournament
          JOIN tbl_result r ON r.id_tournament = tt.id_tournament
         WHERE tt.bool_joint_pool_split = TRUE
           AND tt.txt_joined_order IS NULL
         GROUP BY tt.id_tournament
      ) ps
     WHERE t.id_tournament = ps.id_tournament
       AND t.bool_joint_pool_split = TRUE;

    -- Score every newly-committed tournament. Phase 5 historical re-ingest:
    -- events are 3+ years old, results are final — no async scoring step.
    FOR v_t IN SELECT id_tournament FROM _commit_map LOOP
        BEGIN
            PERFORM fn_calc_tournament_scores(v_t);
            v_tournaments_scored := v_tournaments_scored + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'fn_calc_tournament_scores(%) failed during commit %: %',
                          v_t, p_run_id, SQLERRM;
        END;
    END LOOP;

    INSERT INTO tbl_tournament_ingest_history (
        id_tournament, txt_run_id, enum_parser_kind, txt_source_url
    )
    SELECT m.id_tournament, p_run_id, td.enum_parser_kind, td.txt_source_url_used
      FROM tbl_tournament_draft td
      JOIN _commit_map m ON m.id_tournament_draft = td.id_tournament_draft
     WHERE td.txt_run_id = p_run_id
       AND td.enum_parser_kind IS NOT NULL;

    GET DIAGNOSTICS v_history_rows = ROW_COUNT;

    INSERT INTO tbl_event_ingest_history (
        id_event, txt_run_id, enum_parser_kind, txt_source_url
    )
    SELECT DISTINCT ON (td.id_event)
           td.id_event, p_run_id, td.enum_parser_kind, td.txt_source_url_used
      FROM tbl_tournament_draft td
     WHERE td.txt_run_id = p_run_id
       AND td.enum_parser_kind IS NOT NULL
     ORDER BY td.id_event, td.id_tournament_draft;

    INSERT INTO tbl_audit_log (
        txt_table_name, id_row, txt_action,
        jsonb_old_values, jsonb_new_values, txt_admin_user
    )
    SELECT 'tbl_tournament', m.id_tournament, 'DRAFT_COMMIT',
           NULL::JSONB,
           jsonb_build_object('run_id', p_run_id, 'committed_at', NOW()),
           current_setting('request.jwt.claims', TRUE)::JSONB->>'sub'
      FROM _commit_map m;

    DELETE FROM tbl_result_draft     WHERE txt_run_id = p_run_id;
    DELETE FROM tbl_tournament_draft WHERE txt_run_id = p_run_id;

    DROP TABLE _commit_map;

    RETURN jsonb_build_object(
        'run_id', p_run_id,
        'tournaments_committed', v_committed_tournaments,
        'results_committed',     v_committed_results,
        'joint_pool_siblings_flagged', v_joint_flagged,
        'history_rows',          v_history_rows,
        'tournaments_scored',    v_tournaments_scored
    );
END;
$function$;

-- =============================================================================
-- 9 · The readers publish the new components
-- =============================================================================
-- vw_score gains them at the end (CREATE OR REPLACE may only append); the
-- rolling functions change their result type, so they are recreated.
CREATE OR REPLACE VIEW vw_score AS
 SELECT r.id_result,
    r.id_fencer,
    (f.txt_surname || ' '::text) || f.txt_first_name AS fencer_name,
    f.int_birth_year,
    t.id_tournament,
    t.txt_code AS txt_tournament_code,
    t.txt_name AS txt_tournament_name,
    t.dt_tournament,
    t.enum_type,
    t.enum_weapon,
    t.enum_gender,
    t.enum_age_category,
    t.int_participant_count,
    t.num_multiplier,
    r.int_place,
    r.num_place_pts,
    r.num_de_bonus,
    r.num_podium_bonus,
    r.num_final_score,
    r.ts_points_calc,
    s.id_season,
    s.txt_code AS txt_season_code,
    t.url_results,
    e.txt_location,
    r.enum_score_method,
    r.num_joined_premium,
    r.num_cap_reduction,
    r.int_category_steps
   FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_event e ON e.id_event = t.id_event
     JOIN tbl_season s ON s.id_season = e.id_season
     LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
  WHERE r.id_fencer IS NOT NULL;

DROP FUNCTION IF EXISTS fn_fencer_scores_rolling(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer);
DROP FUNCTION IF EXISTS fn_fencer_scores_rolling_event_code_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer);
DROP FUNCTION IF EXISTS fn_fencer_scores_rolling_event_fk_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer);

CREATE FUNCTION public.fn_fencer_scores_rolling_event_code_matching(p_fencer_id integer, p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer)
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text, enum_score_method text, num_joined_premium numeric, num_cap_reduction numeric, int_category_steps integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_season_id      INT;
  v_prev_season_id INT;
  v_season_end_yr  INT;
  v_rules          JSONB;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  SELECT s.id_season INTO v_prev_season_id
    FROM tbl_season s
   WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
   ORDER BY s.dt_end DESC
   LIMIT 1;

  RETURN QUERY
  WITH
    -- Tournament types from ranking rules — domestic + international (ADR-021)
    rules_types AS (
      SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
        FROM jsonb_array_elements(
          COALESCE(v_rules -> 'domestic', '[]'::JSONB) || COALESCE(v_rules -> 'international', '[]'::JSONB)
        ) AS b(value)
    ),
    -- Positions the current season already HAS a result for (ADR-018/021 amend)
    completed_positions AS (
      SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
        FROM tbl_event ev
        JOIN tbl_tournament t ON t.id_event = ev.id_event
        JOIN tbl_result r ON r.id_tournament = t.id_tournament
       WHERE ev.id_season = v_season_id
         AND t.enum_weapon = p_weapon
         AND t.enum_gender = p_gender
         AND r.num_final_score IS NOT NULL
    ),
    -- Current-season scores
    current_scores AS (
      SELECT
        r.id_result, r.id_fencer,
        f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
        f.int_birth_year,
        t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
        t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
        t.int_participant_count, t.num_multiplier,
        r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
        r.num_final_score, r.ts_points_calc,
        s.id_season, s.txt_code AS txt_season_code,
        t.url_results, ev.txt_location,
        FALSE AS bool_carried_over,
        s.txt_code AS txt_source_season_code,
        r.enum_score_method::TEXT AS enum_score_method,
        r.num_joined_premium, r.num_cap_reduction, r.int_category_steps
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event ev     ON ev.id_event = t.id_event
      JOIN tbl_season s     ON s.id_season = ev.id_season
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      WHERE r.id_fencer = p_fencer_id
        AND ev.id_season = v_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
        AND r.num_final_score IS NOT NULL
    ),
    -- Carried-over scores from previous season
    carried_scores AS (
      SELECT
        r.id_result, r.id_fencer,
        f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
        f.int_birth_year,
        t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
        t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
        t.int_participant_count, t.num_multiplier,
        r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
        r.num_final_score, r.ts_points_calc,
        prev_s.id_season, prev_s.txt_code AS txt_season_code,
        t.url_results, ev.txt_location,
        TRUE AS bool_carried_over,
        prev_s.txt_code AS txt_source_season_code,
        r.enum_score_method::TEXT AS enum_score_method,
        r.num_joined_premium, r.num_cap_reduction, r.int_category_steps
      FROM tbl_result r
      JOIN tbl_tournament t  ON t.id_tournament = r.id_tournament
      JOIN tbl_event ev      ON ev.id_event = t.id_event
      JOIN tbl_season prev_s ON prev_s.id_season = ev.id_season
      JOIN tbl_fencer f      ON f.id_fencer = r.id_fencer
      WHERE v_prev_season_id IS NOT NULL
        AND r.id_fencer = p_fencer_id
        AND ev.id_season = v_prev_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        -- Type must be in ranking rules AND position not yet completed (ADR-021)
        AND t.enum_type::TEXT IN (SELECT type_code FROM rules_types)
        AND fn_event_position(ev.txt_code) NOT IN (SELECT pos FROM completed_positions)
    )
  SELECT * FROM current_scores
  UNION ALL
  SELECT * FROM carried_scores
  ORDER BY num_final_score DESC;
END;
$function$;

CREATE FUNCTION public.fn_fencer_scores_rolling_event_fk_matching(p_fencer_id integer, p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer)
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text, enum_score_method text, num_joined_premium numeric, num_cap_reduction numeric, int_category_steps integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_season_id     INT;
  v_season_end_yr INT;
  v_rules         JSONB;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  RETURN QUERY
  WITH
    rules_types AS (
      SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
        FROM jsonb_array_elements(
          COALESCE(v_rules -> 'domestic', '[]'::JSONB) || COALESCE(v_rules -> 'international', '[]'::JSONB)
        ) AS b(value)
    )
  SELECT
    r.id_result, r.id_fencer,
    f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
    f.int_birth_year,
    t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
    t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
    t.int_participant_count, t.num_multiplier,
    r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
    r.num_final_score, r.ts_points_calc,
    src_s.id_season, src_s.txt_code AS txt_season_code,
    t.url_results, src_e.txt_location,
    v.is_carried AS bool_carried_over,
    src_s.txt_code AS txt_source_season_code,
    r.enum_score_method::TEXT AS enum_score_method,
    r.num_joined_premium, r.num_cap_reduction, r.int_category_steps
  FROM vw_eligible_event v
  JOIN tbl_tournament t   ON t.id_event = v.id_event
  JOIN tbl_result r       ON r.id_tournament = t.id_tournament
  JOIN tbl_fencer f       ON f.id_fencer = r.id_fencer
  JOIN tbl_event src_e    ON src_e.id_event = v.source_event_id
  JOIN tbl_season src_s   ON src_s.id_season = src_e.id_season
  WHERE v.effective_season_id = v_season_id
    AND r.id_fencer = p_fencer_id
    AND t.enum_weapon = p_weapon
    AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
    AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
    AND r.num_final_score IS NOT NULL
    AND (NOT v.is_carried OR t.enum_type::TEXT IN (SELECT type_code FROM rules_types))
  ORDER BY r.num_final_score DESC;
END;
$function$;

CREATE FUNCTION public.fn_fencer_scores_rolling(p_fencer_id integer, p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer)
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text, enum_score_method text, num_joined_premium numeric, num_cap_reduction numeric, int_category_steps integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_engine          enum_event_carryover_engine;
  v_resolved_season INT;
BEGIN
  v_resolved_season := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT s.enum_carryover_engine INTO v_engine
    FROM tbl_season s WHERE s.id_season = v_resolved_season;

  CASE v_engine
    WHEN 'EVENT_CODE_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_fencer_scores_rolling_event_code_matching(
        p_fencer_id, p_weapon, p_gender, p_category, p_season
      );
    WHEN 'EVENT_FK_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_fencer_scores_rolling_event_fk_matching(
        p_fencer_id, p_weapon, p_gender, p_category, p_season
      );
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$function$;

-- =============================================================================
-- 10 · The joining check's verdicts (ADR-104 §7)
-- =============================================================================
-- One row per event, weapon and gender: how the listing was fenced, how § 2
-- would join it, and whether they agree. Written by the pipeline with the
-- service role at the end of each event run and after each recompute; the
-- Telegram message goes out only when bool_match changes.
CREATE TABLE tbl_joining_check (
  id_event    INT              NOT NULL REFERENCES tbl_event (id_event) ON DELETE CASCADE,
  enum_weapon enum_weapon_type NOT NULL,
  enum_gender enum_gender_type NOT NULL,
  txt_fenced  TEXT             NOT NULL,
  txt_rule    TEXT             NOT NULL,
  bool_match  BOOLEAN          NOT NULL,
  ts_checked  TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id_event, enum_weapon, enum_gender)
);

COMMENT ON TABLE tbl_joining_check IS
  'ADR-104 §7: the automatic check of the scoring table''s § 2 joining rules. '
  'txt_fenced is the grouping as fenced, txt_rule the grouping § 2 gives for '
  'the same category sizes. Every listing is scored as fenced; a mismatch is '
  'reported once on Telegram, never blocks and needs no sign-off.';

ALTER TABLE tbl_joining_check ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 11 · The assignment
-- =============================================================================
-- SPWS-2026-2027's default, PPW and MPW move to the joined engine; the other
-- six types stay on EVF classic. Only while the season holds no scored result
-- and no scoring revision (ADR-097 §11): otherwise a NOTICE, and no move.
DO $assign$
DECLARE
  v_season  INT;
  v_joined  INT;
  v_scored  INT;
  v_locked  BOOLEAN;
BEGIN
  SELECT id_engine INTO v_joined FROM tbl_scoring_engine WHERE txt_code = 'SPWS_EVF_JOINED_V1_2026_2027';
  SELECT id_season, (ts_scoring_locked_at IS NOT NULL OR id_active_scoring_revision IS NOT NULL)
    INTO v_season, v_locked
    FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  IF v_season IS NULL THEN
    RETURN;  -- a fresh bootstrap: fn_backfill_scoring_engines() assigns it after the seed
  END IF;

  SELECT count(*) INTO v_scored
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e      ON e.id_event      = t.id_event
   WHERE e.id_season = v_season AND r.ts_points_calc IS NOT NULL;

  IF v_scored > 0 OR v_locked THEN
    RAISE NOTICE
      'SPWS-2026-2027 holds % scored result(s) (locked: %) and is left as it stands: a scored season is never reassigned (ADR-097 §11). Moving it to SPWS_EVF_JOINED_V1_2026_2027 takes a privileged revision (ADR-104).',
      v_scored, v_locked;
    RETURN;
  END IF;

  UPDATE tbl_season SET id_scoring_engine = v_joined WHERE id_season = v_season;

  UPDATE tbl_scoring_type_config tc
     SET id_scoring_engine = v_joined,
         ts_updated = NOW()
    FROM tbl_scoring_config c
   WHERE c.id_config = tc.id_config
     AND c.id_season = v_season
     AND tc.enum_type IN ('PPW', 'MPW');
END $assign$;

-- Replaces the interim of 20260930000001. Fills only what is unassigned, so a
-- deliberate assignment is never overwritten and a scored season never moves.
CREATE OR REPLACE FUNCTION fn_backfill_scoring_engines()
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $backfill$
DECLARE
  v_classic   INT;
  v_joined    INT;
  v_deviant   TEXT;
  v_season    INT;
  v_scored    INT;
BEGIN
  SELECT id_engine INTO v_classic FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026';
  SELECT id_engine INTO v_joined  FROM tbl_scoring_engine WHERE txt_code = 'SPWS_EVF_JOINED_V1_2026_2027';

  -- Assigning EVF_CLASSIC_V1_2025_2026 to a historical season is only truthful
  -- if that season was scored with the base it reproduces. mp_value and the
  -- podium coefficients are season configuration, so they are read per season.
  SELECT string_agg(s.txt_code || ' (mp=' || c.int_mp_value || ', podium='
                    || c.int_podium_gold || '/' || c.int_podium_silver || '/'
                    || c.int_podium_bronze || ')', '; ' ORDER BY s.txt_code)
    INTO v_deviant
    FROM tbl_season s
    JOIN tbl_scoring_config c ON c.id_season = s.id_season
   WHERE s.txt_code < 'SPWS-2026-2027'
     AND (c.int_mp_value <> 50 OR c.int_podium_gold <> 3
          OR c.int_podium_silver <> 2 OR c.int_podium_bronze <> 1);

  IF v_deviant IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot assign EVF_CLASSIC_V1_2025_2026: these seasons were not scored with the base it reproduces: %. Each needs its own frozen engine rather than silent coercion.',
      v_deviant;
  END IF;

  UPDATE tbl_season s
     SET id_scoring_engine = v_classic
   WHERE s.txt_code < 'SPWS-2026-2027' AND s.id_scoring_engine IS NULL;

  SELECT s.id_season INTO v_season FROM tbl_season s WHERE s.txt_code = 'SPWS-2026-2027';

  IF v_season IS NOT NULL THEN
    SELECT count(*) INTO v_scored
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event e      ON e.id_event      = t.id_event
     WHERE e.id_season = v_season AND r.ts_points_calc IS NOT NULL;

    IF v_scored = 0 THEN
      UPDATE tbl_season
         SET id_scoring_engine = v_joined
       WHERE id_season = v_season AND id_scoring_engine IS NULL;

      UPDATE tbl_scoring_type_config tc
         SET id_scoring_engine = CASE WHEN tc.enum_type IN ('PPW', 'MPW') THEN v_joined ELSE v_classic END,
             ts_updated = NOW()
        FROM tbl_scoring_config c
       WHERE c.id_config = tc.id_config
         AND c.id_season = v_season
         AND tc.id_scoring_engine IS NULL;
    END IF;
  END IF;

  -- Any other season that predates this call and holds no assignment falls
  -- back to the classic engine. A deliberate assignment is never overwritten.
  UPDATE tbl_season s
     SET id_scoring_engine = v_classic
   WHERE s.id_scoring_engine IS NULL AND s.ts_created < NOW();
END;
$backfill$;

COMMENT ON FUNCTION fn_backfill_scoring_engines() IS
  'Idempotent engine backfill (ADR-104 §5): EVF classic for history; for an '
  'unscored SPWS-2026-2027 the season default, PPW and MPW on '
  'SPWS_EVF_JOINED_V1_2026_2027 and the other six types on EVF classic, each '
  'type row set explicitly. Fills only unassigned rows and never reassigns a '
  'scored season. Called again from supabase/seed_post_backfill.sql because '
  'migrations run before the seed (ADR-036 amendment).';

SELECT fn_backfill_scoring_engines();

-- =============================================================================
-- 12 · ADR-083 deny-by-default: every new or recreated object states its grants
-- =============================================================================
REVOKE EXECUTE ON FUNCTION fn_score_spws_evf_joined_v1_2026_2027(INT, INT, INT, BOOLEAN, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_score_spws_evf_joined_v1_2026_2027(INT, INT, INT, BOOLEAN, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
  TO service_role;

REVOKE EXECUTE ON FUNCTION fn_score_by_engine(TEXT, INT, INT, INT, BOOLEAN, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_score_by_engine(TEXT, INT, INT, INT, BOOLEAN, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
  TO service_role;

REVOKE EXECUTE ON FUNCTION fn_score_joined_bracket(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_score_joined_bracket(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
  TO service_role;

REVOKE EXECUTE ON FUNCTION fn_preview_tournament_score(INT, INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_preview_tournament_score(INT, INT) TO service_role;

REVOKE EXECUTE ON FUNCTION fn_ingest_tournament_results(INT, JSONB, INT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_ingest_tournament_results(INT, JSONB, INT, TEXT) TO authenticated, service_role;

GRANT SELECT ON vw_score TO anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION fn_fencer_scores_rolling(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION fn_fencer_scores_rolling_event_code_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION fn_fencer_scores_rolling_event_fk_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer)
  TO anon, authenticated, service_role;

REVOKE ALL ON tbl_joining_check FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tbl_joining_check TO service_role;
