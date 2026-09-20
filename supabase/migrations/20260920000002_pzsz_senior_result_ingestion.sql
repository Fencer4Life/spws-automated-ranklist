-- =============================================================================
-- PZSz senior result ingestion: the SENIOR-result guard and the match review queue
-- =============================================================================
-- Design step 6, doc/plans/pzsz-senior-result-ingestion-2026-09-19.html §04.
-- ADR-100. RTM SS26.TYPE.06e-f, SS26.PZSZ.05.
--
-- Two independent pieces, both needed before any PZSz result can be written:
--
-- 1. SENIOR is a legitimate tbl_tournament.enum_age_category (the source
--    bracket a PZSz PPS/MPS field competes in) but must never be a RESULT's
--    own effective category -- a veteran's result always carries a real V-cat
--    (via enum_source_age_category, ADR-056) or NULL, never SENIOR. Requires
--    20260920000001 (SENIOR was added to enum_age_category there, in its own
--    transaction, since a new enum value cannot be used in the transaction
--    that adds it).
--
-- 2. tbl_pzsz_match_review holds an uncertain PZSz match pending an
--    administrator's decision. No existing table fits: tbl_match_candidate
--    requires an already-committed tbl_result row (id_result NOT NULL) -- it
--    is a post-write correction table, not a pre-write hold -- and a genuinely
--    uncertain PZSz match must NOT be written into tbl_result at all (that
--    column is a real, NOT NULL foreign key to a real fencer; publishing a
--    guess, even provisionally, is a bigger mistake than a competitor's row
--    not appearing for a few days). Modeled directly on
--    tbl_registration_identity_override's already-proven shape (dedicated
--    table, nullable candidate FK, CHECK-constrained status, decision
--    timestamp, admin-only RLS, no anon policy).
-- =============================================================================

CREATE TABLE IF NOT EXISTS tbl_pzsz_match_review (
    id_review           SERIAL PRIMARY KEY,
    id_tournament       INT NOT NULL REFERENCES tbl_tournament(id_tournament) ON DELETE CASCADE,
    txt_scraped_name    TEXT NOT NULL,
    int_place           INT NOT NULL,
    -- The fuzzy matcher's top guess, if any -- nullable: a row can also be
    -- queued with no candidate at all named (an admin still names one on
    -- approval, or rejects).
    id_candidate_fencer INT REFERENCES tbl_fencer(id_fencer),
    num_confidence      NUMERIC(5, 2),
    enum_status         TEXT NOT NULL DEFAULT 'PENDING',
    ts_created          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ts_decided          TIMESTAMPTZ
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pzsz_match_review_status') THEN
    ALTER TABLE tbl_pzsz_match_review
      ADD CONSTRAINT chk_pzsz_match_review_status
      CHECK (enum_status IN ('PENDING', 'APPROVED', 'REJECTED'));
  END IF;
END $$;

COMMENT ON TABLE tbl_pzsz_match_review IS
  'One row per PZSz senior-bracket competitor whose identity match was too '
  'uncertain to auto-link and too plausible to silently drop (design §07 item '
  '4: "uncertain matches enter Admin review"). PENDING until an administrator '
  'approves (writes the held tbl_result row) or rejects (writes nothing). '
  'int_participant_count on the tournament is fixed at ingest time from the '
  'full source field and never changes here -- a pending or rejected row was '
  'always part of that count, matched or not.';

CREATE INDEX IF NOT EXISTS idx_pzsz_match_review_pending
  ON tbl_pzsz_match_review (id_tournament)
  WHERE enum_status = 'PENDING';

-- RLS: this names fencer candidates, an ADR-078-adjacent surface. No anon
-- policy — the pipeline writes it via the SECURITY DEFINER path only, and an
-- administrator is the only reader/decider.
ALTER TABLE tbl_pzsz_match_review ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin all pzsz match review" ON tbl_pzsz_match_review;
CREATE POLICY "Admin all pzsz match review" ON tbl_pzsz_match_review
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

GRANT SELECT, INSERT, UPDATE, DELETE ON tbl_pzsz_match_review TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE tbl_pzsz_match_review_id_review_seq TO authenticated;

-- -----------------------------------------------------------------------------
-- 1. The SENIOR-result guard.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_result_source_vcat_not_senior'
  ) THEN
    ALTER TABLE tbl_result
      ADD CONSTRAINT chk_result_source_vcat_not_senior
      CHECK (enum_source_age_category IS NULL OR enum_source_age_category <> 'SENIOR');
  END IF;
END $$;

COMMENT ON CONSTRAINT chk_result_source_vcat_not_senior ON tbl_result IS
  'SENIOR (design §07) is a tournament-level source-bracket label, never a '
  'published veteran category. A result row''s own enum_source_age_category '
  'may be a real V-cat or NULL, never SENIOR.';

-- -----------------------------------------------------------------------------
-- 2. Insert one PENDING review row (called by ResolveFencers's PZSZ_SENIOR
--    intake path, via db_connector, once CommitPzszSenior has created the
--    tournament and knows its id).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_queue_pzsz_match_review(
  p_id_tournament       INT,
  p_txt_scraped_name    TEXT,
  p_int_place           INT,
  p_id_candidate_fencer INT,
  p_num_confidence      NUMERIC
)
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO tbl_pzsz_match_review (
    id_tournament, txt_scraped_name, int_place, id_candidate_fencer, num_confidence
  )
  VALUES (
    p_id_tournament, p_txt_scraped_name, p_int_place, p_id_candidate_fencer, p_num_confidence
  )
  RETURNING id_review;
$$;

COMMENT ON FUNCTION fn_queue_pzsz_match_review IS
  'Ingestion-time writer, SECURITY DEFINER so the pipeline''s own low-privilege '
  'role can queue a review row without a standing INSERT grant. Not a public '
  'RPC -- called only from the PZSz ingestion flow.';

REVOKE ALL ON FUNCTION fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC) FROM anon;
GRANT EXECUTE ON FUNCTION fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. Administrator decisions. NOT SECURITY DEFINER and never granted to anon:
--    the same shape as fn_apply_identity_override/fn_reject_identity_override.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_approve_pzsz_match_review(p_id_review INT, p_id_fencer INT)
RETURNS INT
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_tournament  INT;
  v_name        TEXT;
  v_place       INT;
  v_confidence  NUMERIC;
  v_season_end  INT;
  v_birth_year  INT;
  v_source_vcat enum_age_category;
BEGIN
  SELECT id_tournament, txt_scraped_name, int_place, num_confidence
    INTO v_tournament, v_name, v_place, v_confidence
    FROM tbl_pzsz_match_review
   WHERE id_review = p_id_review AND enum_status = 'PENDING'
   FOR UPDATE;

  IF v_tournament IS NULL THEN
    RAISE EXCEPTION 'No pending PZSz match review %', p_id_review;
  END IF;

  IF p_id_fencer IS NULL THEN
    RAISE EXCEPTION 'A fencer must be named to approve review %', p_id_review;
  END IF;

  SELECT f.int_birth_year INTO v_birth_year FROM tbl_fencer f WHERE f.id_fencer = p_id_fencer;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fencer % does not exist', p_id_fencer;
  END IF;

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end
    FROM tbl_tournament t
    JOIN tbl_event e  ON e.id_event  = t.id_event
    JOIN tbl_season s ON s.id_season = e.id_season
   WHERE t.id_tournament = v_tournament;

  v_source_vcat := CASE
    WHEN v_birth_year IS NOT NULL THEN fn_age_category(v_birth_year, v_season_end)
    ELSE NULL
  END;

  INSERT INTO tbl_result (
    id_fencer, id_tournament, int_place,
    txt_scraped_name, num_match_confidence, enum_match_method,
    enum_source_age_category
  ) VALUES (
    p_id_fencer, v_tournament, v_place,
    v_name, v_confidence, 'USER_CONFIRMED',
    v_source_vcat
  );

  PERFORM fn_calc_tournament_scores(v_tournament);

  UPDATE tbl_pzsz_match_review
     SET enum_status = 'APPROVED', ts_decided = NOW()
   WHERE id_review = p_id_review;

  RETURN p_id_review;
END;
$$;

CREATE OR REPLACE FUNCTION fn_reject_pzsz_match_review(p_id_review INT)
RETURNS INT
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  UPDATE tbl_pzsz_match_review
     SET enum_status = 'REJECTED', ts_decided = NOW()
   WHERE id_review = p_id_review AND enum_status = 'PENDING';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No pending PZSz match review %', p_id_review;
  END IF;

  RETURN p_id_review;
END;
$$;

COMMENT ON FUNCTION fn_approve_pzsz_match_review IS
  'Administrator-only. Writes the ONE held result row directly (never a call '
  'to fn_ingest_tournament_results, which deletes and rewrites the whole '
  'tournament -- that would erase every already-committed row and, worse, '
  're-derive int_participant_count from the row count instead of leaving the '
  'full source field size untouched). p_id_fencer need not be the review''s '
  'own candidate -- an administrator may confirm a different existing fencer '
  'entirely. Rescoring afterward is a normal fn_calc_tournament_scores call, '
  'exactly as any other new result triggers.';

COMMENT ON FUNCTION fn_reject_pzsz_match_review IS
  'Administrator-only. Closes a PENDING review without touching tbl_result -- '
  'the competitor is treated as unmatched, same as if no candidate had ever '
  'been found.';

REVOKE ALL ON FUNCTION fn_approve_pzsz_match_review(INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_approve_pzsz_match_review(INT, INT) FROM anon;
REVOKE ALL ON FUNCTION fn_reject_pzsz_match_review(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_reject_pzsz_match_review(INT) FROM anon;
GRANT EXECUTE ON FUNCTION fn_approve_pzsz_match_review(INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_reject_pzsz_match_review(INT) TO authenticated;
