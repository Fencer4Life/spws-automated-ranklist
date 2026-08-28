-- =============================================================================
-- pgTAP — tbl_registration.txt_surname / txt_first_name auto-trim trigger
-- =============================================================================
-- Verifies migration 20260828000001_registration_trim_trigger.sql.
--
-- Why this exists: RegistrationForm.svelte validated with `surname.trim()`
-- but submitted the raw string, so a fencer who typed a trailing space had it
-- persisted verbatim. Two of the first fourteen live PROD registrations
-- carried one ("Gary ", "KUCIĘBA "). tbl_fencer has had trg_trim_fencer_names
-- since 20260503000004; tbl_registration had no equivalent, and its admin
-- "FOR ALL" RLS policy means PostgREST writes never pass the form at all.
--
-- The trigger is BEFORE INSERT OR UPDATE, so it fires ahead of ON CONFLICT
-- arbitration: fn_create_registration's unmatched branch arbitrates on
-- upper(btrim(...)) already, and trimming first cannot change which row it
-- picks. 57.7 pins that the two agree.
-- =============================================================================

BEGIN;

SELECT plan(7);

-- 57.1 — trigger function exists
SELECT has_function(
  'fn_trim_registration_names',
  '57.1 — fn_trim_registration_names() exists'
);

-- 57.2 — trigger is wired BEFORE INSERT OR UPDATE on tbl_registration
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgname = 'trg_trim_registration_names'
       AND tgrelid = 'tbl_registration'::regclass
  ),
  '57.2 — trg_trim_registration_names trigger present on tbl_registration'
);

-- ----- fixtures (mirrors 49_registration_schema.sql) -----
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_e      INT;
BEGIN
  v_season := fn_create_season('REG57', '2098-09-01', '2099-06-30');
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('REGORG57', 'Reg org 57') RETURNING id_organizer INTO v_org;
  v_e := fn_create_event('REG57EVT', 'Reg 57', v_season, v_org);
END $setup$;

-- 57.3 — direct INSERT with a trailing-space surname is stored trimmed.
-- This is the admin/PostgREST path, which never touches the form.
INSERT INTO tbl_registration (
  id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons
)
SELECT id_event, 'PGTAP57_TRAIL  ', 'Anna', 'F', 1975, ARRAY['EPEE']::enum_weapon_type[]
FROM tbl_event WHERE txt_code = 'REG57EVT';

SELECT is(
  (SELECT txt_surname FROM tbl_registration WHERE int_birth_year = 1975 AND txt_first_name = 'Anna'),
  'PGTAP57_TRAIL',
  '57.3 — trailing whitespace on txt_surname stripped on INSERT'
);

-- 57.4 — leading whitespace on the given name is stripped too
INSERT INTO tbl_registration (
  id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons
)
SELECT id_event, 'PGTAP57_LEAD', '  Gary', 'M', 1961, ARRAY['FOIL']::enum_weapon_type[]
FROM tbl_event WHERE txt_code = 'REG57EVT';

SELECT is(
  (SELECT txt_first_name FROM tbl_registration WHERE txt_surname = 'PGTAP57_LEAD'),
  'Gary',
  '57.4 — leading whitespace on txt_first_name stripped on INSERT'
);

-- 57.5 — an UPDATE that reintroduces whitespace is trimmed as well
UPDATE tbl_registration
   SET txt_first_name = '   Gary Edward   '
 WHERE txt_surname = 'PGTAP57_LEAD';

SELECT is(
  (SELECT txt_first_name FROM tbl_registration WHERE txt_surname = 'PGTAP57_LEAD'),
  'Gary Edward',
  '57.5 — whitespace introduced by UPDATE also stripped'
);

-- 57.6 — the real public write path stores trimmed values. Explicit casts are
-- required here for the same function-resolution reason documented at 49.14.
SET LOCAL ROLE anon;
SELECT fn_create_registration(
  (SELECT id_event FROM tbl_event WHERE txt_code = 'REG57EVT'),
  'PGTAP57_RPC '::TEXT, ' Piotr'::TEXT, 'M'::enum_gender_type, 1979::SMALLINT,
  ARRAY['SABRE']::enum_weapon_type[], NULL::INT, NULL::TEXT, NULL::TEXT
);
RESET ROLE;

SELECT is(
  (SELECT txt_surname || '|' || txt_first_name
     FROM tbl_registration WHERE int_birth_year = 1979),
  'PGTAP57_RPC|Piotr',
  '57.6 — fn_create_registration stores both names trimmed'
);

-- 57.7 — a padded resubmission still upserts onto the same unmatched row
-- rather than creating a second entry (trigger and the btrim-normalised
-- partial index agree on identity).
SET LOCAL ROLE anon;
SELECT fn_create_registration(
  (SELECT id_event FROM tbl_event WHERE txt_code = 'REG57EVT'),
  '  PGTAP57_RPC'::TEXT, 'Piotr  '::TEXT, 'M'::enum_gender_type, 1979::SMALLINT,
  ARRAY['SABRE','EPEE']::enum_weapon_type[], NULL::INT, NULL::TEXT, NULL::TEXT
);
RESET ROLE;

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration WHERE txt_surname = 'PGTAP57_RPC'),
  1,
  '57.7 — padded resubmission upserts the same row, no duplicate entry'
);

SELECT * FROM finish();

ROLLBACK;
