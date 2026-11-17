-- =============================================================================
-- REGDEL — an administrator removes an entry from the entry list (FR-166)
-- =============================================================================
-- The admin application deletes a registration directly, under the table's one
-- policy ("Admin all registrations", 20260704000001): a signed-in
-- administrator may delete, a visitor may not. No new function and no grant
-- change; these assertions pin the permission the "Usuń" button relies on.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(4);

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW9-2025-2026', 'REGDEL fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2026-03-01', DATE '2026-03-01', 'PLANNED';

INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT e.id_event, s, 'Test', 'F', 1970, ARRAY['EPEE']::enum_weapon_type[]
  FROM tbl_event e, (VALUES ('REGDELA'), ('REGDELB')) v(s) WHERE e.txt_code = 'PPW9-2025-2026';

-- REGDEL.02 — a visitor's delete is refused, and the row is still there.
SELECT throws_ok(
  $$SET LOCAL ROLE anon;
    SELECT set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
    DELETE FROM tbl_registration WHERE txt_surname = 'REGDELB'$$,
  '42501', NULL,
  'REGDEL.02 a visitor''s delete of a registration is refused');
RESET ROLE;

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration WHERE txt_surname = 'REGDELB'), 1,
  'REGDEL.02 the refused delete leaves the row in place');

-- REGDEL.01 — a signed-in administrator's delete removes the row, and only it.
-- The number of rows removed leaves the DO block through a transaction-local
-- setting, read back once the role is reset.
DO $body$
DECLARE
  v_removed INT;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
  DELETE FROM tbl_registration WHERE txt_surname = 'REGDELA';
  GET DIAGNOSTICS v_removed = ROW_COUNT;
  RESET ROLE;
  PERFORM set_config('regdel.removed', v_removed::TEXT, TRUE);
END;
$body$;

SELECT is(current_setting('regdel.removed')::INT, 1,
  'REGDEL.01 an administrator''s delete removes the one row');

SELECT results_eq(
  $$SELECT txt_surname FROM tbl_registration
     WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW9-2025-2026')
     ORDER BY txt_surname$$,
  $$VALUES ('REGDELB'::TEXT)$$,
  'REGDEL.01 the administrator''s delete removed that row and no other');

SELECT * FROM finish();
ROLLBACK;
