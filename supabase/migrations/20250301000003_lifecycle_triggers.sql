-- =============================================================================
-- M1 Migration: Season Lifecycle, Audit Triggers, Auto-config
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Auto-create scoring config when a new season is inserted
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auto_create_scoring_config()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO tbl_scoring_config (id_season)
    VALUES (NEW.id_season)
    ON CONFLICT (id_season) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_season_auto_config
    AFTER INSERT ON tbl_season
    FOR EACH ROW
    EXECUTE FUNCTION fn_auto_create_scoring_config();

-- ---------------------------------------------------------------------------
-- 2. Auto-populate tournament num_multiplier from scoring config
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auto_populate_multiplier()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_season_id INT;
    v_config RECORD;
BEGIN
    -- Get the season via the event
    SELECT e.id_season INTO v_season_id
    FROM tbl_event e
    WHERE e.id_event = NEW.id_event;

    -- Get the scoring config for this season
    SELECT * INTO v_config
    FROM tbl_scoring_config
    WHERE id_season = v_season_id;

    -- Resolve multiplier based on tournament type
    NEW.num_multiplier := CASE NEW.enum_type
        WHEN 'PPW' THEN v_config.num_ppw_multiplier
        WHEN 'MPW' THEN v_config.num_mpw_multiplier
        WHEN 'PEW' THEN v_config.num_pew_multiplier
        WHEN 'MEW' THEN v_config.num_mew_multiplier
        WHEN 'MSW' THEN v_config.num_msw_multiplier
    END;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tournament_auto_multiplier
    BEFORE INSERT ON tbl_tournament
    FOR EACH ROW
    EXECUTE FUNCTION fn_auto_populate_multiplier();

-- ---------------------------------------------------------------------------
-- 3. Event status transition validation
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_event_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_valid BOOLEAN := FALSE;
BEGIN
    -- Define valid transitions
    v_valid := CASE
        -- From PLANNED
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'SCHEDULED'   THEN TRUE
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From SCHEDULED
        WHEN OLD.enum_status = 'SCHEDULED'    AND NEW.enum_status = 'CHANGED'     THEN TRUE
        WHEN OLD.enum_status = 'SCHEDULED'    AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'SCHEDULED'    AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From CHANGED
        WHEN OLD.enum_status = 'CHANGED'      AND NEW.enum_status = 'SCHEDULED'   THEN TRUE
        WHEN OLD.enum_status = 'CHANGED'      AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'CHANGED'      AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From IN_PROGRESS
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'COMPLETED'   THEN TRUE
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        ELSE FALSE
    END;

    IF NOT v_valid THEN
        RAISE EXCEPTION 'Invalid event status transition: % → %',
            OLD.enum_status, NEW.enum_status;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_event_transition
    BEFORE UPDATE OF enum_status ON tbl_event
    FOR EACH ROW
    WHEN (OLD.enum_status IS DISTINCT FROM NEW.enum_status)
    EXECUTE FUNCTION fn_validate_event_transition();

-- ---------------------------------------------------------------------------
-- 4. Audit log trigger (captures UPDATE/DELETE on key tables)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_old_json JSONB;
    v_new_json JSONB;
    v_id_row INT;
    v_pk_col TEXT;
BEGIN
    -- Determine PK column name from TG_ARGV or convention
    v_pk_col := TG_ARGV[0];

    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_old_json := to_jsonb(OLD);
        v_id_row := (v_old_json->>v_pk_col)::INT;
    END IF;

    IF TG_OP IN ('UPDATE', 'INSERT') THEN
        v_new_json := to_jsonb(NEW);
        IF v_id_row IS NULL THEN
            v_id_row := (v_new_json->>v_pk_col)::INT;
        END IF;
    END IF;

    INSERT INTO tbl_audit_log (
        txt_table_name, id_row, txt_action,
        jsonb_old_values, jsonb_new_values, txt_admin_user
    ) VALUES (
        TG_TABLE_NAME,
        v_id_row,
        TG_OP,
        v_old_json,
        v_new_json,
        current_setting('request.jwt.claims', TRUE)::JSONB->>'sub'
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

-- Attach audit trigger to key tables
CREATE TRIGGER trg_audit_event
    AFTER UPDATE OR DELETE ON tbl_event
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log('id_event');

CREATE TRIGGER trg_audit_tournament
    AFTER UPDATE OR DELETE ON tbl_tournament
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log('id_tournament');

CREATE TRIGGER trg_audit_result
    AFTER UPDATE OR DELETE ON tbl_result
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log('id_result');

CREATE TRIGGER trg_audit_fencer
    AFTER UPDATE OR DELETE ON tbl_fencer
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log('id_fencer');

CREATE TRIGGER trg_audit_season
    AFTER UPDATE OR DELETE ON tbl_season
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log('id_season');
