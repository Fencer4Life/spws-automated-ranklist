// Drilldown counting (plan: doc/plans/drilldown-points-order-and-uncounted-2026-10-01.html).
// The drilldown greys the results that do not count, so the set it greys has
// to be the set the ranking SQL sums. The counting moved out of
// DrilldownModal.svelte unchanged; DD.PARITY.01 pins it to fn_ranking_full and
// fn_ranking_ppw on a LOCAL snapshot of SPWS-2026-2027 (228 fencers).

import { describe, it, expect } from 'vitest'
import {
  byPointsDesc,
  countResults,
  joinedBracketDetails,
  shortTournamentName,
  type CountableScore,
} from '../src/lib/drilldown-counting'
import type { RankingRules } from '../src/lib/types'
import parity from './fixtures/drilldown-parity-2026-2027.json'

const RULES_2026_27 = parity.rules as RankingRules

const row = (
  id: number,
  type: string,
  pts: number,
  extra: Partial<CountableScore> = {},
): CountableScore => ({
  id_result: id,
  enum_type: type as CountableScore['enum_type'],
  num_final_score: pts,
  dt_tournament: '2026-01-01',
  bool_carried_over: false,
  ...extra,
})

// KRZEMIŃSKI Mariusz, épée men V3, SPWS-2026-2027 rolling, LOCAL 2026-10-01.
const KRZ: CountableScore[] = [
  row(1137, 'MPW', 131.27, { dt_tournament: '2026-06-20', bool_carried_over: true }),
  row(3601, 'PPW', 108.72, { dt_tournament: '2026-09-26' }),
  row(2447, 'PPW', 98.0, { dt_tournament: '2025-12-13', bool_carried_over: true }),
  row(2639, 'PPW', 97.22, { dt_tournament: '2026-02-21', bool_carried_over: true }),
  row(2789, 'PPW', 96.35, { dt_tournament: '2026-04-11', bool_carried_over: true }),
  row(814, 'MSW', 54.03, { dt_tournament: '2025-11-12', bool_carried_over: true }),
  row(1473, 'PEW', 51.71, { dt_tournament: '2026-03-07', bool_carried_over: true }),
  row(1681, 'PEW', 40.11, { dt_tournament: '2026-03-28', bool_carried_over: true }),
  row(1566, 'PEW', 37.74, { dt_tournament: '2026-01-10', bool_carried_over: true }),
  row(2228, 'PPW', 17.79, { dt_tournament: '2025-10-25', bool_carried_over: true }),
]

describe('byPointsDesc', () => {
  it('DD.SORT.01 — orders by points, highest first', () => {
    const order = [...KRZ].filter((s) => ['PPW', 'MPW'].includes(s.enum_type)).sort(byPointsDesc)
    expect(order.map((s) => s.num_final_score)).toEqual([131.27, 108.72, 98.0, 97.22, 96.35, 17.79])
  })

  it('DD.SORT.03 — equal points put the newer result first', () => {
    const older = row(1, 'PPW', 50, { dt_tournament: '2025-10-01' })
    const newer = row(2, 'PPW', 50, { dt_tournament: '2026-03-01' })
    expect([older, newer].sort(byPointsDesc).map((s) => s.id_result)).toEqual([2, 1])
  })
})

describe('countResults', () => {
  it('KRZEMIŃSKI: best 2 PPW + the MPW, and all four EVF+ results, count', () => {
    const c = countResults(KRZ, RULES_2026_27, null)
    expect([...c.ids].sort((a, b) => a - b)).toEqual([814, 1137, 1473, 1566, 1681, 2447, 3601])
    expect(c.domesticTotal).toBe(338)
    expect(c.internationalTotal).toBe(183.6)
    expect(c.grandTotal).toBe(521.6)
    expect(c.ppwTotal).toBe(206.7)
    expect(c.mpwTotal).toBe(131.3)
  })

  it('DD.GREY.02 — EVF+ results beyond the best five do not count', () => {
    const scores = [1, 2, 3, 4, 5, 6].map((i) => row(i, 'PEW', 100 - i))
    const c = countResults(scores, RULES_2026_27, null)
    expect(c.ids.has(6)).toBe(false)
    expect([1, 2, 3, 4, 5].every((i) => c.ids.has(i))).toBe(true)
  })

  it('DD.GREY.07 — without bucket rules the older PEW best-J + MEW counting decides', () => {
    const scores = [
      row(1, 'PEW', 90), row(2, 'PEW', 80), row(3, 'PEW', 70), row(4, 'PEW', 60),
      row(5, 'MEW', 20), row(6, 'MSW', 50),
    ]
    const c = countResults(scores, null, { ppwBestCount: 4, pewBestCount: 3 })
    expect([...c.ids].sort((a, b) => a - b)).toEqual([1, 2, 3, 5])
    expect(c.internationalTotal).toBe(260)
  })

  it('DD.PARITY.01 — the counted set sums to fn_ranking_full and fn_ranking_ppw on LOCAL', () => {
    const misses: string[] = []
    for (const f of parity.fencers) {
      const scores = f.scores.map(([id, type, pts, carried]) =>
        row(id as number, type as string, pts as number, { bool_carried_over: carried as boolean }),
      )
      const c = countResults(scores, RULES_2026_27, null)
      const sum = (pred: (s: CountableScore) => boolean) =>
        scores.filter((s) => c.ids.has(s.id_result) && pred(s)).reduce((a, s) => a + (s.num_final_score ?? 0), 0)
      const dom = sum((s) => s.enum_type === 'PPW' || s.enum_type === 'MPW')
      const intl = sum((s) => s.enum_type !== 'PPW' && s.enum_type !== 'MPW')
      const near = (a: number, b: number, tol: number) => Math.abs(a - b) <= tol
      if (!near(dom, f.spws, 0.011)) misses.push(`${f.key} spws ${dom} vs ${f.spws}`)
      if (!near(intl, f.evf, 0.011)) misses.push(`${f.key} evf ${intl} vs ${f.evf}`)
      if (f.ppw != null && !near(sum((s) => s.enum_type === 'PPW'), f.ppw, 0.011)) misses.push(`${f.key} ppw`)
      if (f.mpw != null && !near(sum((s) => s.enum_type === 'MPW'), f.mpw, 0.011)) misses.push(`${f.key} mpw`)
      // The printed totals are the same numbers at one decimal.
      if (!near(c.domesticTotal, f.spws, 0.1)) misses.push(`${f.key} printed spws ${c.domesticTotal}`)
      if (!near(c.internationalTotal, f.evf, 0.1)) misses.push(`${f.key} printed evf ${c.internationalTotal}`)
    }
    expect(parity.fencers.length).toBe(228)
    expect(misses).toEqual([])
  })
})

describe('shortTournamentName (B1)', () => {
  it('DD.NAME.01 — event and season from the code; a PEW row by its own name', () => {
    expect(shortTournamentName({ txt_tournament_code: 'PPW1-V3-M-EPEE-2026-2027', txt_tournament_name: 'V3 M EPEE' })).toBe('PPW1 · 2026/27')
    expect(shortTournamentName({ txt_tournament_code: 'MPW-V3-M-EPEE-2025-2026', txt_tournament_name: 'V3 M EPEE' })).toBe('MPW · 2025/26')
    expect(shortTournamentName({ txt_tournament_code: 'IMSW-V3-M-EPEE-2025-2026', txt_tournament_name: 'V3 M EPEE' })).toBe('IMSW · 2025/26')
    expect(shortTournamentName({ txt_tournament_code: 'PPW2-V3-M-EPEE-2025-2026', txt_tournament_name: null })).toBe('PPW2 · 2025/26')
    expect(shortTournamentName({ txt_tournament_code: 'PEW7ef-V3-M-EPEE-2025-2026', txt_tournament_name: 'V3 M EPEE' })).toBe('PEW7ef · 2025/26')
    expect(shortTournamentName({ txt_tournament_code: 'PEW4efs-V3-M-EPEE-2025-2026', txt_tournament_name: 'EVF Grand Prix 4' })).toBe('EVF Grand Prix 4')
  })

  it('DD.NAME.02 — a code that does not parse is shown as it is', () => {
    expect(shortTournamentName({ txt_tournament_code: 'PPW-07', txt_tournament_name: 'V2 M EPEE' })).toBe('PPW-07')
    expect(shortTournamentName({ txt_tournament_code: 'PPW-07', txt_tournament_name: '' })).toBe('PPW-07')
  })
})

describe('joinedBracketDetails (B2)', () => {
  it('DD.JOIN.01 — EVF_JOINED rows carry their premium and cap reduction; others none', () => {
    expect(joinedBracketDetails({ enum_score_method: 'EVF_JOINED', num_joined_premium: 6.6, num_cap_reduction: 0 })).toEqual({ premium: 6.6, cap: 0 })
    expect(joinedBracketDetails({ enum_score_method: 'EVF_JOINED', num_joined_premium: 4.04, num_cap_reduction: 1.25 })).toEqual({ premium: 4.04, cap: 1.25 })
    expect(joinedBracketDetails({ enum_score_method: 'EVF_CLASSIC', num_joined_premium: -1, num_cap_reduction: -1 })).toBeNull()
    expect(joinedBracketDetails({})).toBeNull()
  })
})
