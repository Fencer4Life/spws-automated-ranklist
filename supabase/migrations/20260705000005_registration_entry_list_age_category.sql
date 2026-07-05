-- =============================================================================
-- FR-123 mockup parity — expose computed age category on the public entry-list
-- view (doc/mockups/registration_entry_list.html shows a "Kat." column + filter;
-- the view never carried it). int_birth_year itself is NEVER added to the SELECT
-- list — only the derived category, preserving GDPR minimisation (ADR-078,
-- pinned by pgTAP 49.15/49.27).
-- =============================================================================

DROP VIEW IF EXISTS vw_registration_entry_list;

CREATE VIEW vw_registration_entry_list AS
SELECT
  r.id_registration,
  r.id_event,
  r.txt_surname,
  r.txt_first_name,
  r.enum_gender,
  r.arr_weapons,
  fn_age_category(r.int_birth_year::INT, EXTRACT(YEAR FROM s.dt_end)::INT) AS enum_age_category
FROM tbl_registration r
JOIN tbl_event e ON e.id_event = r.id_event
JOIN tbl_season s ON s.id_season = e.id_season;

GRANT SELECT ON vw_registration_entry_list TO anon;
GRANT SELECT ON vw_registration_entry_list TO authenticated;

COMMENT ON VIEW vw_registration_entry_list IS
  'Public entry-list roster (FR-123): every declared registration, no payment '
  'gate. Excludes raw birth year and club (GDPR minimisation, ADR-078); exposes '
  'only the derived enum_age_category via fn_age_category, matching '
  'doc/mockups/registration_entry_list.html.';
