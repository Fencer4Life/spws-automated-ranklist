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
