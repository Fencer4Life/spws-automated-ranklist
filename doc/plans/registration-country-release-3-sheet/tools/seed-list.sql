-- LOCAL only: throwaway entries on Łomianki for the FR-169 entry-list captures.
-- psql -v step=plain    — five entries, none with a country (the list as before)
-- psql -v step=country  — seven entries with countries, one without, one AIN,
--                         and a long name
-- psql -v step=remove   — removes every entry this file wrote (surnames starting ZZ)
-- Written through the table, so every trigger runs as on PROD.

\if :{?step}
\else
  \echo 'set -v step=plain|country|remove'
  \quit
\endif

SELECT :'step' = 'plain' AS is_plain, :'step' = 'country' AS is_country, :'step' = 'remove' AS is_remove \gset

\if :is_plain
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT e.id_event, v.s, v.f, v.g::enum_gender_type, v.y, v.w::enum_weapon_type[]
  FROM tbl_event e,
       (VALUES ('ZZDUDA', 'Ewa', 'F', 1975, '{EPEE}'),
               ('ZZKOWALSKA', 'Anna', 'F', 1980, '{FOIL}'),
               ('ZZNOWAK', 'Piotr', 'M', 1968, '{SABRE}'),
               ('ZZWOLF', 'Eva', 'F', 1972, '{EPEE,FOIL}'),
               ('ZZWOJCIECHOWSKA-KOWALCZYK', 'Aleksandra', 'F', 1966, '{EPEE}')) v(s, f, g, y, w)
 WHERE e.txt_code = 'PEW5efs-2026-2027';
\endif

\if :is_country
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons, txt_country)
SELECT e.id_event, v.s, v.f, v.g::enum_gender_type, v.y, v.w::enum_weapon_type[], v.c
  FROM tbl_event e,
       (VALUES ('ZZKOWALSKA', 'Anna', 'F', 1980, '{FOIL}', 'POL'),
               ('ZZMULLER', 'Hans', 'M', 1970, '{EPEE}', 'GER'),
               ('ZZNEUTRAL', 'Ivan', 'M', 1960, '{EPEE,SABRE}', 'AIN'),
               ('ZZNOWAK', 'Piotr', 'M', 1968, '{SABRE}', NULL),
               ('ZZSCHMIDT', 'Eva', 'F', 1982, '{EPEE}', 'GER'),
               ('ZZSMITH', 'John', 'M', 1990, '{EPEE}', 'GBR'),
               ('ZZWOJCIECHOWSKA-KOWALCZYK', 'Aleksandra', 'F', 1966, '{EPEE,FOIL}', 'POL'),
               ('ZZVAN DER BRUGGEN-SCHOONHOVEN', 'Annemarie', 'F', 1961, '{EPEE}', 'NED')) v(s, f, g, y, w, c)
 WHERE e.txt_code = 'PEW5efs-2026-2027';
\endif

\if :is_remove
DELETE FROM tbl_registration r
 USING tbl_event e
 WHERE e.id_event = r.id_event AND e.txt_code = 'PEW5efs-2026-2027'
   AND fn_name_without_title(r.txt_surname) LIKE 'ZZ%'
RETURNING r.txt_surname, r.txt_first_name;
\endif

-- r.txt_country: tbl_event has a txt_country of its own (the event's country).
SELECT r.txt_surname, r.txt_first_name, r.txt_country FROM tbl_registration r JOIN tbl_event e USING (id_event)
 WHERE e.txt_code = 'PEW5efs-2026-2027' ORDER BY 1;
