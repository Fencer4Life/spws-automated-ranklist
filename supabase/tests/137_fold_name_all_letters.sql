-- pgt-ignore-all lint/safety: pgTAP runs this file in one rolled-back transaction on LOCAL/CI, never on CERT/PROD
-- =============================================================================
-- I27 (plan registration-name-list-under-surname-2026-11-22, rev 1, Part A):
-- fn_fold_name folds every accented letter to its base letter, so a name typed
-- without its accents finds the name written with them.
--
--   RFAC.31  each Polish letter and each accented letter in our data folds to
--            its base letter, in capitals
--   RFAC.32  a name typed without accents folds like the name with them; the
--            space and hyphen rules are as before
--   RFAC.33  the stored given-name keys follow the repaired folding, with no
--            duplicate, and the name check answers for a name typed without
--            its accents
-- =============================================================================

BEGIN;
SELECT plan(8);

-- RFAC.31
SELECT is(fn_fold_name('ĄąĆćĘęŁłŃńÓóŚśŹźŻż'), 'AACCEELLNNOOSSZZZZ',
  'RFAC.31: every Polish letter folds to its base letter');
SELECT is(fn_fold_name('ÁáÀÄäÃãÅåÉéÈĖÍíÌîÑÓóÔöÖőŐÕØÚúÛüÜçÇ'), 'AAAAAAAAAEEEEIIIINOOOOOOOOOUUUUUCC',
  'RFAC.31: every accented letter found in our data folds to its base letter');

-- RFAC.32
SELECT is(fn_fold_name('Zieba Zaneta'), fn_fold_name('Zięba Żaneta'),
  'RFAC.32: a Polish name typed without accents folds like the name with them');
SELECT is(fn_fold_name('kovacs eva'), fn_fold_name('Kovács Éva'),
  'RFAC.32: a Hungarian name typed without accents folds like the name with them');
SELECT is(fn_fold_name('Muller Soren'), fn_fold_name('Müller Søren'),
  'RFAC.32: a German or Danish name typed without accents folds like the name with them');
SELECT is(fn_fold_name('  Nowak   -  Kowalska  '), 'NOWAK-KOWALSKA',
  'RFAC.32: spaces collapse and a spaced hyphen closes, as before');

-- RFAC.33
SELECT is(
  (SELECT count(*) FROM tbl_common_given_name
    WHERE txt_name_key IS DISTINCT FROM fn_fold_name(txt_name))::INT,
  0, 'RFAC.33: every stored given-name key is the repaired folding of its name');

INSERT INTO tbl_common_given_name (txt_name, txt_source) VALUES ('Jóźwiłła', 'EVF');
SELECT is((SELECT bool_given_name_known FROM fn_registration_name_check('X', 'jozwilla')), TRUE,
  'RFAC.33: a known given name typed without its accents is known');

SELECT * FROM finish();
ROLLBACK;
