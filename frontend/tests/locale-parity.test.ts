// Locale parity guard — pl.json and en.json must always have identical key sets.
// Regression scaffold for the admin-UI label sweep (calm-tinkering-popcorn plan).
// Baseline: 327 = 327 keys (ADR-077 added status_created + status_scored).

import { describe, it, expect } from 'vitest'
import pl from '../src/lib/locales/pl.json'
import en from '../src/lib/locales/en.json'

describe('locale parity', () => {
  const plKeys = new Set(Object.keys(pl))
  const enKeys = new Set(Object.keys(en))

  it('pl.json and en.json have identical key sets', () => {
    const missingInEn = [...plKeys].filter((k) => !enKeys.has(k))
    const missingInPl = [...enKeys].filter((k) => !plKeys.has(k))
    expect(missingInEn, `keys in pl.json missing from en.json: ${missingInEn.join(', ')}`).toEqual([])
    expect(missingInPl, `keys in en.json missing from pl.json: ${missingInPl.join(', ')}`).toEqual([])
  })

  it('no empty string values in either locale', () => {
    const emptyPl = Object.entries(pl).filter(([, v]) => v === '').map(([k]) => k)
    const emptyEn = Object.entries(en).filter(([, v]) => v === '').map(([k]) => k)
    expect(emptyPl, `empty values in pl.json: ${emptyPl.join(', ')}`).toEqual([])
    expect(emptyEn, `empty values in en.json: ${emptyEn.join(', ')}`).toEqual([])
  })
})
