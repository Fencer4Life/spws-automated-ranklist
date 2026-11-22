// RFYEAR.01–02 — the birth years a registration accepts (FR-168, plan
// registration-form-names-year-country rev 10, release 2). The database rule
// (supabase/tests/131_registration_birth_year.sql) uses the same two edges.
import { describe, it, expect } from 'vitest'
import { birthYearRange, cleanYearInput, decadeOf, inRange, vcatDecade } from '../src/lib/birthYearRange'
import { birthYearToVcat } from '../src/lib/birthYearEstimate'

const NOV_21_2026 = new Date('2026-11-21T12:00:00Z')

describe('RFYEAR.01 the range comes from the season and today', () => {
  it('2026/27 on 21 Nov 2026: 1906 to 1997', () => {
    expect(birthYearRange(2027, NOV_21_2026)).toEqual({ min: 1906, max: 1997 })
  })

  it('the youngest year is the V0 rule itself: the season later year minus 30', () => {
    expect(birthYearRange(2030, NOV_21_2026).max).toBe(2000)
  })

  it('the oldest year moves with today, not with the season', () => {
    expect(birthYearRange(2027, new Date('2031-01-02T12:00:00Z')).min).toBe(1911)
  })

  it('without a season the youngest year counts from this year', () => {
    expect(birthYearRange(null, NOV_21_2026)).toEqual({ min: 1906, max: 1996 })
  })

  it('both edges are inside; one year past either is not', () => {
    const r = { min: 1906, max: 1997 }
    expect([1905, 1906, 1997, 1998].map((y) => inRange(y, r))).toEqual([false, true, true, false])
    expect(inRange(null, r)).toBe(false)
  })

  it('a decade is the year with its last digit set to 0', () => {
    expect([1977, 1990, 1999, 1906].map(decadeOf)).toEqual([1970, 1990, 1990, 1900])
  })
})

describe('RFYEAR.02 typing keeps digits only, four at most', () => {
  it.each([
    ['-1972', '1972'],
    ['19a7', '197'],
    ['19700', '1970'],
    ['1 9 7 2', '1972'],
    ['47', '47'],
    ['', ''],
    ['+-e', ''],
  ])('%j → %j', (typed, kept) => {
    expect(cleanYearInput(typed)).toBe(kept)
  })
})

// FR-173 (D12): after a pick from the name list the year grid opens on the
// decade that holds most of the person's age category.
describe('RFAC.15 the decade a category opens the year grid on', () => {
  it.each([2027, 2031])('season ending %i: most years of the decade fall in the category', (season) => {
    for (const vcat of ['V0', 'V1', 'V2', 'V3', 'V4']) {
      const d = vcatDecade(vcat, season) as number
      expect(d % 10).toBe(0)
      const inCat = Array.from({ length: 10 }, (_, i) => d + i).filter((y) => birthYearToVcat(y, season) === vcat)
      expect(inCat.length).toBeGreaterThanOrEqual(5)
    }
  })

  it('V1 in 2026/27 (born 1978–1987) opens on the 1980s, V2 on the 1970s', () => {
    expect(vcatDecade('V1', 2027)).toBe(1980)
    expect(vcatDecade('V2', 2027)).toBe(1970)
  })

  it('no category or no season gives no decade', () => {
    expect(vcatDecade(null, 2027)).toBeNull()
    expect(vcatDecade('V9', 2027)).toBeNull()
    expect(vcatDecade('V1', null)).toBeNull()
  })
})
