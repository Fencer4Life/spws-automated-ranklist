// Plan-test-ID 5.1: birthYearEstimate(vcat, seasonEndYear)
// TS port of python/matcher/pipeline.py::estimate_birth_year (single source of
// truth). ADR-056 Stage-0 convention (2026-06-13): `suggested` is the band
// MIDPOINT anchor (V0→35, V1→45, V2→55, V3→65, V4→75), replacing the
// youngest-edge. `range` still spans the full V-cat band for context.
// Bands: V0 <40, V1 40-49, V2 50-59, V3 60-69, V4 ≥70 (measured at season end).

import { describe, it, expect } from 'vitest'
import { estimateBirthYear, birthYearToVcat } from '../src/lib/birthYearEstimate'

describe('estimateBirthYear', () => {
  // 5.1.1 — V2 + 2024 → suggested 1969 (midpoint), range (1965, 1974)
  it('V2 / season 2024 → suggested 1969, range 1965-1974', () => {
    const out = estimateBirthYear('V2', 2024)
    expect(out).not.toBeNull()
    expect(out!.suggested).toBe(1969)
    expect(out!.range).toEqual([1965, 1974])
  })

  // 5.1.2 — V0 + 2024 → suggested 1989 (midpoint), range (1985, 1994)
  it('V0 / season 2024 → suggested 1989, range 1985-1994', () => {
    const out = estimateBirthYear('V0', 2024)
    expect(out!.suggested).toBe(1989)
    expect(out!.range).toEqual([1985, 1994])
  })

  // 5.1.3 — V1 + 2024 → suggested 1979 (midpoint), range (1975, 1984)
  it('V1 / season 2024 → suggested 1979, range 1975-1984', () => {
    const out = estimateBirthYear('V1', 2024)
    expect(out!.suggested).toBe(1979)
    expect(out!.range).toEqual([1975, 1984])
  })

  // 5.1.4 — V3 + 2024 → suggested 1959 (midpoint), range (1955, 1964)
  it('V3 / season 2024 → suggested 1959, range 1955-1964', () => {
    const out = estimateBirthYear('V3', 2024)
    expect(out!.suggested).toBe(1959)
    expect(out!.range).toEqual([1955, 1964])
  })

  // 5.1.5 — V4 + 2024 → suggested 1949 (midpoint anchor 75), range (1900, 1954)
  it('V4 / season 2024 → suggested 1949, range 1900-1954', () => {
    const out = estimateBirthYear('V4', 2024)
    expect(out!.suggested).toBe(1949)
    expect(out!.range).toEqual([1900, 1954])
  })

  // 5.1.6 — null vcat → null
  it('null vcat → null', () => {
    expect(estimateBirthYear(null, 2024)).toBeNull()
    expect(estimateBirthYear(undefined, 2024)).toBeNull()
  })

  // 5.1.7 — null seasonEndYear → null
  it('null seasonEndYear → null', () => {
    expect(estimateBirthYear('V2', null)).toBeNull()
    expect(estimateBirthYear('V2', undefined)).toBeNull()
  })

  // 5.1.8 — invalid V-cat → null
  it('invalid vcat → null', () => {
    expect(estimateBirthYear('V5', 2024)).toBeNull()
    expect(estimateBirthYear('Senior', 2024)).toBeNull()
    expect(estimateBirthYear('', 2024)).toBeNull()
  })

  // 5.1.9 — V2 + 2025 (different season) → suggested 1970 (midpoint)
  it('V2 / season 2025 → suggested 1970 (band shifts with season)', () => {
    const out = estimateBirthYear('V2', 2025)
    expect(out!.suggested).toBe(1970)
    expect(out!.range).toEqual([1966, 1975])
  })
})

// Phase 2 (P2.2, ADR-079 §6 UI) — birthYearToVcat(by, seasonEndYear), the
// reverse of estimateBirthYear. Mirrors python/pipeline/age_split.py::
// birth_year_to_vcat exactly: age = seasonEndYear - birthYear;
// V0 30-39, V1 40-49, V2 50-59, V3 60-69, V4 70+; age<30 → null (no V0 floor).
describe('birthYearToVcat', () => {
  it('age 35 (2026-1991) → V0', () => {
    expect(birthYearToVcat(1991, 2026)).toBe('V0')
  })
  it('age 45 (2026-1981) → V1', () => {
    expect(birthYearToVcat(1981, 2026)).toBe('V1')
  })
  it('age 55 (2026-1971) → V2', () => {
    expect(birthYearToVcat(1971, 2026)).toBe('V2')
  })
  it('age 65 (2026-1961) → V3', () => {
    expect(birthYearToVcat(1961, 2026)).toBe('V3')
  })
  it('age 70+ (2026-1950) → V4', () => {
    expect(birthYearToVcat(1950, 2026)).toBe('V4')
  })
  it('age 29 (below V0 floor) → null', () => {
    expect(birthYearToVcat(1997, 2026)).toBeNull()
  })
  it('band edges: age 39 → V0, age 40 → V1', () => {
    expect(birthYearToVcat(1987, 2026)).toBe('V0')
    expect(birthYearToVcat(1986, 2026)).toBe('V1')
  })
  it('null birthYear or seasonEndYear → null', () => {
    expect(birthYearToVcat(null, 2026)).toBeNull()
    expect(birthYearToVcat(1991, null)).toBeNull()
  })
})
