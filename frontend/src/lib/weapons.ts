import type { WeaponType } from './types'
import type { WeaponLetter } from './calendarMonths'

/**
 * The weapon vocabulary shared by the event card's pills and the calendar
 * footer's filter chips.
 *
 * It exists because those two controls must agree. The card taught the reader
 * that a green pill means épée; the footer chip has to mean the same thing or
 * the colour stops carrying information. The card's colours used to live only
 * in its own scoped `<style>` block, which a second component cannot reach —
 * so a filter chip would have had to restate the six hex values, and the pair
 * would have drifted the first time either was retouched.
 *
 * Colours are therefore applied INLINE from here rather than by CSS class.
 * That is deliberate: Svelte scopes component styles, and this repo has no
 * global stylesheet to hang shared custom properties on, so a TypeScript
 * constant is the only place the two components can genuinely share one value.
 */
export const WEAPON_ORDER: readonly WeaponType[] = ['EPEE', 'FOIL', 'SABRE']

export const WEAPON_LETTER: Record<WeaponType, WeaponLetter> = {
  EPEE: 'E',
  FOIL: 'F',
  SABRE: 'S',
}

export const WEAPON_TYPE: Record<WeaponLetter, WeaponType> = {
  E: 'EPEE',
  F: 'FOIL',
  S: 'SABRE',
}

/** Locale keys — `epee` / `foil` / `sabre` carry both languages already. */
export const WEAPON_KEY: Record<WeaponLetter, string> = {
  E: 'epee',
  F: 'foil',
  S: 'sabre',
}

/** Fill and text, paired: the text is the dark end of the fill's own family. */
export const WEAPON_COLOR: Record<WeaponLetter, { bg: string; fg: string }> = {
  E: { bg: '#cfe8dd', fg: '#0b3d2e' },
  F: { bg: '#ddd9f5', fg: '#2b2564' },
  S: { bg: '#f7ddd2', fg: '#5c2410' },
}
