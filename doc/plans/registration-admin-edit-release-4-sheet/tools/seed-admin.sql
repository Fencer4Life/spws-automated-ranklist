-- LOCAL only: throwaway entries on Łomianki for the FR-170 captures.
-- psql -v step=admin   — a throwaway roster fencer (ZZROSTER Maria, 1975) and four
--                        entries: three newcomers (one with a name too long for a
--                        phone row, I25) and one linked to ZZROSTER, declared
--                        1979, so the signed-in list shows its ≠ mark
-- psql -v step=remove  — removes every entry and the fencer this file wrote
-- Written through the tables, so every trigger runs as on PROD; LOCAL's roster
-- holds real people, whose names must not reach a committed capture.

\if :{?step}
\else
  \echo 'set -v step=admin|remove'
  \quit
\endif

SELECT :'step' = 'admin' AS is_admin, :'step' = 'remove' AS is_remove \gset

\if :is_admin
INSERT INTO tbl_fencer (txt_surname, txt_first_name, enum_gender, int_birth_year)
VALUES ('ZZROSTER', 'Maria', 'F', 1975);

INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons,
                              txt_club, txt_country, id_fencer)
SELECT e.id_event, v.s, v.f, v.g::enum_gender_type, v.y, v.w::enum_weapon_type[], v.club, v.c,
       CASE WHEN v.linked THEN (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZZROSTER') END
  FROM tbl_event e,
       (VALUES ('ZZNOWICKA', 'Ewa', 'F', 1970, '{EPEE}', NULL, 'POL', FALSE),
               ('ZZSMITH', 'John', 'M', 1990, '{EPEE}', 'London FC', 'GBR', FALSE),
               ('ZZROSTER', 'Maria', 'F', 1979, '{FOIL}', NULL, 'POL', TRUE),
               -- I25: a name too long for a phone row
               ('ZZVAN DER BRUGGEN-SCHOONHOVEN', 'Maximiliaan', 'M', 1968, '{SABRE}', NULL, 'NED', FALSE)) v(s, f, g, y, w, club, c, linked)
 WHERE e.txt_code = 'PEW5efs-2026-2027';
\endif

\if :is_remove
DELETE FROM tbl_registration r
 USING tbl_event e
 WHERE e.id_event = r.id_event AND e.txt_code = 'PEW5efs-2026-2027'
   AND (fn_name_without_title(r.txt_surname) LIKE 'ZZ%'
        OR r.id_fencer IN (SELECT id_fencer FROM tbl_fencer WHERE txt_surname LIKE 'ZZ%'))
RETURNING r.txt_surname, r.txt_first_name;
DELETE FROM tbl_fencer WHERE txt_surname LIKE 'ZZ%' RETURNING txt_surname, txt_first_name;
\endif

-- r.*: tbl_event has a txt_country of its own (the event's country).
SELECT r.txt_surname, r.txt_first_name, r.int_birth_year, r.txt_country, r.txt_club, r.id_fencer IS NOT NULL AS linked
  FROM tbl_registration r JOIN tbl_event e USING (id_event)
 WHERE e.txt_code = 'PEW5efs-2026-2027' ORDER BY 1;
