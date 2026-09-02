// Weapon names for the transfer title.
//
// The association's payee and IBAN used to live here too. They moved into the
// database on 2026-09-02 (migration 20260902000001): the account is held on
// tbl_organizer as the organizer default, overridable per event on tbl_event,
// resolved by vw_calendar and delivered with the event. A constant compiled into
// the bundle could only ever describe one organizer and changing it required a
// release — which is exactly what this file's own comment used to ask for.
//
// These names are deliberately always Polish and NOT routed through the locale:
// the note is read by the association's treasurer against a Polish bank
// statement, so it must not change when a fencer happens to be browsing the
// form in English.
export const WEAPON_PL: Record<string, string> = {
  EPEE: 'SZPADA',
  FOIL: 'FLORET',
  SABRE: 'SZABLA',
}

// TRANSITIONAL — delete once PROD carries migration 20260902000001.
//
// The account lives in the database now, but the Pages bundle deploys ahead of
// deploy-prod (which waits on a required reviewer), so this frontend runs for a
// while against a PROD database that has no payment columns. Without a fallback
// the live payment panel would show a blank payee and IBAN to fencers holding a
// registration deadline.
//
// It is the association's own account and matches what the bundle showed before
// the move, so on un-migrated PROD the page behaves exactly as it did. Once the
// columns exist the resolved value always wins and this is never read.
//
// Tracked as ADR-079 open item 8.
export const LEGACY_SPWS_PAYEE = 'STOWARZYSZENIE POLSKICH WETERANÓW SZERMIERKI'
export const LEGACY_SPWS_IBAN = 'PL 06 1090 1665 0000 0001 5004 1549'
