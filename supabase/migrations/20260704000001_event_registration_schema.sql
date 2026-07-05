-- =============================================================================
-- FR-120–FR-124 — Event Self-Registration Phase 1: DB schema
-- (ADR-079 §5, ADR-080 §5; spec §5.2)
-- =============================================================================
-- New `tbl_registration` (ephemeral, public self-registration record) + 6 new
-- `tbl_event` columns + RLS (no direct anon writes, controlled RPC only) +
-- public entry-list view (all declared registrations, excludes birth year +
-- club) + exact-tuple match RPC (ADR-079 Path A only — see FR-124 for the
-- deferred B/C/D scope). No payment-status tracking (corrected 2026-07-04 —
-- see the tbl_registration comment below).
--
-- SCOPE NOTE: this migration does NOT extend fn_update_event with the 6 new
-- tbl_event columns. That write path is deferred to Phase 4, to be added in
-- the same change as the EventManager.svelte "Organizator" section that
-- actually calls it (matches how id_prior_event's picker + RPC + view were
-- shipped together in 20260627000001) — adding unused RPC parameters now
-- would be an untested, uncalled code path. vw_calendar IS updated below
-- (read visibility), per the standing "new tbl_event column → rebuild
-- vw_calendar" rule.
-- =============================================================================

-- 1. tbl_registration (ephemeral — see ADR-079 §5 for the "rows not a file"
--    rationale: public concurrent writes need ACID; ephemeral = purged after
--    results are ingested + reconciled, not short-lived).
--
-- NOTE (corrected 2026-07-04): no payment-status tracking. This system
-- displays bank-transfer instructions to the fencer so they can pay
-- correctly, but does NOT track whether the transfer lands — that is
-- verified in person by the organizer at the venue, before the competition
-- starts. An earlier draft of this schema had enum_payment_status/
-- txt_payment_ref columns and gated the entry list + seed export on
-- "PAID" — removed. The declared registration itself (not a payment flag)
-- is the source of truth for "who's entering."
CREATE TABLE tbl_registration (
    id_registration     SERIAL PRIMARY KEY,
    id_event            INT NOT NULL REFERENCES tbl_event(id_event) ON DELETE CASCADE,
    id_fencer            INT REFERENCES tbl_fencer(id_fencer),
    txt_surname          TEXT NOT NULL,
    txt_first_name       TEXT NOT NULL,
    enum_gender          enum_gender_type NOT NULL,
    int_birth_year       SMALLINT NOT NULL,
    arr_weapons          enum_weapon_type[] NOT NULL,
    txt_ftl_name         TEXT,
    ts_consent           TIMESTAMPTZ,
    txt_consent_version  TEXT,
    txt_email_hash       TEXT,
    ts_created           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (id_event, id_fencer)
);

COMMENT ON TABLE tbl_registration IS
  'Ephemeral public self-registration record (ADR-079). READ-ONLY invariant: '
  'never joined into tbl_fencer/tbl_result writes; a fencer only enters tbl_fencer '
  'when results are ingested. Purged after an event''s results are ingested + reconciled.';
COMMENT ON COLUMN tbl_registration.id_fencer IS
  'Matched fencer, NULL until/unless resolved (ADR-079 Model B paths A-D). '
  'UNIQUE(id_event, id_fencer) enables the anonymous-path upsert; Postgres treats '
  'NULL id_fencer values as distinct, so unmatched registrations never falsely collide.';
COMMENT ON COLUMN tbl_registration.txt_ftl_name IS
  'Canonical seed name + (N) category marker (ADR-080 §1), computed by the seed '
  'exporter (Phase 3) — not written at registration time.';
COMMENT ON COLUMN tbl_registration.txt_email_hash IS
  'Salted hash of the verification email, abuse-defense log only (ADR-078). '
  'The raw email is never persisted here — Model B treats it as one-time '
  'inbox-control proof, not a stored identity.';

-- 2. tbl_event additions (FR-121). url_registration + dt_registration_deadline
--    already exist (ADR-030). One combined ALTER TABLE (single table scan) +
--    lock_timeout (matches 20250301000002_rls_policies.sql convention).
SET LOCAL lock_timeout = '2s';
ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS url_entry_list TEXT,
  ADD COLUMN IF NOT EXISTS txt_organizer_email TEXT,
  ADD COLUMN IF NOT EXISTS ts_ftl_sent TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS num_entry_fee_2w NUMERIC,
  ADD COLUMN IF NOT EXISTS num_entry_fee_3w NUMERIC,
  ADD COLUMN IF NOT EXISTS bool_use_spws_registration BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN tbl_event.ts_ftl_sent IS
  'Stamped by send_seed_to_organizer() (Phase 4), not admin-editable via fn_update_event.';

-- 3. Rebuild vw_calendar so the 6 new columns are visible (read-side of the
--    standing "new tbl_event column → rebuild vw_calendar" discipline;
--    write-side (fn_update_event) is deferred to Phase 4 — see file header).
DROP VIEW IF EXISTS vw_calendar;
CREATE VIEW vw_calendar AS
SELECT
  e.id_event, e.txt_code, e.txt_name, e.id_season,
  s.txt_code AS txt_season_code,
  e.id_organizer, o.txt_name AS txt_organizer_name,
  e.txt_location, e.txt_country, e.txt_venue_address,
  e.url_invitation, e.num_entry_fee, e.txt_entry_fee_currency,
  e.arr_weapons,
  e.dt_start, e.dt_end, e.url_event, e.enum_status,
  e.url_registration, e.dt_registration_deadline,
  e.url_event_2, e.url_event_3, e.url_event_4, e.url_event_5,
  e.id_evf_event,
  e.id_prior_event,
  COUNT(t.id_tournament)::INT AS num_tournaments,
  COALESCE(BOOL_OR(t.enum_type IN ('PEW','MEW','MSW','PSW')), FALSE) AS bool_has_international,
  e.json_ingest_sources, e.json_source_overrides,
  e.url_entry_list, e.txt_organizer_email, e.ts_ftl_sent,
  e.num_entry_fee_2w, e.num_entry_fee_3w, e.bool_use_spws_registration
FROM tbl_event e
JOIN tbl_season s ON s.id_season = e.id_season
LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
GROUP BY e.id_event, s.txt_code, o.txt_name
ORDER BY e.dt_start ASC;

GRANT SELECT ON vw_calendar TO anon;
GRANT SELECT ON vw_calendar TO authenticated;

-- 4. RLS on tbl_registration (FR-122). No public write policy exists at all —
--    RLS enabled + zero anon-facing policy means anon INSERT/UPDATE/DELETE is
--    implicitly denied (same convention as every other table in this schema,
--    see 20250301000002_rls_policies.sql). The only public write path is the
--    SECURITY DEFINER RPC below. Admins (authenticated) get full CRUD, e.g.
--    for removing an impersonation/bogus entry spotted at the venue or via
--    "Sprawdź zgłoszenie" (ADR-079 §4).
ALTER TABLE tbl_registration ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin all registrations" ON tbl_registration
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 5. Public entry-list view (FR-123). Shows every DECLARED registration for
--    the event — this system displays bank-transfer instructions to the
--    fencer but does not track whether the transfer actually lands; that
--    check happens in person, at the venue, before the competition starts
--    (corrected 2026-07-04; supersedes an earlier "PAID only" gate that
--    wrongly assumed digital payment tracking). Explicitly excludes birth
--    year and club (GDPR minimisation, ADR-078).
--    Views run with the owner's row-security context in Postgres (the
--    migration role, which bypasses RLS), so anon can SELECT this projection
--    even though the base table has no anon SELECT policy — the same pattern
--    already used by every other vw_* in this schema.
CREATE VIEW vw_registration_entry_list AS
SELECT
  r.id_registration,
  r.id_event,
  r.txt_surname,
  r.txt_first_name,
  r.enum_gender,
  r.arr_weapons
FROM tbl_registration r;

GRANT SELECT ON vw_registration_entry_list TO anon;
GRANT SELECT ON vw_registration_entry_list TO authenticated;

-- 6. fn_create_registration — the sole public write path (FR-122).
--    SECURITY DEFINER: anon has no INSERT policy on tbl_registration, so this
--    function runs as its owner to perform the write, then returns just the
--    new id. Upserts on (id_event, id_fencer) for the anonymous fast-path
--    (ADR-079 §2); id_fencer NULL rows never collide (see column comment).
CREATE OR REPLACE FUNCTION fn_create_registration(
  p_event      INT,
  p_surname    TEXT,
  p_first_name TEXT,
  p_gender     enum_gender_type,
  p_birth_year SMALLINT,
  p_weapons    enum_weapon_type[],
  p_id_fencer  INT DEFAULT NULL,
  p_email_hash TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id INT;
BEGIN
  INSERT INTO tbl_registration (
    id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
    int_birth_year, arr_weapons, txt_email_hash
  ) VALUES (
    p_event, p_id_fencer, p_surname, p_first_name, p_gender,
    p_birth_year, p_weapons, p_email_hash
  )
  ON CONFLICT (id_event, id_fencer) DO UPDATE SET
    txt_surname    = EXCLUDED.txt_surname,
    txt_first_name = EXCLUDED.txt_first_name,
    enum_gender    = EXCLUDED.enum_gender,
    int_birth_year = EXCLUDED.int_birth_year,
    arr_weapons    = EXCLUDED.arr_weapons
  RETURNING id_registration INTO v_id;

  RETURN v_id;
END;
$$;

-- 7. fn_match_registration_fencer — the COMPLETE form-side identity router
--    (FR-124, ADR-079 §2). Read-only; no SECURITY DEFINER needed since
--    tbl_fencer already has a "Public read fencers" RLS policy (anon can
--    already SELECT it directly). Exact triple → Path A (skip email); ANY miss
--    → email-verify path. The form does NO fuzzy matching: ADR-079's Paths
--    B/C/D are an ingestion-time reconciliation model realised by the existing
--    Python find_best_match (never called from the browser), so no
--    Python-from-frontend bridge is needed — the "invocation gap" closes by
--    construction (resolved 2026-07-05; see ADR-079 §2 implementation note +
--    pgTAP 49.22).
CREATE OR REPLACE FUNCTION fn_match_registration_fencer(
  p_surname    TEXT,
  p_first_name TEXT,
  p_birth_year SMALLINT
)
RETURNS INT
LANGUAGE sql
STABLE
AS $$
  SELECT id_fencer FROM tbl_fencer
  WHERE upper(trim(txt_surname)) = upper(trim(p_surname))
    AND upper(trim(txt_first_name)) = upper(trim(p_first_name))
    AND int_birth_year = p_birth_year
  LIMIT 1;
$$;
