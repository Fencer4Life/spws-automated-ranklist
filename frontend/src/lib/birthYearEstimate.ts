// Plan-test-ID 5.1 (frontend/tests/birthYearEstimate.test.ts).
//
// TS port of python/tools/phase5_runner.py::_estimate_birth_year_for_vcat.
// Returns the YOUNGEST eligible birth year (= largest BY) for a given V-cat
// at season-end-year, plus the inclusive range. Used by the new
// CreateFencerFromAliasModal to prepopulate the BY input from the alias's
// staging context (latest_category_hint + latest_season_end_year exposed by
// vw_fencer_aliases per migration 20260503000001 / ADR-058).
//
// Bands match the Python helper exactly:
//   V0 — under 40                → suggested = season_end - 30, range [season_end-39, season_end-30]
//   V1 — 40-49                   → suggested = season_end - 40, range [season_end-49, season_end-40]
//   V2 — 50-59                   → suggested = season_end - 50, range [season_end-59, season_end-50]
//   V3 — 60-69                   → suggested = season_end - 60, range [season_end-69, season_end-60]
//   V4 — 70+                     → suggested = season_end - 70, range [1900, season_end-70]

export interface BirthYearEstimate {
  suggested: number
  range: [number, number]
}

const BANDS: Record<string, [number | null, number | null]> = {
  V0: [null, 39],
  V1: [40, 49],
  V2: [50, 59],
  V3: [60, 69],
  V4: [70, null],
}

export function estimateBirthYear(
  vcat: string | null | undefined,
  seasonEndYear: number | null | undefined,
): BirthYearEstimate | null {
  if (!vcat || !seasonEndYear || !Number.isFinite(seasonEndYear)) return null
  const band = BANDS[vcat]
  if (!band) return null
  const [ageMin, ageMax] = band
  const byMax = ageMin !== null ? seasonEndYear - ageMin : seasonEndYear - 30
  const byMin = ageMax !== null ? seasonEndYear - ageMax : 1900
  return { suggested: byMax, range: [byMin, byMax] }
}
