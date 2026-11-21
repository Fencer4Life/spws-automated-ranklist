-- LOCAL only: throwaway entries on Łomianki for the entry-list captures (FR-167 sheet).
-- psql -v step=plain   — five entries, none with a title
-- psql -v step=titled  — adds one entry whose surname carries a title
-- psql -v step=remove  — removes every entry this file wrote (surnames starting ZZ)
-- Written through the table, so the trigger writes the name form, as on PROD.

\if :{?step}
\else
  \echo 'set -v step=plain|titled|remove'
  \quit
\endif

SELECT :'step' = 'plain' AS is_plain, :'step' = 'titled' AS is_titled, :'step' = 'remove' AS is_remove \gset

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

\if :is_titled
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT e.id_event, 'dr zzveress', 'ilona katalin', 'F', 1979, '{EPEE}'::enum_weapon_type[]
  FROM tbl_event e WHERE e.txt_code = 'PEW5efs-2026-2027';
\endif

\if :is_remove
DELETE FROM tbl_registration r
 USING tbl_event e
 WHERE e.id_event = r.id_event AND e.txt_code = 'PEW5efs-2026-2027'
   AND fn_name_without_title(r.txt_surname) LIKE 'ZZ%'
RETURNING r.txt_surname, r.txt_first_name;
\endif

SELECT txt_surname, txt_first_name FROM tbl_registration r JOIN tbl_event e USING (id_event)
 WHERE e.txt_code = 'PEW5efs-2026-2027' ORDER BY 1;
