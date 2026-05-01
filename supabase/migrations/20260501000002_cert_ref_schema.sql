-- =============================================================================
-- Phase 0 — cert_ref schema scaffold (ADR-050)
-- =============================================================================
-- Creates a parallel read-only schema `cert_ref` that mirrors the four
-- tables the rebuild needs to diff against: tbl_event, tbl_tournament,
-- tbl_result, tbl_fencer.
--
-- This migration ONLY scaffolds the tables — they start empty.
-- scripts/load-cert-ref.sh populates rows from the latest
-- `supabase/seed_prod_<date>.sql` snapshot at rebuild start, then never
-- modifies them again. Phase 6 drops the schema entirely.
--
-- The schema sits on the same Postgres DB so 3-way diffs in Phase 3
-- (Source / cert_ref / draft) can join in a single query.
--
-- Permissions: cert_ref is owned by postgres, anon/authenticated have
-- only SELECT, service_role can refresh via the loader script.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS cert_ref;
COMMENT ON SCHEMA cert_ref IS
  'Read-only mirror of CERT/PROD tables for 3-way rebuild diffs (ADR-050). '
  'Populated once at rebuild start by scripts/load-cert-ref.sh from the '
  'latest seed_prod_<date>.sql; never modified during the rebuild lifetime. '
  'Dropped in Phase 6 after LOCAL→CERT→PROD promotion.';

-- ---------------------------------------------------------------------------
-- Tables — bare column scaffolds. We intentionally do NOT mirror constraints,
-- indexes, or FKs from public.* — cert_ref is read-only reference data,
-- never enforced. The loader script does pure column-list COPY/INSERT.
--
-- Schema follows public.* as of 2026-05-01. If public.* gains a column
-- and the rebuild needs to diff against it, add the column here AND
-- update load-cert-ref.sh in the same commit.
-- ---------------------------------------------------------------------------

-- Column lists match public.* exactly (as of 2026-05-01). Enum columns are
-- stored as TEXT here so cert_ref doesn't depend on the enum types — keeps
-- it loose-coupled and Phase-6-droppable without enum cleanup churn.

-- tbl_fencer
CREATE TABLE IF NOT EXISTS cert_ref.tbl_fencer (
  id_fencer                 INT     PRIMARY KEY,
  txt_surname               TEXT,
  txt_first_name            TEXT,
  int_birth_year            SMALLINT,
  txt_club                  TEXT,
  txt_nationality           TEXT,
  json_name_aliases         JSONB,
  ts_created                TIMESTAMPTZ,
  ts_updated                TIMESTAMPTZ,
  bool_birth_year_estimated BOOLEAN,
  enum_gender               TEXT
);

-- tbl_event
CREATE TABLE IF NOT EXISTS cert_ref.tbl_event (
  id_event                   INT     PRIMARY KEY,
  txt_code                   TEXT,
  txt_name                   TEXT,
  id_season                  INT,
  id_organizer               INT,
  txt_location               TEXT,
  dt_start                   DATE,
  dt_end                     DATE,
  url_event                  TEXT,
  enum_status                TEXT,
  ts_created                 TIMESTAMPTZ,
  ts_updated                 TIMESTAMPTZ,
  txt_country                TEXT,
  txt_venue_address          TEXT,
  url_invitation             TEXT,
  num_entry_fee              NUMERIC,
  txt_entry_fee_currency     TEXT,
  arr_weapons                TEXT[],
  url_registration           TEXT,
  dt_registration_deadline   DATE,
  url_event_2                TEXT,
  url_event_3                TEXT,
  url_event_4                TEXT,
  url_event_5                TEXT,
  id_prior_event             INT,
  id_evf_event               INT,
  txt_source_status          TEXT
);

-- tbl_tournament
CREATE TABLE IF NOT EXISTS cert_ref.tbl_tournament (
  id_tournament            INT     PRIMARY KEY,
  id_event                 INT,
  txt_code                 TEXT,
  txt_name                 TEXT,
  enum_type                TEXT,
  num_multiplier           NUMERIC,
  dt_tournament            DATE,
  int_participant_count    INT,
  enum_weapon              TEXT,
  enum_gender              TEXT,
  enum_age_category        TEXT,
  url_results              TEXT,
  enum_import_status       TEXT,
  txt_import_status_reason TEXT,
  ts_created               TIMESTAMPTZ,
  ts_updated               TIMESTAMPTZ,
  id_evf_competition       INT,
  bool_joint_pool_split    BOOLEAN
);

-- tbl_result (with Phase 0 provenance columns)
CREATE TABLE IF NOT EXISTS cert_ref.tbl_result (
  id_result                 INT     PRIMARY KEY,
  id_fencer                 INT,
  id_tournament             INT,
  int_place                 INT,
  enum_fencer_age_category  TEXT,
  txt_cross_cat             TEXT,
  num_place_pts             NUMERIC,
  num_de_bonus              NUMERIC,
  num_podium_bonus          NUMERIC,
  num_final_score           NUMERIC,
  ts_points_calc            TIMESTAMPTZ,
  ts_created                TIMESTAMPTZ,
  ts_updated                TIMESTAMPTZ,
  txt_scraped_name          TEXT,
  num_match_confidence      NUMERIC(5,2),
  enum_match_method         TEXT
);

-- ---------------------------------------------------------------------------
-- Helpful indexes for the diff queries (Stage 9 of the unified pipeline)
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_cert_ref_event_code      ON cert_ref.tbl_event      (txt_code);
CREATE INDEX IF NOT EXISTS idx_cert_ref_event_dates     ON cert_ref.tbl_event      (dt_start, dt_end);
CREATE INDEX IF NOT EXISTS idx_cert_ref_tournament_code ON cert_ref.tbl_tournament (txt_code);
CREATE INDEX IF NOT EXISTS idx_cert_ref_tournament_evt  ON cert_ref.tbl_tournament (id_event);
CREATE INDEX IF NOT EXISTS idx_cert_ref_result_tourn    ON cert_ref.tbl_result     (id_tournament);
CREATE INDEX IF NOT EXISTS idx_cert_ref_result_fencer   ON cert_ref.tbl_result     (id_fencer);

-- ---------------------------------------------------------------------------
-- Permissions — read-only for everyone; service_role can refresh via loader
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA cert_ref TO anon, authenticated, service_role;

GRANT SELECT ON ALL TABLES IN SCHEMA cert_ref TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA cert_ref
  GRANT SELECT ON TABLES TO anon, authenticated, service_role;

-- service_role gets DDL/DML for the loader script
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA cert_ref TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA cert_ref
  GRANT INSERT, UPDATE, DELETE, TRUNCATE ON TABLES TO service_role;

COMMIT;
