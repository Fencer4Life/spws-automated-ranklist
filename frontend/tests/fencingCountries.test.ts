// RFCTRY.01–03 — the fencing-country table (FR-169, plan registration-form-
// names-year-country rev 10, release 3). One reviewed table pairs each
// three-letter fencing code with the two-letter code the flags use; the
// database holds the same codes (tbl_fencing_country), read here from its
// migration so the two cannot drift.
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve } from 'path'
import { FENCING_COUNTRIES, flagIso, countryName } from '../src/lib/fencingCountries'
import { FLAG_SVG } from '../src/lib/flags.generated'

const MIGRATION = resolve(__dirname, '../../supabase/migrations/20261121000004_registration_country.sql')

function databaseCodes(): string[] {
  const sql = readFileSync(MIGRATION, 'utf8')
  const block = sql.split('INSERT INTO tbl_fencing_country')[1].split(';')[0]
  return [...block.matchAll(/\('([A-Z]{3})'/g)].map((m) => m[1])
}

describe('RFCTRY.01 the codes', () => {
  const codes = FENCING_COUNTRIES.map((c) => c.code)

  it('every code is three capital letters', () => {
    expect(codes.filter((c) => !/^[A-Z]{3}$/.test(c))).toEqual([])
  })

  it('no code appears twice', () => {
    expect(new Set(codes).size).toBe(codes.length)
  })

  it('the table equals the database list', () => {
    expect([...codes].sort()).toEqual(databaseCodes().sort())
  })

  it('it covers the countries of the entry lists and the calendar', () => {
    for (const c of ['POL', 'GER', 'GBR', 'SUI', 'UKR', 'HUN', 'AUT', 'ITA', 'FRA', 'ESP', 'USA', 'GEO', 'BLR', 'LTU', 'AIN']) {
      expect(codes).toContain(c)
    }
  })
})

describe('RFCTRY.02 the pairs where the two codes differ', () => {
  it.each([
    ['GER', 'DE'], ['SUI', 'CH'], ['NED', 'NL'], ['CRO', 'HR'], ['DEN', 'DK'], ['POR', 'PT'],
    ['RSA', 'ZA'], ['SLO', 'SI'], ['BUL', 'BG'], ['LAT', 'LV'], ['GRE', 'GR'], ['IRI', 'IR'],
    ['SVK', 'SK'], ['SRB', 'RS'], ['RUS', 'RU'], ['UKR', 'UA'], ['KSA', 'SA'], ['UAE', 'AE'],
    ['MAS', 'MY'], ['INA', 'ID'], ['CHI', 'CL'], ['URU', 'UY'], ['PUR', 'PR'], ['ALG', 'DZ'],
  ])('%s → %s', (code, iso) => {
    expect(flagIso(code)).toBe(iso)
  })

  it('every code paired with a flag has a drawn flag', () => {
    const missing = FENCING_COUNTRIES.filter((c) => c.iso && !FLAG_SVG[c.iso]).map((c) => c.code)
    expect(missing).toEqual([])
  })

  it('an unknown code has no flag', () => {
    expect(flagIso('XYZ')).toBeNull()
    expect(flagIso(null)).toBeNull()
  })
})

describe('RFCTRY.03 the codes without a drawn flag', () => {
  it('are AIN and TPE', () => {
    expect(FENCING_COUNTRIES.filter((c) => c.iso === null).map((c) => c.code).sort()).toEqual(['AIN', 'TPE'])
  })

  it('carry their own names', () => {
    expect(countryName('AIN', 'pl')).toBe('Indywidualni Sportowcy Neutralni')
    expect(countryName('AIN', 'en')).toBe('Individual Neutral Athletes')
    expect(countryName('TPE', 'en')).toBe('Chinese Taipei')
  })

  it('every other name comes from the browser in the page language', () => {
    expect(countryName('GER', 'pl')).toBe('Niemcy')
    expect(countryName('GER', 'en')).toBe('Germany')
    expect(countryName('GBR', 'pl')).toBe('Wielka Brytania')
    expect(countryName('SUI', 'pl')).toBe('Szwajcaria')
  })

  it('an unknown code is named by itself', () => {
    expect(countryName('XYZ', 'pl')).toBe('XYZ')
  })
})
