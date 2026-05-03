// Plan-test-ID 5.1: birthYearEstimate(vcat, seasonEndYear)
// TS port of python/tools/phase5_runner.py::_estimate_birth_year_for_vcat.
// Bands: V0 <40, V1 40-49, V2 50-59, V3 60-69, V4 ≥70 (measured at season end).
// Returns the YOUNGEST eligible BY (= largest BY) as `suggested`.

import { describe, it, expect } from 'vitest'
import { estimateBirthYear } from '../src/lib/birthYearEstimate'

describe('estimateBirthYear', () => {
  // 5.1.1 — V2 + 2024 → suggested 1974, range (1965, 1974)
  it('V2 / season 2024 → suggested 1974, range 1965-1974', () => {
    const out = estimateBirthYear('V2', 2024)
    expect(out).not.toBeNull()
    expect(out!.suggested).toBe(1974)
    expect(out!.range).toEqual([1965, 1974])
  })

  // 5.1.2 — V0 + 2024 → suggested 1994, range (1985, 1994)
  it('V0 / season 2024 → suggested 1994, range 1985-1994', () => {
    const out = estimateBirthYear('V0', 2024)
    expect(out!.suggested).toBe(1994)
    expect(out!.range).toEqual([1985, 1994])
  })

  // 5.1.3 — V1 + 2024 → suggested 1984, range (1975, 1984)
  it('V1 / season 2024 → suggested 1984, range 1975-1984', () => {
    const out = estimateBirthYear('V1', 2024)
    expect(out!.suggested).toBe(1984)
    expect(out!.range).toEqual([1975, 1984])
  })

  // 5.1.4 — V3 + 2024 → suggested 1964, range (1955, 1964)
  it('V3 / season 2024 → suggested 1964, range 1955-1964', () => {
    const out = estimateBirthYear('V3', 2024)
    expect(out!.suggested).toBe(1964)
    expect(out!.range).toEqual([1955, 1964])
  })

  // 5.1.5 — V4 + 2024 → suggested 1954, range (1900, 1954)
  it('V4 / season 2024 → suggested 1954, range 1900-1954', () => {
    const out = estimateBirthYear('V4', 2024)
    expect(out!.suggested).toBe(1954)
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

  // 5.1.9 — V2 + 2025 (different season) → suggested 1975
  it('V2 / season 2025 → suggested 1975 (band shifts with season)', () => {
    const out = estimateBirthYear('V2', 2025)
    expect(out!.suggested).toBe(1975)
    expect(out!.range).toEqual([1966, 1975])
  })
})
