// =============================================================================
// SE27.UI / SS26.CALC — the shared scoring formula module
// =============================================================================
// ADR-102 (one browser-side module, generated into the published pages) and
// ADR-104 (the 2026/2027 engine, SPWS_EVF_JOINED_V1_2026_2027, which replaced
// the place-and-medal engine of ADR-103 before it scored a result).
//
// WHY THIS MODULE EXISTS
// -----------------------------------------------------------------------------
// The scoring-table annex renders up to 64 x 64 cells and re-renders on every
// coefficient change, so per-cell and whole-grid score RPCs were rejected. The
// formula therefore lives in exactly two places — here and the SQL strategies —
// and these tests are the pin between them.
//
// EVERY EXPECTATION BELOW WAS DERIVED FROM THE DATABASE, NOT GUESSED
// -----------------------------------------------------------------------------
// Produced by calling fn_score_by_engine against the local stack with the
// 2026/2027 EVF settings (mp_value 50, de_round 10, podium 3/2/1) and rounding
// exactly as fn_calc_tournament_scores does: each component to two decimals,
// and the final once, from the unrounded sum times the coefficient. If a value
// here disagrees with SQL, that is a parity defect and this file is the alarm.
//
// =============================================================================

import { describe, it, expect } from 'vitest'
import {
  CLASSIC_ENGINE,
  JOINED,
  JOINED_ENGINE,
  joinedAlternatives,
  joinedMethod,
  scoreBracket,
  scoreComponents,
  type ScoringParams,
} from '../src/lib/scoring'

// The 2026/2027 stored configuration, as fn_public_scoring_params publishes the
// PPW row. The engine code here is data; scoreComponents takes the engine to
// run as its own argument.
const PARAMS: ScoringParams = {
  engineCode: JOINED_ENGINE,
  engineLabel: 'SPWS — punkty EVF i premia w stawce łączonej (od sezonu 2026/2027)',
  mpValue: 50,
  deRound: 10,
  podiumGold: 3,
  podiumSilver: 2,
  podiumBronze: 1,
}

// EVF classic: n, place -> [placePts, deBonus, podiumBonus, final] at 1.0.
// Unchanged from the 2025/2026 pin: the released strategy is immutable.
const CLASSIC_GOLDEN: [number, number, [number, number, number, number]][] = [
  [1, 1, [50.0, 0.0, 9.0, 59.0]],
  [2, 1, [50.0, 10.0, 11.34, 71.34]],
  [2, 2, [1.0, 0.0, 7.56, 8.56]],
  [8, 3, [24.11, 10.0, 6.0, 40.11]],
  [16, 1, [50.0, 40.0, 22.68, 112.68]],
  [24, 1, [50.0, 50.0, 25.96, 125.96]],
  [31, 17, [9.57, 0.0, 0.0, 9.57]],
  [32, 1, [50.0, 50.0, 28.57, 128.57]],
  [107, 34, [13.02, 10.0, 0.0, 23.02]],
  [1000, 500, [5.92, 10.0, 0.0, 15.92]],
]

describe('SS26.PARITY — EVF classic reproduces the released SQL strategy', () => {
  for (const [n, place, [pp, de, pod, final]] of CLASSIC_GOLDEN) {
    it(`${CLASSIC_ENGINE} at N=${n} place=${place}`, () => {
      const c = scoreComponents(PARAMS, CLASSIC_ENGINE, n, place, 1)
      expect(c.method).toBe('EVF_CLASSIC')
      expect(c.placePoints).toBe(pp)
      expect(c.deBonus).toBe(de)
      expect(c.podiumBonus).toBe(pod)
      expect(c.finalScore).toBe(final)
    })
  }
})

describe('SE27.UI — the final score rounds once, from unrounded components', () => {
  // SQL: ROUND(sum of the unrounded components x coefficient, 2). Summing the
  // rounded components first would drift, so the module rounds in that order.
  it('matches SQL at a non-unit coefficient', () => {
    // SQL: ROUND((place + DE + podium) x coefficient, 2) over
    // fn_score_evf_classic_v1_2025_2026(8, 3, 50, 10, 10, 3, 2, 1).
    const at = (r: number) => scoreComponents(PARAMS, CLASSIC_ENGINE, 8, 3, r).finalScore
    expect(at(1.5)).toBe(60.17)
    expect(at(2.0)).toBe(80.22)
    expect(at(1.2)).toBe(48.13)
    expect(at(0.75)).toBe(30.08)
  })
})

describe('SE27.UI — invalid input is rejected, never scored as zero', () => {
  // A place greater than the field is corrupt data, and zero is the one value
  // that hides it — it sorts to the bottom and reads as a weak result. SQL
  // raises with the same meaning; this module throws.
  for (const engine of [CLASSIC_ENGINE, JOINED_ENGINE]) {
    it(`${engine}: throws when place exceeds the field`, () => {
      expect(() => scoreComponents(PARAMS, engine, 8, 9, 1)).toThrow(/exceeds the field/i)
    })

    it(`${engine}: throws on a place below 1 and on an empty field`, () => {
      expect(() => scoreComponents(PARAMS, engine, 8, 0, 1)).toThrow(/invalid scoring input/i)
      expect(() => scoreComponents(PARAMS, engine, 0, 1, 1)).toThrow(/invalid scoring input/i)
    })
  }

  it('does not award a podium bonus for a place outside the field', () => {
    // N = 2 place 3 once earned a bronze bonus for a place that cannot exist.
    expect(() => scoreComponents(PARAMS, CLASSIC_ENGINE, 2, 3, 1)).toThrow()
  })
})

describe('SE27.UI — an unknown engine fails closed', () => {
  it('throws rather than silently choosing a default', () => {
    expect(() => scoreComponents(PARAMS, 'SPWS_NOT_AN_ENGINE_V9', 8, 1, 1)).toThrow(
      /unknown scoring engine/i,
    )
  })

  it('no longer knows the retired field-scaled engine', () => {
    expect(() => scoreComponents(PARAMS, 'SPWS_FIELD_SCALED_V1_2026_2027', 8, 1, 1)).toThrow(
      /unknown scoring engine/i,
    )
  })

  it('JB27.CLEAN.06 no longer knows the removed place-and-medal engine', () => {
    expect(() => scoreComponents(PARAMS, 'SPWS_PLACE_MEDAL_V1_2026_2027', 8, 1, 1)).toThrow(
      /unknown scoring engine/i,
    )
  })
})

// =============================================================================
// The joined-bracket engine, locked 30 September 2026
// =============================================================================
// doc/plans/joined-scoring-final-spec-2026-09-30.html. A bracket of 1-3 is a
// meeting (N - place + 1); a single-category bracket of 4+, and any bracket of
// 16+, is plain EVF; in a joined bracket of 4-15 the youngest category scores
// EVF and an older one max(EVF x (1 + 0.05 d), EVF + d), capped at the fencer
// directly ahead minus 1. The coefficient multiplies after the cap.
//
// NOT YET DERIVED FROM THE DATABASE, UNLIKE EVERYTHING ABOVE
// -----------------------------------------------------------------------------
// The SQL strategy does not exist yet. These brackets are Part C of the spec —
// real category line-ups from PPW and MPW 2023/24-2025/26 in illustrative
// finishing orders — and every value is the output of its reference
// implementation (A14). When the SQL engine lands, these expectations are
// re-derived from fn_score_by_engine, and they must come out the same.
// =============================================================================

// id, finishing order (category index per place: 0 = V0 ... 4 = V4),
// coefficient, and the final score of every place.
const PART_C: [string, string, number, number[]][] = [
  ['C2A', '343344', 1.0, [96.35, 65.04, 35.41, 22.09, 6.99, 2.0]],
  ['C2B', '22222222222323', 1.0, [111.69, 81.59, 56.83, 44.26, 30.12, 26.73, 23.87, 21.39, 9.2, 7.25, 5.48, 4.48, 2.38, 1.38]],
  ['C2C', '2242224', 1.2, [116.66, 76.83, 50.26, 30.11, 11.37, 5.86, 3.6]],
  ['C2D', '0101101111', 1.0, [109.39, 82.08, 53.08, 42.52, 27.04, 21.87, 19.59, 16.75, 4.24, 2.0]],
  ['C2E', '30', 1.0, [2.0, 1.0]],
  ['C3A', '1211113121', 1.0, [109.39, 82.08, 53.08, 40.5, 25.75, 21.87, 20.59, 15.75, 4.24, 1.0]],
  ['C3B', '121321323', 1.0, [108.72, 80.87, 51.74, 42.99, 25.31, 20.04, 18.6, 14.63, 3.0]],
  ['C3C', '2120221222222', 1.0, [122.28, 84.91, 61.67, 43.52, 32.18, 28.35, 23.97, 22.3, 10.02, 8.01, 6.19, 4.53, 3.0]],
  ['C3D', '024024', 1.0, [96.35, 68.14, 42.49, 22.09, 7.99, 5.0]],
  ['C3E', '304', 1.0, [3.0, 2.0, 1.0]],
  ['C4A', '1013141', 1.0, [102.08, 64.02, 39.98, 28.86, 10.47, 8.88, 2.0]],
  ['C4B', '010210312', 1.2, [130.46, 97.05, 62.09, 51.59, 30.38, 24.05, 22.85, 17.55, 3.6]],
  ['C4C', '2031', 1.0, [92.72, 45.02, 18.93, 2.0]],
  ['C4D', '22122203222222213', 1.0, [123.14, 93.44, 68.71, 56.02, 42.17, 39.01, 36.35, 34.04, 22.0, 20.18, 18.53, 17.02, 15.64, 14.36, 13.16, 12.05, 1.0]],
  ['C5A', '2102321424', 1.0, [120.33, 82.08, 53.08, 44.55, 29.61, 24.06, 19.59, 18.59, 5.24, 4.24]],
  ['C5B', '010234', 1.0, [96.35, 65.04, 35.41, 24.3, 8.99, 5.0]],
  ['C5C', '01203243', 1.2, [117.6, 82.74, 52.95, 32.8, 18.09, 11.73, 9.78, 4.8]],
]
const cats = (order: string) => [...order].map(Number)

describe('SE27.JOIN — the joined-bracket engine reproduces the spec, Part C', () => {
  for (const [id, order, coefficient, finals] of PART_C) {
    it(`${id}: ${order} at x ${coefficient}`, () => {
      const lines = scoreBracket(PARAMS, cats(order), coefficient)
      expect(lines.map(l => l.finalScore)).toEqual(finals)
      expect(lines.map(l => l.place)).toEqual(finals.map((_, i) => i + 1))
    })
  }

  it('marks the cap where it cuts: C2B places 12 and 14, C4B place 7', () => {
    const at = (order: string, coefficient: number) =>
      scoreBracket(PARAMS, cats(order), coefficient).flatMap(l => (l.capped ? [l.place] : []))
    expect(at('22222222222323', 1)).toEqual([12, 14])
    expect(at('010210312', 1.2)).toEqual([7])
    expect(at('343344', 1)).toEqual([])
  })

  it('shows the cap as the score ahead minus 1, before the coefficient', () => {
    const seventh = scoreBracket(PARAMS, cats('010210312'), 1.2)[6]
    expect(seventh.capAt).toBeCloseTo(20.04 - 1, 1)
    expect(seventh.uncappedTotal).toBeCloseTo(19.6, 2)
    expect(seventh.rawTotal).toBe(seventh.capAt)
  })
})

describe('SE27.JOIN — one place, without the cap', () => {
  it('pays 5% per step above 20 EVF points and d points below', () => {
    const second = scoreComponents(PARAMS, JOINED_ENGINE, 6, 2, 1, { categorySteps: 1 })
    expect(second.method).toBe('EVF_JOINED')
    expect(second.categorySteps).toBe(1)
    expect(second.finalScore).toBe(65.04)
    expect(second.premium).toBe(3.1)
    const last = scoreComponents(PARAMS, JOINED_ENGINE, 6, 6, 1, { categorySteps: 1 })
    expect(last.finalScore).toBe(2)
    expect(last.premium).toBe(1)
  })

  it('gives the two alternatives and the larger, equal at exactly 20 points', () => {
    expect(joinedAlternatives(20, 3)).toEqual({ byPercent: 23, byPoints: 23, candidate: 23 })
    expect(joinedAlternatives(40, 1).candidate).toBe(42)
    expect(joinedAlternatives(10, 4).candidate).toBe(14)
    expect(joinedAlternatives(61.95, 0)).toEqual({ byPercent: 61.95, byPoints: 61.95, candidate: 61.95 })
  })

  it('switches range at 3/4 and 15/16, and pays no premium at d = 0', () => {
    expect([3, 4, 15, 16].map(n => joinedMethod(n, 1))).toEqual([
      'TABLE',
      'EVF_JOINED',
      'EVF_JOINED',
      'EVF_CLASSIC',
    ])
    expect([4, 15].map(n => joinedMethod(n, 0))).toEqual(['EVF_CLASSIC', 'EVF_CLASSIC'])
    expect(JOINED).toEqual({ meetingUpTo: 3, premiumUpTo: 15, perStep: 0.05, capGap: 1 })
  })

  it('scores a meeting 3 / 2 / 1 whatever the categories', () => {
    for (const [n, place, points] of [
      [1, 1, 1],
      [2, 1, 2],
      [3, 2, 2],
      [3, 3, 1],
    ]) {
      const c = scoreComponents(PARAMS, JOINED_ENGINE, n, place, 1, { categorySteps: 4 })
      expect(c.method).toBe('TABLE')
      expect(c.finalScore).toBe(points)
    }
  })

  it('is exactly EVF classic from 4 fencers at d = 0, and from 16 at any d', () => {
    for (const [n, d] of [
      [4, 0],
      [8, 0],
      [15, 0],
      [16, 3],
      [64, 4],
      [300, 1],
    ]) {
      for (const place of [1, 2, 3, Math.ceil(n / 2), n]) {
        const classic = scoreComponents(PARAMS, CLASSIC_ENGINE, n, place, 1.2)
        const joined = scoreComponents(PARAMS, JOINED_ENGINE, n, place, 1.2, { categorySteps: d })
        expect(joined, `N=${n} place=${place} d=${d}`).toEqual(classic)
      }
    }
  })

  it('refuses a d that is not a category step from 0 to 4', () => {
    for (const d of [-1, 5, 1.5, Number.NaN]) {
      expect(() => scoreComponents(PARAMS, JOINED_ENGINE, 8, 2, 1, { categorySteps: d }), String(d)).toThrow(
        /invalid scoring input/i,
      )
    }
  })

  it('refuses a bracket without fencers or with a category outside V0-V4', () => {
    expect(() => scoreBracket(PARAMS, [], 1)).toThrow(/invalid scoring input/i)
    expect(() => scoreBracket(PARAMS, [0, 5, 1, 1], 1)).toThrow(/invalid scoring input/i)
    expect(() => scoreBracket(PARAMS, [0, 1, -1, 1], 1)).toThrow(/invalid scoring input/i)
  })
})

// Every distinct finishing order of a line-up that keeps each category's own
// order: the multiset permutations of the category indices.
function allOrders(sizes: Record<number, number>): number[][] {
  const out: number[][] = []
  const left = { ...sizes }
  const total = Object.values(sizes).reduce((a, b) => a + b, 0)
  const walk = (prefix: number[]) => {
    if (prefix.length === total) {
      out.push([...prefix])
      return
    }
    for (const key of Object.keys(left)) {
      const c = Number(key)
      if (left[c] === 0) continue
      left[c] -= 1
      prefix.push(c)
      walk(prefix)
      prefix.pop()
      left[c] += 1
    }
  }
  walk([])
  return out
}

describe('SE27.JOIN — the guarantees hold in every finishing order', () => {
  // Real line-ups from the spec: two small neighbours, a big youngest with a
  // small one, three small, the exception, and all five categories.
  const LINE_UPS: Record<number, number>[] = [
    { 3: 3, 4: 3 },
    { 3: 5, 4: 3 },
    { 2: 12, 3: 2 },
    { 1: 3, 2: 3, 3: 3 },
    { 0: 3, 1: 7 },
    { 1: 7, 2: 2, 3: 1 },
    { 0: 1, 1: 2, 2: 4, 3: 1, 4: 2 },
  ]
  const meeting = (size: number, m: number) => size - m + 1

  for (const sizes of LINE_UPS) {
    const label = Object.entries(sizes)
      .map(([c, k]) => `V${c} ${k}`)
      .join(' + ')
    it(`${label}: Z1 youngest is EVF, Z3/Z4 at least 1 below the fencer ahead, Z2 small categories never below their meeting`, () => {
      const youngest = Math.min(...Object.keys(sizes).map(Number))
      for (const order of allOrders(sizes)) {
        const lines = scoreBracket(PARAMS, order, 1)
        const n = order.length
        const seen: Record<number, number> = {}
        lines.forEach((line, i) => {
          seen[line.category] = (seen[line.category] ?? 0) + 1
          if (line.category === youngest) {
            const evf = scoreComponents(PARAMS, CLASSIC_ENGINE, n, i + 1, 1).rawTotal
            expect(line.rawTotal).toBeCloseTo(evf, 9)
          }
          if (i > 0) expect(lines[i - 1].rawTotal - line.rawTotal).toBeGreaterThanOrEqual(1 - 1e-9)
          if (sizes[line.category] <= 3) {
            expect(line.finalScore).toBeGreaterThanOrEqual(meeting(sizes[line.category], seen[line.category]))
          }
        })
      }
    })
  }

  it('never gives more points for a lower place: moving a fencer down never raises their score', () => {
    for (const order of allOrders({ 1: 3, 2: 3, 3: 3 })) {
      const lines = scoreBracket(PARAMS, order, 1)
      for (let i = 0; i + 1 < order.length; i += 1) {
        if (order[i] === order[i + 1]) continue
        const swapped = [...order]
        ;[swapped[i], swapped[i + 1]] = [swapped[i + 1], swapped[i]]
        const after = scoreBracket(PARAMS, swapped, 1)
        expect(after[i + 1].rawTotal, `${order.join('')} place ${i + 1}`).toBeLessThanOrEqual(lines[i].rawTotal + 1e-9)
      }
    }
  })
})
