import en from './locales/en.json'
import pl from './locales/pl.json'

export type Locale = 'en' | 'pl'

const locales: Record<Locale, Record<string, string>> = { en, pl }

let current = $state<Locale>('pl')

export function getLocale(): Locale {
  return current
}

export function setLocale(l: Locale): void {
  current = l
}

export function t(key: string, vars?: Record<string, string | number>): string {
  return tIn(current, key, vars)
}

/**
 * The same lookup, in a language the viewer is not currently reading.
 *
 * The FTL export archive carries its instructions in BOTH languages whatever
 * the page is set to, because the person who downloads it is often not the
 * person who reads it at the venue. Without this, rendering the Polish copy
 * would mean switching the whole UI and switching it back.
 */
export function tIn(
  locale: Locale,
  key: string,
  vars?: Record<string, string | number>,
): string {
  let str = locales[locale][key] ?? key
  if (vars) {
    for (const [k, v] of Object.entries(vars)) {
      str = str.replace(`{${k}}`, String(v))
    }
  }
  return str
}
