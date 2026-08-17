// Association payment details shown on the registration payment step (ADR-079 §6).
//
// Why a module constant and not a prop chain or a DB column:
//   - register.html can pass payee=/iban= attributes through
//     <spws-registration>, but the in-app calendar modal cannot — CalendarView
//     renders <RegistrationModal> with no payment props at all, so the modal
//     path showed a BLANK account number for as long as it has existed.
//     A shared fallback fixes both surfaces in one place.
//   - These are not credentials. The IBAN is printed on every entry form and
//     is displayed publicly to every fencer who reaches the payment step; it
//     is payee information, deliberately public.
//
// This belongs in the database (an organizer- or season-level column) rather
// than in the bundle, so that changing it does not require a release. That is
// a follow-up, not a launch blocker — see the Wave 2 notes in
// doc/plans/ppw1-golive-scope-decisions-2026-08-17.html.
// The full registered name, not the "SPWS" short form: a bank transfer is
// matched against the account holder's legal name, and an abbreviation is a
// common cause of a returned or held payment.
export const SPWS_PAYEE = 'STOWARZYSZENIE POLSKICH WETERANÓW SZERMIERKI'

// Erste Bank Polska S.A. Kept in the association's own published grouping —
// it is what a fencer visually checks against the invitation before pasting,
// and Polish banking strips the spaces on input.
export const SPWS_IBAN = '06 1090 1665 0000 0001 5004 1549'

// Weapon names for the transfer title. Deliberately always Polish and NOT
// routed through the locale: the note is read by the association's treasurer
// against a Polish bank statement, so it must not change when a fencer
// happens to be browsing the form in English.
export const WEAPON_PL: Record<string, string> = {
  EPEE: 'SZPADA',
  FOIL: 'FLORET',
  SABRE: 'SZABLA',
}
