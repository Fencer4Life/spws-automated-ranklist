// =============================================================================
// SS26.CALC / SS26.PARITY — the shared scoring formula module
// =============================================================================
// doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html §08 and §11
// step 8. Written BEFORE src/lib/scoring.ts exists, per §10.
//
// WHY THIS MODULE EXISTS
// -----------------------------------------------------------------------------
// §08: the formula is currently written THREE times in browser JavaScript —
// kalkulator-punktow-za-wynik-spws.v2.html (fN/rundy/parts/total), its
// byte-identical WordPress copy, and Tabela-punktacji-SPWS_2026-2027.html
// (firstPlaceBase/wonRounds/scoreParts/totalScore). They already disagree: the
// annex floors at MIN_PARTICIPANTS = 4, the calculator accepts N = 1. This module
// is the one implementation all three collapse into.
//
// Per-cell and whole-grid score RPCs were rejected for the annex, which renders
// up to 300 x 300 cells and re-renders on every rank-coefficient change. So the
// formula lives in exactly two places — here and the SQL strategies — and these
// tests are the pin between them.
//
// EVERY EXPECTATION BELOW WAS DERIVED FROM THE DATABASE, NOT GUESSED
// -----------------------------------------------------------------------------
// Produced by calling fn_score_by_engine directly against the local stack with
// the 2026/2027 configuration (mp_value 50, base_slope 10, de_round 10, podium
// 3/2/1) and rounding exactly as fn_preview_tournament_score does. If any value
// here disagrees with SQL, that is a parity defect and this file is the alarm.
//
// TWO PROPERTIES WORTH READING THE TABLE FOR
// -----------------------------------------------------------------------------
//   * N = 1 scores 59.00 classic and 19.00 field-scaled (§04, decided 19 Sep
//     2026). ADR-066 records six of seven FOIL brackets in PPW2-2025-2026 as
//     single-competitor, so this re-prices published results deliberately.
//   * From N = 32 upward the two engines are IDENTICAL, because
//     10 x log2(32) = 50. The entire difference is confined to fields below 32.
// =============================================================================

import { describe, it, expect } from 'vitest'
import {
  CLASSIC_ENGINE,
  FIELD_SCALED_ENGINE,
  scoreComponents,
  type ScoringParams,
} from '../src/lib/scoring'

// The 2026/2027 stored configuration, as fn_public_scoring_params publishes it.
const PARAMS: ScoringParams = {
  engineCode: FIELD_SCALED_ENGINE,
  engineLabel: 'SPWS (skalowany stawką)',
  mpValue: 50,
  baseSlope: 10,
  deRound: 10,
  podiumGold: 3,
  podiumSilver: 2,
  podiumBronze: 1,
}

// engine, n, place -> [placePts, deBonus, podiumBonus, final] at multiplier 1.
const GOLDEN: [string, number, number, [number, number, number, number]][] = [
  [CLASSIC_ENGINE, 1, 1, [50.0, 0.0, 9.0, 59.0]],
  [CLASSIC_ENGINE, 2, 1, [50.0, 10.0, 11.34, 71.34]],
  [CLASSIC_ENGINE, 2, 2, [1.0, 0.0, 7.56, 8.56]],
  [CLASSIC_ENGINE, 8, 3, [24.11, 10.0, 6.0, 40.11]],
  [CLASSIC_ENGINE, 16, 1, [50.0, 40.0, 22.68, 112.68]],
  [CLASSIC_ENGINE, 24, 1, [50.0, 50.0, 25.96, 125.96]],
  [CLASSIC_ENGINE, 31, 17, [9.57, 0.0, 0.0, 9.57]],
  [CLASSIC_ENGINE, 32, 1, [50.0, 50.0, 28.57, 128.57]],
  [CLASSIC_ENGINE, 107, 34, [13.02, 10.0, 0.0, 23.02]],
  [CLASSIC_ENGINE, 1000, 500, [5.92, 10.0, 0.0, 15.92]],
  [FIELD_SCALED_ENGINE, 1, 1, [10.0, 0.0, 9.0, 19.0]],
  [FIELD_SCALED_ENGINE, 2, 1, [10.0, 10.0, 11.34, 31.34]],
  [FIELD_SCALED_ENGINE, 2, 2, [1.0, 0.0, 7.56, 8.56]],
  [FIELD_SCALED_ENGINE, 8, 3, [14.68, 10.0, 6.0, 30.68]],
  [FIELD_SCALED_ENGINE, 16, 1, [40.0, 40.0, 22.68, 102.68]],
  [FIELD_SCALED_ENGINE, 24, 1, [45.85, 50.0, 25.96, 121.81]],
  [FIELD_SCALED_ENGINE, 31, 17, [9.49, 0.0, 0.0, 9.49]],
  [FIELD_SCALED_ENGINE, 32, 1, [50.0, 50.0, 28.57, 128.57]],
  [FIELD_SCALED_ENGINE, 107, 34, [13.02, 10.0, 0.0, 23.02]],
  [FIELD_SCALED_ENGINE, 1000, 500, [5.92, 10.0, 0.0, 15.92]],
]

describe('SS26.PARITY — the shared module reproduces the SQL engines exactly', () => {
  for (const [engine, n, place, [pp, de, pod, final]] of GOLDEN) {
    it(`${engine} at N=${n} place=${place}`, () => {
      const c = scoreComponents(PARAMS, engine, n, place, 1)
      expect(c.placePoints).toBe(pp)
      expect(c.deBonus).toBe(de)
      expect(c.podiumBonus).toBe(pod)
      expect(c.finalScore).toBe(final)
    })
  }
})

describe('SS26.CALC — the two engines differ only below N = 32', () => {
  // 10 * log2(32) = 50, so the field-scaled base reaches mp_value at 32 and the
  // min() clamps it there for every larger field.
  it('agrees with the classic engine for every N >= 32', () => {
    for (const n of [32, 33, 64, 107, 256, 1000]) {
      for (const place of [1, 2, 3, Math.ceil(n / 2), n]) {
        const classic = scoreComponents(PARAMS, CLASSIC_ENGINE, n, place, 1)
        const scaled = scoreComponents(PARAMS, FIELD_SCALED_ENGINE, n, place, 1)
        expect(scaled.finalScore, `N=${n} place=${place}`).toBe(classic.finalScore)
      }
    }
  })

  it('differs below N = 32, and the walkover is the largest gap', () => {
    const classic = scoreComponents(PARAMS, CLASSIC_ENGINE, 1, 1, 1)
    const scaled = scoreComponents(PARAMS, FIELD_SCALED_ENGINE, 1, 1, 1)
    expect(classic.finalScore).toBe(59.0)
    expect(scaled.finalScore).toBe(19.0)
  })
})

describe('SS26.CALC — the final score rounds once, from unrounded components', () => {
  // SQL: ROUND((place + de + podium) * multiplier, 2), where the components
  // inside the sum are NOT the rounded ones. Summing rounded components first
  // would drift, so the module must round in the same order.
  it('matches SQL at a non-unit multiplier', () => {
    expect(scoreComponents(PARAMS, FIELD_SCALED_ENGINE, 8, 3, 1.5).finalScore).toBe(46.02)
    expect(scoreComponents(PARAMS, FIELD_SCALED_ENGINE, 8, 3, 0.75).finalScore).toBe(23.01)
    expect(scoreComponents(PARAMS, FIELD_SCALED_ENGINE, 8, 3, 2.0).finalScore).toBe(61.36)
  })
})

describe('SS26.CALC — invalid input is rejected, never scored as zero', () => {
  // §04, decided 19 September 2026: a place greater than the field is corrupt
  // data, and zero is the one value that hides it — it sorts to the bottom and
  // reads as an ordinary weak result. SQL raises; this module throws.
  it('throws when place exceeds the field', () => {
    expect(() => scoreComponents(PARAMS, FIELD_SCALED_ENGINE, 8, 9, 1)).toThrow(
      /exceeds the field/i,
    )
  })

  it('throws on a place below 1 and on an empty field', () => {
    expect(() => scoreComponents(PARAMS, FIELD_SCALED_ENGINE, 8, 0, 1)).toThrow()
    expect(() => scoreComponents(PARAMS, FIELD_SCALED_ENGINE, 0, 1, 1)).toThrow()
  })

  it('does not award a podium bonus for a place outside the field', () => {
    // The SQL writer had no place>N guard on num_podium_bonus, so N=2 place=3
    // awarded a bronze bonus for a place that cannot exist. Rejecting the input
    // closes that branch here too, rather than reproducing the leak.
    expect(() => scoreComponents(PARAMS, FIELD_SCALED_ENGINE, 2, 3, 1)).toThrow()
  })
})

describe('SS26.CALC — an unknown engine fails closed', () => {
  it('throws rather than silently choosing a default', () => {
    expect(() => scoreComponents(PARAMS, 'SPWS_NOT_AN_ENGINE_V9', 8, 1, 1)).toThrow(
      /unknown scoring engine/i,
    )
  })
})
