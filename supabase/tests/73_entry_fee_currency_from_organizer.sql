-- =============================================================================
-- pgTAP — the entry-fee currency follows the ORGANIZER, not a column default
-- =============================================================================
-- Verifies migration 20260905000001_entry_fee_currency_from_organizer.sql.
--
-- `txt_entry_fee_currency` was added with `DEFAULT 'PLN'`
-- (20260327000004_entry_fee_currency.sql:8). The EVF scraper only ever set a
-- currency when it found a SYMBOL (€ £ $) in the cost text, so any listing
-- written "50 EUR" produced no currency at all and the row silently took the
-- column default. That labelled 40 EVF events across 12 countries — none of
-- them Poland — as Polish złoty, and the public calendar page showed a Budapest
-- event priced at "40 PLN".
--
-- Same shape as the ADR-089 defect: a column with a non-null default is never
-- NULL, so nothing downstream can tell "not set" from "deliberately PLN".
--
-- The rule, from the association: SPWS and PZSz run domestic events priced in
-- złoty; EVF, FIE and anything unrecognised are priced in euro.
--
-- Plan-test-ID 73.
-- =============================================================================

BEGIN;

SELECT plan(8);

-- The trap itself is gone: "unset" must be expressible again.
SELECT col_hasnt_default('tbl_event', 'txt_entry_fee_currency',
  '73.1 — txt_entry_fee_currency no longer carries a blanket PLN default');

SELECT has_function('public', 'fn_default_entry_fee_currency', ARRAY['integer'],
  '73.2 — the organizer rule exists as a function');

-- The rule, asserted directly against the organizer registry.
SELECT is(
  fn_default_entry_fee_currency((SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS')),
  'PLN',
  '73.3 — SPWS runs domestic events, priced in PLN'
);

SELECT is(
  fn_default_entry_fee_currency((SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'PZSz')),
  'PLN',
  '73.4 — PZSz likewise'
);

SELECT is(
  fn_default_entry_fee_currency((SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF')),
  'EUR',
  '73.5 — EVF prices its circuit in EUR'
);

SELECT is(
  fn_default_entry_fee_currency((SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'FIE')),
  'EUR',
  '73.6 — FIE likewise'
);

-- Unknown organizer falls to EUR, deliberately: an unrecognised body is far
-- likelier to be international than Polish, and PLN is the value that caused
-- this defect.
SELECT is(
  fn_default_entry_fee_currency(NULL),
  'EUR',
  '73.7 — an unknown organizer defaults to EUR, not to PLN'
);

-- The rule is advisory, NOT enforced on write. An insert that states no
-- currency must still store NULL: pgTAP 8.25 asserts vw_calendar passes an
-- unstated currency through as NULL, and forcing a value here would make
-- "unstated" unrepresentable — the very defect this migration fixes, with a
-- better-chosen constant. Absence has to stay sayable.
WITH ins AS (
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  SELECT '73-TEST-EVF', '73 currency probe',
         (SELECT id_season FROM tbl_season ORDER BY id_season LIMIT 1),
         (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
         'CREATED'
  RETURNING txt_entry_fee_currency
)
SELECT is(
  (SELECT txt_entry_fee_currency FROM ins),
  NULL::TEXT,
  '73.8 — an unstated currency stays NULL; the rule is applied by callers, not forced on write'
);

SELECT * FROM finish();

ROLLBACK;
