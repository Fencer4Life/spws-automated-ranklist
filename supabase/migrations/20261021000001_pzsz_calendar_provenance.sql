-- =============================================================================
-- PZSz calendar provenance and the one atomic write (ADR-116 §9, §14)
-- =============================================================================
-- The PZSz calendar run fills five fields of each future PZSz event from the
-- organizer's letter, the pzszerm.pl listing and the home page. Two promises
-- need state the event row cannot hold on its own:
--
--   * a field a PERSON corrected on CERT is never overwritten by the run
--     (rule 3): the run must know the value IT last wrote, apart from the value
--     now in tbl_event;
--   * a lower-rank source that MOVES after a higher-rank one was applied (the
--     listing shifts an event's dates after the letter set them) is held and
--     sent to the operator (rule 6): the run must know each source's last
--     reported value.
--
-- Three small tables carry that, and one function makes the whole write for an
-- event a single transaction whose every UPDATE names the value it expects to
-- replace — so an admin edit landing between the run's read and its write wins
-- and is reported, never clobbered (compare-and-set). service_role only
-- (ADR-083); none of the tables is exported to the PROD seed (ADR-078).
--
-- Plan: doc/plans/pzsz-calendar-robust-rewrite-2026-10-21.html (§9, §14).
-- Tests: supabase/tests/110_pzsz_calendar_provenance.sql (110.1-110.9).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- Per event and field: the value the run last wrote, where it came from, the
-- evidence line, the letter it read and the parser version. Rules 3-4 compare
-- the value now in tbl_event with this to tell a hand correction from the
-- run's own value.
CREATE TABLE IF NOT EXISTS tbl_pzsz_field_state (
  id_event            INT NOT NULL REFERENCES tbl_event (id_event) ON DELETE CASCADE,
  txt_field           TEXT NOT NULL CONSTRAINT ck_pzsz_field_state_field
                        CHECK (txt_field IN ('dt_start', 'dt_end', 'txt_location',
                               'txt_venue_address', 'num_entry_fee',
                               'txt_entry_fee_currency', 'url_invitation')),
  txt_value           TEXT NOT NULL,
  txt_source          TEXT NOT NULL CONSTRAINT ck_pzsz_field_state_source
                        CHECK (txt_source IN ('letter', 'listing', 'home')),
  txt_evidence        TEXT,
  txt_letter_sha256   TEXT CONSTRAINT ck_pzsz_field_state_sha256
                        CHECK (txt_letter_sha256 IS NULL OR txt_letter_sha256 ~ '^[0-9a-f]{64}$'),
  txt_parser_version  TEXT,
  ts_written          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id_event, txt_field)
);

COMMENT ON TABLE tbl_pzsz_field_state IS
  'ADR-116 §14: per PZSz event and field, the value the run last wrote and its provenance. Rule 3-4: a value in tbl_event that differs from this was changed by hand and is never overwritten. Filled on CERT only; service_role only; not in the PROD seed (ADR-078).';

-- Per event, field and source: that source's last reported value. Rule 6: a
-- lower-rank source whose report moves against a higher-rank one already
-- applied is held for the operator.
CREATE TABLE IF NOT EXISTS tbl_pzsz_source_report (
  id_event      INT NOT NULL REFERENCES tbl_event (id_event) ON DELETE CASCADE,
  txt_field     TEXT NOT NULL,
  txt_source    TEXT NOT NULL CONSTRAINT ck_pzsz_source_report_source
                  CHECK (txt_source IN ('letter', 'listing', 'home')),
  txt_value     TEXT NOT NULL,
  ts_reported   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id_event, txt_field, txt_source)
);

COMMENT ON TABLE tbl_pzsz_source_report IS
  'ADR-116 §14: per PZSz event, field and source, that source''s last reported value. Rule 6: a moved lower-rank source is held and reported. Filled on CERT only; service_role only; not in the PROD seed (ADR-078).';

-- Per event (its code) or the site, per named check: the current state, since
-- when, when last seen and when the operator was last told. Drives
-- digest-on-change, the daily "still not served" warning, and the recorded
-- source-not-served state.
CREATE TABLE IF NOT EXISTS tbl_pzsz_check (
  txt_scope         TEXT NOT NULL,
  txt_check         TEXT NOT NULL,
  txt_state         TEXT NOT NULL,
  txt_detail        TEXT,
  ts_since          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ts_last_seen      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ts_last_notified  TIMESTAMPTZ,
  PRIMARY KEY (txt_scope, txt_check)
);

COMMENT ON TABLE tbl_pzsz_check IS
  'ADR-116 §14: per event or site, a named check''s state, since, last seen and last notified. Drives digest-on-change and reminders. Filled on CERT only; service_role only; not in the PROD seed (ADR-078).';

ALTER TABLE tbl_pzsz_field_state  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_pzsz_source_report ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_pzsz_check         ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_pzsz_field_state   FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON tbl_pzsz_source_report FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON tbl_pzsz_check         FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON tbl_pzsz_field_state   TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON tbl_pzsz_source_report TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON tbl_pzsz_check         TO service_role;

-- The whole write for one event, one transaction (ADR-116 §9). Each change is
-- a compare-and-set: the UPDATE names the value it expects to replace, so an
-- admin edit made between the run's read and this write does not match and is
-- reported "changed by hand meanwhile" rather than clobbered. The field name
-- is whitelisted to a fixed column and type, so the dynamic UPDATE carries no
-- injection. Provenance (field_state) is recorded only for a field actually
-- written; every source's report and every check are recorded regardless.
CREATE OR REPLACE FUNCTION fn_pzsz_apply_event(p_id_event INT, p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_change          JSONB;
  v_report          JSONB;
  v_check           JSONB;
  v_field           TEXT;
  v_type            TEXT;
  v_rows            INT;
  v_prev_state      TEXT;
  v_applied         TEXT[] := '{}';
  v_hand_changed    TEXT[] := '{}';
  v_rejected        TEXT[] := '{}';
  v_checks_changed  TEXT[] := '{}';
BEGIN
  FOR v_change IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload -> 'changes', '[]'::jsonb))
  LOOP
    v_field := v_change ->> 'field';
    v_type := CASE v_field
      WHEN 'dt_start' THEN 'date'
      WHEN 'dt_end' THEN 'date'
      WHEN 'num_entry_fee' THEN 'numeric'
      WHEN 'txt_location' THEN 'text'
      WHEN 'txt_venue_address' THEN 'text'
      WHEN 'txt_entry_fee_currency' THEN 'text'
      WHEN 'url_invitation' THEN 'text'
      ELSE NULL
    END;
    IF v_type IS NULL THEN
      v_rejected := v_rejected || v_field;
      CONTINUE;
    END IF;
    EXECUTE format(
      'UPDATE tbl_event SET %I = $1::%s WHERE id_event = $2 AND %I IS NOT DISTINCT FROM $3::%s',
      v_field, v_type, v_field, v_type
    ) USING (v_change ->> 'value'), p_id_event, (v_change ->> 'expected');
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 1 THEN
      v_applied := v_applied || v_field;
      INSERT INTO tbl_pzsz_field_state AS fs (
        id_event, txt_field, txt_value, txt_source, txt_evidence,
        txt_letter_sha256, txt_parser_version, ts_written
      ) VALUES (
        p_id_event, v_field, v_change ->> 'value', v_change ->> 'source',
        v_change ->> 'evidence', v_change ->> 'letter_sha256',
        v_change ->> 'parser_version', NOW()
      )
      ON CONFLICT (id_event, txt_field) DO UPDATE SET
        txt_value = EXCLUDED.txt_value,
        txt_source = EXCLUDED.txt_source,
        txt_evidence = EXCLUDED.txt_evidence,
        txt_letter_sha256 = EXCLUDED.txt_letter_sha256,
        txt_parser_version = EXCLUDED.txt_parser_version,
        ts_written = EXCLUDED.ts_written;
    ELSE
      v_hand_changed := v_hand_changed || v_field;
    END IF;
  END LOOP;

  FOR v_report IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload -> 'reports', '[]'::jsonb))
  LOOP
    INSERT INTO tbl_pzsz_source_report AS sr (id_event, txt_field, txt_source, txt_value, ts_reported)
    VALUES (p_id_event, v_report ->> 'field', v_report ->> 'source', v_report ->> 'value', NOW())
    ON CONFLICT (id_event, txt_field, txt_source) DO UPDATE SET
      txt_value = EXCLUDED.txt_value,
      ts_reported = EXCLUDED.ts_reported;
  END LOOP;

  FOR v_check IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload -> 'checks', '[]'::jsonb))
  LOOP
    SELECT c.txt_state INTO v_prev_state
      FROM tbl_pzsz_check c
     WHERE c.txt_scope = v_check ->> 'scope' AND c.txt_check = v_check ->> 'check';
    INSERT INTO tbl_pzsz_check AS c (txt_scope, txt_check, txt_state, txt_detail, ts_since, ts_last_seen)
    VALUES (v_check ->> 'scope', v_check ->> 'check', v_check ->> 'state', v_check ->> 'detail', NOW(), NOW())
    ON CONFLICT (txt_scope, txt_check) DO UPDATE SET
      txt_detail = EXCLUDED.txt_detail,
      ts_last_seen = NOW(),
      ts_since = CASE WHEN c.txt_state IS DISTINCT FROM EXCLUDED.txt_state THEN NOW() ELSE c.ts_since END,
      txt_state = EXCLUDED.txt_state;
    IF v_prev_state IS DISTINCT FROM (v_check ->> 'state') THEN
      v_checks_changed := v_checks_changed || (v_check ->> 'check');
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'applied', to_jsonb(v_applied),
    'hand_changed', to_jsonb(v_hand_changed),
    'rejected', to_jsonb(v_rejected),
    'checks_changed', to_jsonb(v_checks_changed)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_pzsz_apply_event(INT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_pzsz_apply_event(INT, JSONB) TO service_role;

-- Backfill (ADR-116 §14). The run already owns the dates, city and letter link
-- of the existing future PZSz events; record them as written-by-the-run so
-- rule 3 does not mistake them for hand edits. Venue address and fee are
-- admin-entered enrichment and keep NO provenance — they are treated as hand
-- values until the letter reader writes one. Guarded by the SELECT: on a fresh
-- bootstrap (no events yet) it inserts nothing (ADR-036 amendment).
INSERT INTO tbl_pzsz_field_state (id_event, txt_field, txt_value, txt_source, ts_written)
SELECT e.id_event, f.field, f.val, 'listing', NOW()
  FROM tbl_event e
  CROSS JOIN LATERAL (VALUES
    ('dt_start', e.dt_start::TEXT),
    ('dt_end', e.dt_end::TEXT),
    ('txt_location', e.txt_location),
    ('url_invitation', e.url_invitation)
  ) AS f(field, val)
 WHERE e.id_pzsz_event IS NOT NULL
   AND e.enum_status NOT IN ('COMPLETED', 'CANCELLED')
   AND f.val IS NOT NULL
ON CONFLICT (id_event, txt_field) DO NOTHING;

COMMIT;
