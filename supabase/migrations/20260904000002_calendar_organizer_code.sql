-- =============================================================================
-- vw_calendar exposes the organizer's CODE, not only its display name
-- =============================================================================
-- The calendar card shows an organizer logo, and it was choosing which logo by
-- guessing from the event code's prefix: PEW -> EVF, IMEW|IMSW|MEW|MSW|PSW ->
-- FIE, MPW -> SPWS, PPS|MPS -> PZSz, everything else -> SPWS.
--
-- The guess is wrong in two of the ten code families actually in use, because
-- tbl_event already knows the answer and the heuristic was never reconciled
-- with it:
--
--   DMEW  organizer EVF   guessed SPWS   (fell through to the default)
--   IMEW  organizer EVF   guessed FIE    (swept up with the world championships)
--
-- DMEW is the European TEAM championship and IMEW the individual European
-- championship; both are EVF's. Only IMSW and MSW are FIE's. Nothing flagged the
-- drift because a heuristic has no way to disagree with the data it is
-- approximating.
--
-- The view already joins tbl_organizer for txt_organizer_name, so the code is
-- one column away and costs nothing. Exposing it lets the card read the
-- organizer as a fact instead of inferring it, the same correction already
-- applied to the event's weapons (ADR-089) and its city (ADR-088).
--
-- txt_organizer_name stays: it is the human-readable label and is used
-- elsewhere. This adds a column and changes no existing one.
--
-- The column is appended LAST rather than placed beside txt_organizer_name:
-- CREATE OR REPLACE VIEW may only add columns at the end, and inserting one
-- mid-list fails with "cannot change name of view column".
--
-- Plan-test-ID 72 (supabase/tests/72_calendar_organizer_code.sql).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

CREATE OR REPLACE VIEW vw_calendar AS
SELECT e.id_event,
    e.txt_code,
    e.txt_name,
    e.id_season,
    s.txt_code AS txt_season_code,
    e.id_organizer,
    o.txt_name AS txt_organizer_name,
    e.txt_location,
    e.txt_country,
    e.txt_venue_address,
    e.url_invitation,
    e.num_entry_fee,
    e.txt_entry_fee_currency,
    e.arr_weapons,
    e.dt_start,
    e.dt_end,
    e.url_event,
    e.enum_status,
    e.url_registration,
    e.dt_registration_deadline,
    e.url_event_2,
    e.url_event_3,
    e.url_event_4,
    e.url_event_5,
    e.id_evf_event,
    e.txt_evf_slug,
    e.id_evf_calendar_event,
    e.id_prior_event,
    count(t.id_tournament)::integer AS num_tournaments,
    COALESCE(bool_or(t.enum_type = ANY (ARRAY['PEW'::enum_tournament_type, 'MEW'::enum_tournament_type, 'MSW'::enum_tournament_type, 'PSW'::enum_tournament_type])), false) AS bool_has_international,
    e.json_ingest_sources,
    e.json_source_overrides,
    e.url_entry_list,
    e.txt_organizer_email,
    e.ts_ftl_sent,
    e.num_entry_fee_2w,
    e.num_entry_fee_3w,
    e.bool_use_spws_registration,
    e.dt_start_first_published,
    e.txt_payee AS txt_event_payee,
    e.txt_iban AS txt_event_iban,
    COALESCE(e.txt_payee, o.txt_payee) AS txt_payee,
    COALESCE(e.txt_iban, o.txt_iban) AS txt_iban,
        CASE
            WHEN e.txt_payee IS NOT NULL AND e.txt_iban IS NOT NULL THEN 'EVENT'::text
            WHEN o.txt_payee IS NOT NULL AND o.txt_iban IS NOT NULL THEN 'ORGANIZER'::text
            ELSE 'NONE'::text
        END AS txt_payment_source,
    o.txt_code AS txt_organizer_code
   FROM tbl_event e
     JOIN tbl_season s ON s.id_season = e.id_season
     LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
     LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
  GROUP BY e.id_event, s.txt_code, o.txt_name, o.txt_code, o.txt_payee, o.txt_iban
  ORDER BY e.dt_start;

COMMIT;
