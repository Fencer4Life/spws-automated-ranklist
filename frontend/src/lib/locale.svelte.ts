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
  let str = locales[current][key] ?? key
  if (vars) {
    for (const [k, v] of Object.entries(vars)) {
      str = str.replace(`{${k}}`, String(v))
    }
  }
  return str
}
