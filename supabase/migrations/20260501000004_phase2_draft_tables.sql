-- =============================================================================
-- Phase 2 — Draft tables + dry-run loop (ADR-050, P2 of
-- /Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
--
-- Adds scratch state for ingest runs:
--   - tbl_tournament_draft (draft-local PK + all live cols + txt_run_id)
--   - tbl_result_draft     (draft-local PK + all live cols + txt_run_id)
--   - fn_commit_event_draft(UUID)  → moves draft → live, sets joint-pool flag,
--                                    appends ingest_history, writes audit,
--                                    deletes drafts. Returns JSONB counts.
--   - fn_discard_event_draft(UUID) → deletes drafts, writes audit. Returns
--                                    JSONB counts.
--   - fn_dry_run_event_draft(JSONB) → validates + counts from in-memory IR
--                                     payload. NEVER writes anywhere. Returns
--                                     JSONB counts.
--
-- Tests: supabase/tests/27_draft_tables.sql (26 assertions).
--
-- Locked decisions (conversation 2026-05-01):
--   D1  --dry-run = no DB writes; Python computes diff from in-memory IR.
--       fn_dry_run_event_draft is a stateless validator/counter.
--   D2  RPCs return JSONB with counts; never throw on missing run_id
--       (CLI inspects count and routes to Telegram on zero / nonzero exit).
--   D3  Tournament-level diff in Phase 2; per-fencer detail = Phase 3.
--   D4  Migration filename: 20260501000004_phase2_draft_tables.sql.
--   D5  All txn boundaries inside SQL; no psycopg2 at runtime.
--
-- Deviation from plan text (`LIKE tbl_tournament INCLUDING ALL`):
--   Explicit DDL instead. Reason: LIKE INCLUDING ALL inherits the SERIAL
--   sequence, so draft inserts would consume the same id_tournament sequence
--   that live INSERT uses — collision risk. Explicit DDL gives drafts their
--   own id_tournament_draft sequence and renames the linkage column on
--   tbl_result_draft to id_tournament_draft (clarifies semantic: the integer
--   references a draft PK, not a live PK).
--
-- Drafts are LOOSE (no FKs to live):
--   id_event / id_fencer / id_tournament_draft are typed INT but unconstrained.
--   This is deliberate — admin overrides may stage values that don't yet
--   resolve to live rows. The commit RPC enforces resolution at promotion
--   time by INSERTing into live (which has the FKs).
-- =============================================================================

BEGIN;


-- ---------------------------------------------------------------------------
-- 1. tbl_tournament_draft (22 cols = 21 live + txt_run_id, with PK renamed)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_tournament_draft (
    id_tournament_draft      SERIAL PRIMARY KEY,
    id_event                 INT NOT NULL,
    txt_code                 TEXT NOT NULL,
    txt_name                 TEXT,
    enum_type                enum_tournament_type NOT NULL,
    num_multiplier           NUMERIC,
    dt_tournament            DATE,
    int_participant_count    INT,
    enum_weapon              enum_weapon_type NOT NULL,
    enum_gender              enum_gender_type NOT NULL,
    enum_age_category        enum_age_category NOT NULL,
    url_results              TEXT,
    enum_import_status       enum_import_status NOT NULL DEFAULT 'PLANNED',
    txt_import_status_reason TEXT,
    ts_created               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ts_updated               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_evf_competition       INT,
    bool_joint_pool_split    BOOLEAN NOT NULL DEFAULT FALSE,
    enum_parser_kind         enum_parser_kind,
    dt_last_scraped          TIMESTAMPTZ,
    txt_source_url_used      TEXT,
    txt_run_id               UUID NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tbl_tournament_draft_run_id
  ON tbl_tournament_draft (txt_run_id);

COMMENT ON TABLE tbl_tournament_draft IS
  'Phase 2 (ADR-050) scratch state for tournament drafts. Loose: no FKs. '
  'Materialized via direct INSERT, committed via fn_commit_event_draft, '
  'discarded via fn_discard_event_draft. Resumable across sessions by '
  'txt_run_id (UUID matching Phase 1 history tables).';

COMMENT ON COLUMN tbl_tournament_draft.txt_run_id IS
  'UUID identifier for this draft run. Same value flows through to '
  'tbl_tournament_ingest_history.txt_run_id at commit time.';


-- ---------------------------------------------------------------------------
-- 2. tbl_result_draft (17 cols = 16 live + txt_run_id, with PK renamed and
--    id_tournament linkage renamed to id_tournament_draft)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_result_draft (
    id_result_draft          SERIAL PRIMARY KEY,
    id_fencer                INT,
    id_tournament_draft      INT NOT NULL,
    int_place                INT NOT NULL,
    enum_fencer_age_category enum_age_category,
    txt_cross_cat            TEXT,
    num_place_pts            NUMERIC,
    num_de_bonus             NUMERIC,
    num_podium_bonus         NUMERIC,
    num_final_score          NUMERIC,
    ts_points_calc           TIMESTAMPTZ,
    ts_created               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ts_updated               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    txt_scraped_name         TEXT,
    num_match_confidence     NUMERIC,
    enum_match_method        enum_match_method,
    txt_run_id               UUID NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tbl_result_draft_run_id
  ON tbl_result_draft (txt_run_id);

COMMENT ON TABLE tbl_result_draft IS
  'Phase 2 (ADR-050) scratch state for result drafts. Loose: no FKs. '
  'id_tournament_draft links to tbl_tournament_draft.id_tournament_draft '
  '(draft-local), not to tbl_tournament.id_tournament.';


-- ---------------------------------------------------------------------------
-- 3. fn_commit_event_draft(p_run_id UUID) RETURNS JSONB
--
-- Atomic move from drafts to live tables for one run_id:
--   a. INSERT draft tournaments → tbl_tournament (via CTE, capturing txt_code
--      → live id_tournament mapping for use in step b).
--   b. INSERT draft results → tbl_result, mapping draft id_tournament_draft
--      → live id_tournament via the txt_code joined CTE.
--   c. Detect joint-pool siblings (≥2 newly-committed tournaments sharing
--      url_results under same id_event/weapon/gender) and set
--      bool_joint_pool_split=TRUE + rewrite int_participant_count = full
--      physical pool size. Logic mirrors fn_backfill_joint_pool_split,
--      scoped to newly-committed rows.
--   d. Append per-event and per-tournament ingest_history rows
--      (Phase 1 ADR-055).
--   e. Write tbl_audit_log rows with txt_action='DRAFT_COMMIT'.
--   f. Delete drafts for this run_id.
--   g. Return JSONB counts. NEVER throws on unknown run_id (returns 0s).
--
-- Failure semantics: PL/pgSQL function is one transaction. If any step
-- raises (e.g. NOT NULL violation, unique constraint), the whole function
-- rolls back — no orphan tournaments, no partial drafts deleted.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_commit_event_draft(p_run_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_committed_tournaments INT := 0;
    v_committed_results     INT := 0;
    v_joint_flagged         INT := 0;
    v_history_rows          INT := 0;
    v_event_id              INT;
BEGIN
    -- Short-circuit: nothing to commit
    IF NOT EXISTS (SELECT 1 FROM tbl_tournament_draft WHERE txt_run_id = p_run_id) THEN
        RETURN jsonb_build_object(
            'run_id', p_run_id,
            'tournaments_committed', 0,
            'results_committed', 0,
            'joint_pool_siblings_flagged', 0,
            'history_rows', 0
        );
    END IF;

    -- Step a + b: insert tournaments, capture txt_code → id_tournament
    -- mapping, then insert results using that mapping. We use a temp table
    -- (per-transaction) for the mapping so step c can find the new ids.
    CREATE TEMP TABLE _commit_map (
        id_tournament_draft INT NOT NULL,
        id_tournament       INT NOT NULL
    ) ON COMMIT DROP;

    WITH inserted AS (
        INSERT INTO tbl_tournament (
            id_event, txt_code, txt_name, enum_type, num_multiplier,
            dt_tournament, int_participant_count, enum_weapon, enum_gender,
            enum_age_category, url_results, enum_import_status,
            txt_import_status_reason, id_evf_competition, bool_joint_pool_split,
            enum_parser_kind, dt_last_scraped, txt_source_url_used
        )
        SELECT id_event, txt_code, txt_name, enum_type, num_multiplier,
               dt_tournament, int_participant_count, enum_weapon, enum_gender,
               enum_age_category, url_results, enum_import_status,
               txt_import_status_reason, id_evf_competition, bool_joint_pool_split,
               enum_parser_kind, dt_last_scraped, txt_source_url_used
          FROM tbl_tournament_draft
         WHERE txt_run_id = p_run_id
        RETURNING id_tournament, txt_code
    )
    INSERT INTO _commit_map (id_tournament_draft, id_tournament)
    SELECT td.id_tournament_draft, i.id_tournament
      FROM inserted i
      JOIN tbl_tournament_draft td ON td.txt_code = i.txt_code
                                  AND td.txt_run_id = p_run_id;

    GET DIAGNOSTICS v_committed_tournaments = ROW_COUNT;

    -- Insert results using the draft → live mapping
    INSERT INTO tbl_result (
        id_fencer, id_tournament, int_place, enum_fencer_age_category,
        txt_cross_cat, num_place_pts, num_de_bonus, num_podium_bonus,
        num_final_score, ts_points_calc,
        txt_scraped_name, num_match_confidence, enum_match_method
    )
    SELECT rd.id_fencer, m.id_tournament, rd.int_place, rd.enum_fencer_age_category,
           rd.txt_cross_cat, rd.num_place_pts, rd.num_de_bonus, rd.num_podium_bonus,
           rd.num_final_score, rd.ts_points_calc,
           rd.txt_scraped_name, rd.num_match_confidence, rd.enum_match_method
      FROM tbl_result_draft rd
      JOIN _commit_map m ON m.id_tournament_draft = rd.id_tournament_draft
     WHERE rd.txt_run_id = p_run_id;

    GET DIAGNOSTICS v_committed_results = ROW_COUNT;

    -- Step c: joint-pool detection on the newly-committed tournaments
    -- (mirrors fn_backfill_joint_pool_split logic but scoped to this commit).
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

    -- Recompute int_participant_count for joint-pool siblings (full physical
    -- pool size, summed across all sibling tbl_result rows).
    UPDATE tbl_tournament t
       SET int_participant_count = ps.sz
      FROM (
        SELECT tt.id_event, tt.enum_weapon, tt.enum_gender, tt.url_results,
               COUNT(r.id_result)::INT AS sz
          FROM tbl_tournament tt
          JOIN _commit_map m ON m.id_tournament = tt.id_tournament
          JOIN tbl_result r ON r.id_tournament = tt.id_tournament
         WHERE tt.bool_joint_pool_split = TRUE
         GROUP BY tt.id_event, tt.enum_weapon, tt.enum_gender, tt.url_results
      ) ps
     WHERE t.id_event    = ps.id_event
       AND t.enum_weapon = ps.enum_weapon
       AND t.enum_gender = ps.enum_gender
       AND t.url_results = ps.url_results
       AND t.bool_joint_pool_split = TRUE;

    -- Step d: append per-tournament history rows (Phase 1 ADR-055)
    INSERT INTO tbl_tournament_ingest_history (
        id_tournament, txt_run_id, enum_parser_kind, txt_source_url
    )
    SELECT m.id_tournament, p_run_id, td.enum_parser_kind, td.txt_source_url_used
      FROM tbl_tournament_draft td
      JOIN _commit_map m ON m.id_tournament_draft = td.id_tournament_draft
     WHERE td.txt_run_id = p_run_id
       AND td.enum_parser_kind IS NOT NULL;

    GET DIAGNOSTICS v_history_rows = ROW_COUNT;

    -- Append per-event history rows (one per distinct id_event, deduplicated).
    -- Use the parser kind from the first (lowest id_tournament_draft) draft.
    INSERT INTO tbl_event_ingest_history (
        id_event, txt_run_id, enum_parser_kind, txt_source_url
    )
    SELECT DISTINCT ON (td.id_event)
           td.id_event, p_run_id, td.enum_parser_kind, td.txt_source_url_used
      FROM tbl_tournament_draft td
     WHERE td.txt_run_id = p_run_id
       AND td.enum_parser_kind IS NOT NULL
     ORDER BY td.id_event, td.id_tournament_draft;

    -- Step e: audit log rows (one for tbl_tournament, one for tbl_result)
    INSERT INTO tbl_audit_log (
        txt_table_name, id_row, txt_action,
        jsonb_old_values, jsonb_new_values, txt_admin_user
    )
    SELECT 'tbl_tournament', m.id_tournament, 'DRAFT_COMMIT',
           NULL::JSONB,
           jsonb_build_object('run_id', p_run_id, 'committed_at', NOW()),
           current_setting('request.jwt.claims', TRUE)::JSONB->>'sub'
      FROM _commit_map m;

    -- Step f: delete drafts for this run_id (results first; FK-free but order
    -- is convention)
    DELETE FROM tbl_result_draft     WHERE txt_run_id = p_run_id;
    DELETE FROM tbl_tournament_draft WHERE txt_run_id = p_run_id;

    -- Drop the temp mapping (also dropped at commit by ON COMMIT DROP)
    DROP TABLE _commit_map;

    -- Step g: return counts
    RETURN jsonb_build_object(
        'run_id', p_run_id,
        'tournaments_committed', v_committed_tournaments,
        'results_committed', v_committed_results,
        'joint_pool_siblings_flagged', v_joint_flagged,
        'history_rows', v_history_rows
    );
END;
$$;

COMMENT ON FUNCTION fn_commit_event_draft(UUID) IS
  'Phase 2 (ADR-050) commit path: moves drafts under p_run_id to live tables, '
  'sets joint-pool flag on sibling rows sharing url_results, appends '
  'ingest_history (Phase 1 ADR-055), writes audit, deletes drafts. '
  'Returns JSONB counts. Never throws on unknown run_id (returns zero counts).';


-- ---------------------------------------------------------------------------
-- 4. fn_discard_event_draft(p_run_id UUID) RETURNS JSONB
--
-- Deletes draft rows for the given run_id. Writes one DRAFT_DISCARD audit
-- row. Returns JSONB counts. Never throws on unknown run_id.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_discard_event_draft(p_run_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_tournaments INT := 0;
    v_results     INT := 0;
BEGIN
    DELETE FROM tbl_result_draft WHERE txt_run_id = p_run_id;
    GET DIAGNOSTICS v_results = ROW_COUNT;

    DELETE FROM tbl_tournament_draft WHERE txt_run_id = p_run_id;
    GET DIAGNOSTICS v_tournaments = ROW_COUNT;

    -- Always write an audit row, even if zero counts (operator typo trail).
    -- The CLI inspects counts and decides whether to warn via Telegram.
    INSERT INTO tbl_audit_log (
        txt_table_name, id_row, txt_action,
        jsonb_old_values, jsonb_new_values, txt_admin_user
    ) VALUES (
        'tbl_tournament_draft', 0, 'DRAFT_DISCARD',
        jsonb_build_object('run_id', p_run_id,
                           'tournaments_discarded', v_tournaments,
                           'results_discarded', v_results),
        NULL::JSONB,
        current_setting('request.jwt.claims', TRUE)::JSONB->>'sub'
    );

    RETURN jsonb_build_object(
        'run_id', p_run_id,
        'tournaments_discarded', v_tournaments,
        'results_discarded', v_results
    );
END;
$$;

COMMENT ON FUNCTION fn_discard_event_draft(UUID) IS
  'Phase 2 (ADR-050) discard path: deletes draft rows under p_run_id, '
  'writes DRAFT_DISCARD audit row, returns JSONB counts. Never throws on '
  'unknown run_id (returns zero counts; CLI warns via Telegram).';


-- ---------------------------------------------------------------------------
-- 5. fn_dry_run_event_draft(p_drafts JSONB) RETURNS JSONB
--
-- Stateless validator/counter. Takes a JSONB payload of the shape
-- {tournaments: [...], results: [...]} (built by Python from the parsed IR
-- + match decisions in memory) and returns counts + basic shape validation.
--
-- NEVER writes anywhere. Decision-1's "rollback dry-run" is implemented as
-- "no DB writes at all" — the simpler form satisfies the same risk gate
-- (no live tables touched) without needing an explicit txn boundary. Phase 3
-- can extend this RPC to enrich the diff with cross-references against live
-- tables if needed.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_dry_run_event_draft(p_drafts JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_tournaments INT;
    v_results     INT;
    v_joint_groups INT;
BEGIN
    v_tournaments := COALESCE(jsonb_array_length(p_drafts->'tournaments'), 0);
    v_results     := COALESCE(jsonb_array_length(p_drafts->'results'), 0);

    -- Joint-pool sibling group detection: count distinct (weapon, gender,
    -- url_results) groups with ≥2 tournaments.
    SELECT COUNT(*)::INT INTO v_joint_groups
      FROM (
        SELECT t->>'enum_weapon' AS w,
               t->>'enum_gender' AS g,
               t->>'url_results' AS u
          FROM jsonb_array_elements(COALESCE(p_drafts->'tournaments', '[]'::JSONB)) AS t
         WHERE t->>'url_results' IS NOT NULL
           AND t->>'url_results' <> ''
         GROUP BY 1, 2, 3
        HAVING COUNT(*) > 1
      ) g;

    RETURN jsonb_build_object(
        'tournaments_would_create', v_tournaments,
        'results_would_create', v_results,
        'joint_pool_sibling_groups', v_joint_groups
    );
END;
$$;

COMMENT ON FUNCTION fn_dry_run_event_draft(JSONB) IS
  'Phase 2 (ADR-050) dry-run validator/counter. Pure function — never '
  'writes. Returns counts + joint-pool sibling group detection from the '
  'in-memory IR payload. CLI formats the result + Python-side IR data '
  'into the markdown diff.';


COMMIT;
