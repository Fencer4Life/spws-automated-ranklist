-- =============================================================================
-- M1 Migration: Enums, Tables, Indexes, Constraints
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Enum Types (§9.1.1)
-- ---------------------------------------------------------------------------
CREATE TYPE enum_weapon_type AS ENUM ('EPEE', 'FOIL', 'SABRE');
CREATE TYPE enum_gender_type AS ENUM ('M', 'F');
CREATE TYPE enum_tournament_type AS ENUM ('PPW', 'MPW', 'PEW', 'MEW', 'MSW');
CREATE TYPE enum_age_category AS ENUM ('V0', 'V1', 'V2', 'V3', 'V4');

CREATE TYPE enum_event_status AS ENUM (
    'PLANNED', 'SCHEDULED', 'CHANGED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
);
CREATE TYPE enum_import_status AS ENUM (
    'PLANNED', 'PENDING', 'IMPORTED', 'SCORED', 'REJECTED'
);
CREATE TYPE enum_match_status AS ENUM (
    'PENDING', 'AUTO_MATCHED', 'APPROVED', 'NEW_FENCER', 'DISMISSED', 'UNMATCHED'
);

-- ---------------------------------------------------------------------------
-- 2. Tables (§9.2, §9.3)
-- ---------------------------------------------------------------------------

CREATE TABLE tbl_season (
    id_season    SERIAL PRIMARY KEY,
    txt_code     TEXT NOT NULL,
    dt_start     DATE NOT NULL,
    dt_end       DATE NOT NULL,
    bool_active  BOOLEAN NOT NULL DEFAULT FALSE,
    ts_created   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tbl_scoring_config (
    id_config               SERIAL PRIMARY KEY,
    id_season               INT NOT NULL REFERENCES tbl_season(id_season),
    int_mp_value            INT NOT NULL DEFAULT 50,
    int_podium_gold         INT NOT NULL DEFAULT 3,
    int_podium_silver       INT NOT NULL DEFAULT 2,
    int_podium_bronze       INT NOT NULL DEFAULT 1,
    num_ppw_multiplier      NUMERIC NOT NULL DEFAULT 1.0,
    int_ppw_best_count      INT NOT NULL DEFAULT 4,
    int_ppw_total_rounds    INT NOT NULL DEFAULT 5,
    num_mpw_multiplier      NUMERIC NOT NULL DEFAULT 1.2,
    bool_mpw_droppable      BOOLEAN NOT NULL DEFAULT TRUE,
    num_pew_multiplier      NUMERIC NOT NULL DEFAULT 1.0,
    int_pew_best_count      INT NOT NULL DEFAULT 3,
    num_mew_multiplier      NUMERIC NOT NULL DEFAULT 2.0,
    bool_mew_droppable      BOOLEAN NOT NULL DEFAULT TRUE,
    num_msw_multiplier      NUMERIC NOT NULL DEFAULT 2.0,
    int_min_participants_evf INT NOT NULL DEFAULT 5,
    int_min_participants_ppw INT NOT NULL DEFAULT 1,
    json_extra              JSONB NOT NULL DEFAULT '{}'::JSONB,
    ts_created              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ts_updated              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tbl_fencer (
    id_fencer        SERIAL PRIMARY KEY,
    txt_surname      TEXT NOT NULL,
    txt_first_name   TEXT NOT NULL,
    int_birth_year   SMALLINT,
    txt_club         TEXT,
    txt_nationality  TEXT NOT NULL DEFAULT 'PL',
    json_name_aliases JSONB,
    ts_created       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ts_updated       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tbl_organizer (
    id_organizer  SERIAL PRIMARY KEY,
    txt_code      TEXT NOT NULL,
    txt_name      TEXT NOT NULL,
    ts_created    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tbl_event (
    id_event       SERIAL PRIMARY KEY,
    txt_code       TEXT NOT NULL,
    txt_name       TEXT NOT NULL,
    id_season      INT NOT NULL REFERENCES tbl_season(id_season),
    id_organizer   INT NOT NULL REFERENCES tbl_organizer(id_organizer),
    txt_location   TEXT,
    dt_start       DATE,
    dt_end         DATE,
    url_event      TEXT,
    enum_status    enum_event_status NOT NULL DEFAULT 'PLANNED',
    ts_created     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ts_updated     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tbl_tournament (
    id_tournament            SERIAL PRIMARY KEY,
    id_event                 INT NOT NULL REFERENCES tbl_event(id_event),
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
    ts_updated               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tbl_result (
    id_result               SERIAL PRIMARY KEY,
    id_fencer               INT NOT NULL REFERENCES tbl_fencer(id_fencer),
    id_tournament           INT NOT NULL REFERENCES tbl_tournament(id_tournament),
    int_place               INT NOT NULL,
    enum_fencer_age_category enum_age_category,
    txt_cross_cat           TEXT,
    num_place_pts           NUMERIC,
    num_de_bonus            NUMERIC,
    num_podium_bonus        NUMERIC,
    num_final_score         NUMERIC,
    ts_points_calc          TIMESTAMPTZ,
    ts_created              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ts_updated              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tbl_match_candidate (
    id_match         SERIAL PRIMARY KEY,
    id_result        INT NOT NULL REFERENCES tbl_result(id_result),
    txt_scraped_name TEXT NOT NULL,
    id_fencer        INT REFERENCES tbl_fencer(id_fencer),
    num_confidence   NUMERIC,
    enum_status      enum_match_status NOT NULL DEFAULT 'PENDING',
    txt_admin_note   TEXT,
    ts_created       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ts_updated       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tbl_audit_log (
    id_log           SERIAL PRIMARY KEY,
    txt_table_name   TEXT NOT NULL,
    id_row           INT NOT NULL,
    txt_action       TEXT NOT NULL,
    jsonb_old_values JSONB,
    jsonb_new_values JSONB,
    txt_admin_user   TEXT,
    ts_created       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 3. Unique Constraints (§9.2)
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_result ADD CONSTRAINT uq_result_fencer_tournament
    UNIQUE (id_fencer, id_tournament);

ALTER TABLE tbl_match_candidate ADD CONSTRAINT uq_match_result_name
    UNIQUE (id_result, txt_scraped_name);

-- ---------------------------------------------------------------------------
-- 4. Indexes (§9.2)
-- ---------------------------------------------------------------------------

-- txt_code unique indexes (global uniqueness)
CREATE UNIQUE INDEX idx_season_code     ON tbl_season (txt_code);
CREATE UNIQUE INDEX idx_event_code      ON tbl_event (txt_code);
CREATE UNIQUE INDEX idx_tournament_code ON tbl_tournament (txt_code);
CREATE UNIQUE INDEX idx_organizer_code  ON tbl_organizer (txt_code);

-- Partial unique index: only one active season at a time
CREATE UNIQUE INDEX idx_season_active
    ON tbl_season (bool_active)
    WHERE bool_active = TRUE;

-- Scoring config: one config per season
CREATE UNIQUE INDEX idx_scoring_config_season
    ON tbl_scoring_config (id_season);

-- FK lookup indexes
CREATE INDEX idx_result_fencer     ON tbl_result (id_fencer);
CREATE INDEX idx_result_tournament ON tbl_result (id_tournament);
CREATE INDEX idx_tournament_event  ON tbl_tournament (id_event);
CREATE INDEX idx_event_season      ON tbl_event (id_season);
CREATE INDEX idx_event_organizer   ON tbl_event (id_organizer);
CREATE INDEX idx_match_result      ON tbl_match_candidate (id_result);
CREATE INDEX idx_match_fencer      ON tbl_match_candidate (id_fencer);

-- Query-optimized indexes
CREATE INDEX idx_fencer_name   ON tbl_fencer (txt_surname, txt_first_name);
CREATE INDEX idx_match_status  ON tbl_match_candidate (enum_status);
CREATE INDEX idx_audit_table_row ON tbl_audit_log (txt_table_name, id_row);
CREATE INDEX idx_audit_created   ON tbl_audit_log (ts_created);
