// Plan-test-ID 5.1 (frontend/tests/birthYearEstimate.test.ts).
//
// TS mirror of python/matcher/pipeline.py::estimate_birth_year (the single
// source of truth). Returns the band MIDPOINT anchor birth year for a given
// V-cat at season-end-year, plus the inclusive band range. Used by the
// CreateFencerFromAliasModal to prepopulate the BY input from the alias's
// staging context (latest_category_hint + latest_season_end_year exposed by
// vw_fencer_aliases per migration 20260503000001 / ADR-058).
//
// ADR-056 Stage-0 convention (2026-06-13): `suggested` is the band MIDPOINT,
// replacing the youngest-edge. Ranking-neutral — both map to the same V-cat
// band; only the year within the band shifts. Anchor ages must stay in
// lockstep with the Python _CATEGORY_MIDPOINT_AGE table:
//   V0 — under 40 → anchor 35 → suggested = season_end-35, range [season_end-39, season_end-30]
//   V1 — 40-49    → anchor 45 → suggested = season_end-45, range [season_end-49, season_end-40]
//   V2 — 50-59    → anchor 55 → suggested = season_end-55, range [season_end-59, season_end-50]
//   V3 — 60-69    → anchor 65 → suggested = season_end-65, range [season_end-69, season_end-60]
//   V4 — 70+      → anchor 75 → suggested = season_end-75, range [1900, season_end-70]

export interface BirthYearEstimate {
  suggested: number
  range: [number, number]
}

// [ageMin, ageMax] band edges (for the displayed range) + midpoint anchor age.
const BANDS: Record<string, { ageMin: number | null; ageMax: number | null; anchor: number }> = {
  V0: { ageMin: null, ageMax: 39, anchor: 35 },
  V1: { ageMin: 40, ageMax: 49, anchor: 45 },
  V2: { ageMin: 50, ageMax: 59, anchor: 55 },
  V3: { ageMin: 60, ageMax: 69, anchor: 65 },
  V4: { ageMin: 70, ageMax: null, anchor: 75 },
}

export function estimateBirthYear(
  vcat: string | null | undefined,
  seasonEndYear: number | null | undefined,
): BirthYearEstimate | null {
  if (!vcat || !seasonEndYear || !Number.isFinite(seasonEndYear)) return null
  const band = BANDS[vcat]
  if (!band) return null
  const { ageMin, ageMax, anchor } = band
  const byMax = ageMin !== null ? seasonEndYear - ageMin : seasonEndYear - 30
  const byMin = ageMax !== null ? seasonEndYear - ageMax : 1900
  // Suggest the band midpoint anchor; range still spans the full band.
  return { suggested: seasonEndYear - anchor, range: [byMin, byMax] }
}
