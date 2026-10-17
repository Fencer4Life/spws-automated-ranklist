-- ============================================================================
-- Confirm the alias pairs the user decided in signed-off override files
-- (ADR-106 amendment of 2026-10-17, decision D9 A)
-- ============================================================================
-- At an FIE event (MSW, PSW, the IMSW code) international admission accepts a
-- user-confirmed, unrevoked alias as identity (json_user_confirmed_aliases),
-- never a merely recorded one. Every pair below is an identity entry of a
-- signed-off file in doc/overrides/ that links a scraped name to an existing
-- fencer: a person decided it, so it is recorded as confirmed here, and the
-- Phase 5 sign-off confirms such pairs itself from now on (ADM.FIE.11).
--
--   GERTSMAN Alexandr            -> GERTSMAN Alex 1976        PEW1efs-2025-2026
--   GINZERY Thomas               -> GINZERY Tomas 1984        PEW5fs-2024-2025
--   KAMINSKA Grabriela           -> KAMIŃSKA Gabriela 1979    PEW6efs-2024-2025
--   KARMAN Iren                  -> KARMAN Irene 1970         PEW2efs-2024-2025
--   KÁRMÁN Irén                  -> KARMAN Irene 1970         IMEW-2024-2025, PEW10efs-2025-2026
--   KORONA Przemslaw             -> KORONA Przemysław 1976    PEW62efs-2025-2026
--   KORONA Przemysåaw            -> KORONA Przemysław 1976    PEW2efs-2025-2026, PEW7ef-2025-2026
--   KORONA-TRZEBSKI Przemyslaw   -> KORONA Przemysław 1976    PEW13ef/2efs/4ef/6efs-2024-2025, PEW5ef-2025-2026
--   KORONA-TRZEBSKI Przemysåaw   -> KORONA Przemysław 1976    PEW2efs-2024-2025
--   KUZMICHOVA Svitalina         -> KUZMICHOVA Svitlana 1971  PEW4efs-2025-2026
--   LYNCH Patrick                -> LYNCH Pat 1930            IMEW-2024-2025 and six PEW files
--   MCQUEEN Andrew               -> MCQUEEN Andy 1976         PEW5ef/62efs/7ef/8es-2025-2026
-- UIJTING Henk (IMEW-2024-2025) is not listed: migration 20261017000001 makes
-- it the fencer's own name.
--
-- KEYED BY NAME AND BIRTH YEAR, never by id: fencer ids differ between LOCAL,
-- CERT and PROD. A pair already confirmed (case-insensitive), revoked, or
-- equal to the fencer's own name is skipped, so re-applying is a no-op.
-- Aggregated per fencer: an UPDATE ... FROM applies one joined row per target
-- row, so several aliases of one fencer must arrive as one array.
--
-- FRESH BOOTSTRAP: migrations run BEFORE the seed dump loads (ADR-036
-- amendment); on an empty tbl_fencer this touches nothing.
--
-- RANKING IMPACT: none. Alias columns move no result, and
-- trg_fencer_change_enqueue ignores them; trg_audit_fencer records the change.
-- ============================================================================

WITH pairs AS (
  SELECT * FROM (VALUES
    ('GERTSMAN Alexandr',          'GERTSMAN',   'Alex',       1976),
    ('GINZERY Thomas',             'GINZERY',    'Tomas',      1984),
    ('KAMINSKA Grabriela',         'KAMIŃSKA',   'Gabriela',   1979),
    ('KARMAN Iren',                'KARMAN',     'Irene',      1970),
    ('KÁRMÁN Irén',                'KARMAN',     'Irene',      1970),
    ('KORONA Przemslaw',           'KORONA',     'Przemysław', 1976),
    ('KORONA Przemysåaw',          'KORONA',     'Przemysław', 1976),
    ('KORONA-TRZEBSKI Przemyslaw', 'KORONA',     'Przemysław', 1976),
    ('KORONA-TRZEBSKI Przemysåaw', 'KORONA',     'Przemysław', 1976),
    ('KUZMICHOVA Svitalina',       'KUZMICHOVA', 'Svitlana',   1971),
    ('LYNCH Patrick',              'LYNCH',      'Pat',        1930),
    ('MCQUEEN Andrew',             'MCQUEEN',    'Andy',       1976)
  ) AS v (alias, surname, first_name, birth_year)
),
additions AS (
  SELECT f.id_fencer, jsonb_agg(p.alias ORDER BY p.alias) AS aliases
    FROM pairs p
    JOIN tbl_fencer f
      ON f.txt_surname = p.surname
     AND f.txt_first_name = p.first_name
     AND f.int_birth_year = p.birth_year
   WHERE lower(f.txt_surname || ' ' || f.txt_first_name) <> lower(p.alias)
     AND NOT EXISTS (
           SELECT 1
             FROM jsonb_array_elements_text(COALESCE(f.json_user_confirmed_aliases, '[]'::jsonb)) AS c (a)
            WHERE lower(c.a) = lower(p.alias))
     AND NOT EXISTS (
           SELECT 1
             FROM jsonb_array_elements_text(COALESCE(f.json_revoked_aliases, '[]'::jsonb)) AS r (a)
            WHERE lower(r.a) = lower(p.alias))
   GROUP BY f.id_fencer
)
UPDATE tbl_fencer f
   SET json_user_confirmed_aliases = COALESCE(f.json_user_confirmed_aliases, '[]'::jsonb) || a.aliases,
       ts_updated = NOW()
  FROM additions a
 WHERE f.id_fencer = a.id_fencer;

DO $$
DECLARE
  v_missing int;
BEGIN
  -- Every pair whose fencer exists and has not revoked it is now confirmed.
  SELECT count(*) INTO v_missing
    FROM (VALUES
            ('GERTSMAN Alexandr', 'GERTSMAN', 'Alex', 1976),
            ('LYNCH Patrick',     'LYNCH',    'Pat',  1930)) AS p (alias, surname, first_name, birth_year)
    JOIN tbl_fencer f
      ON f.txt_surname = p.surname AND f.txt_first_name = p.first_name
     AND f.int_birth_year = p.birth_year
   WHERE NOT EXISTS (
           SELECT 1
             FROM jsonb_array_elements_text(COALESCE(f.json_user_confirmed_aliases, '[]'::jsonb)) AS c (a)
            WHERE lower(c.a) = lower(p.alias))
     AND NOT EXISTS (
           SELECT 1
             FROM jsonb_array_elements_text(COALESCE(f.json_revoked_aliases, '[]'::jsonb)) AS r (a)
            WHERE lower(r.a) = lower(p.alias));
  IF v_missing > 0 THEN
    RAISE EXCEPTION 'override alias pairs not confirmed: %', v_missing;
  END IF;
  RAISE NOTICE 'override alias pairs confirmed';
END $$;
