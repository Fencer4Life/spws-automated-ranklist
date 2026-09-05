-- =============================================================================
-- The entry-fee currency follows the ORGANIZER — as a rule, not a column default
-- =============================================================================
-- `txt_entry_fee_currency` was introduced with `DEFAULT 'PLN'`
-- (20260327000004_entry_fee_currency.sql:8). The EVF calendar scraper only set
-- a currency when it found a SYMBOL (€ £ $) in the listing's cost text, so a
-- listing written "50 EUR" — the form EVF normally uses — produced no currency
-- at all and the row silently took that default.
--
-- Measured on PROD 2026-09-05: 40 EVF events across 12 countries, none of them
-- Poland, were stored as Polish złoty, and the public calendar page showed a
-- Budapest competition priced "40 PLN".
--
-- This is the ADR-089 defect in a second column: a column with a non-null
-- default is never NULL, so no downstream guard can distinguish "nobody set
-- this" from "deliberately PLN", and a wrong value is indistinguishable from a
-- deliberate one.
--
-- The rule, from the association: SPWS and PZSz run domestic competitions and
-- price them in złoty; EVF, FIE and anything unrecognised price in euro.
-- "Unrecognised defaults to EUR" is deliberate — an unknown organizer is far
-- likelier to be an international body than a Polish one.
--
-- WHY THIS IS NOT A TRIGGER OR A NEW DEFAULT
-- ------------------------------------------
-- The obvious fix — fill NULL from the organizer on write — was built first and
-- rejected on evidence: pgTAP 8.25 (`05_calendar_view.sql:409`) asserts that
-- `vw_calendar` passes an UNSTATED currency through as NULL. Forcing a value on
-- write makes "unstated" unrepresentable, which is precisely the defect being
-- fixed here, only with a better-chosen constant. Absence has to stay sayable.
--
-- So the column loses its default, absence becomes expressible again, and the
-- rule lives in a function the write paths call. `parse_fee_and_currency()` in
-- python/scrapers/evf_calendar.py already states EUR for EVF listings.
-- =============================================================================

-- 1. Absence becomes expressible again.
ALTER TABLE tbl_event ALTER COLUMN txt_entry_fee_currency DROP DEFAULT;

-- 2. The rule, in one place, for any write path that wants it.
CREATE OR REPLACE FUNCTION fn_default_entry_fee_currency(p_id_organizer INTEGER)
RETURNS TEXT
LANGUAGE SQL
STABLE
AS $$
  SELECT CASE
           WHEN (SELECT txt_code FROM tbl_organizer WHERE id_organizer = p_id_organizer)
                IN ('SPWS', 'PZSz')
           THEN 'PLN'
           ELSE 'EUR'
         END;
$$;

COMMENT ON FUNCTION fn_default_entry_fee_currency(INTEGER) IS
  'Entry-fee currency for an organizer: PLN for SPWS/PZSz (domestic), EUR for '
  'EVF, FIE and any unrecognised or absent organizer. Advisory — callers apply '
  'it; it is deliberately NOT a column default or a trigger, so that an '
  'unstated currency stays NULL (pgTAP 8.25). See migration 20260905000001.';

-- ADR-083 deny-by-default: a new function is EXECUTEable by PUBLIC unless said
-- otherwise, and pgTAP 52.7 asserts the anon-EXECUTEable set exactly. This is
-- an internal helper, not part of the public read surface.
REVOKE ALL ON FUNCTION fn_default_entry_fee_currency(INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_default_entry_fee_currency(INTEGER) FROM anon;
REVOKE ALL ON FUNCTION fn_default_entry_fee_currency(INTEGER) FROM authenticated;

-- 3. Bring existing rows onto the rule, so LOCAL and CERT converge with the
--    correction already applied to PROD on 2026-09-05. Only rows that actually
--    state a currency are touched: a NULL means "not stated" and stays NULL.
UPDATE tbl_event e
SET txt_entry_fee_currency = fn_default_entry_fee_currency(e.id_organizer)
WHERE e.txt_entry_fee_currency IS NOT NULL
  AND e.txt_entry_fee_currency IS DISTINCT FROM fn_default_entry_fee_currency(e.id_organizer);
