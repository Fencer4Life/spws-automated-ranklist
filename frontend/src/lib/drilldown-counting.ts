// Which drilldown results count in the ranking, and the totals they make.
//
// Moved unchanged out of DrilldownModal.svelte so the tables, the bars, the ★
// markers and the printed totals read one set (plan:
// doc/plans/drilldown-points-order-and-uncounted-2026-10-01.html). The ranking
// SQL stays the authority; tests/drilldown-counting.test.ts (DD.PARITY.01)
// pins this to fn_ranking_full and fn_ranking_ppw on a LOCAL snapshot.

import type { RankingRules, ScoreRow } from './types'

// SS26.UI (design step 7, ADR-101): split for bar-color provenance — both
// groups still combine into the one EVF+ total/pool (INTL_TYPES is their
// union), matching §06: "Color communicates provenance only; it does not
// create separate orange or red subtotals."
export const EVF_TYPES = ['PEW', 'MEW', 'MSW', 'PSW'] as const
export const PZSZ_TYPES = ['PPS', 'MPS'] as const
export const INTL_TYPES = [...EVF_TYPES, ...PZSZ_TYPES] as const

export const isDomestic = (type: string): boolean => type === 'PPW' || type === 'MPW'
export const isEvf = (type: string): boolean => (EVF_TYPES as readonly string[]).includes(type)
export const isPzsz = (type: string): boolean => (PZSZ_TYPES as readonly string[]).includes(type)
export const isInternational = (type: string): boolean => (INTL_TYPES as readonly string[]).includes(type)

export type CountableScore = Pick<
  ScoreRow,
  'id_result' | 'enum_type' | 'num_final_score' | 'dt_tournament' | 'bool_carried_over'
>

/** Points, highest first; equal points put the newer result first. */
export function byPointsDesc(a: CountableScore, b: CountableScore): number {
  const d = (b.num_final_score ?? 0) - (a.num_final_score ?? 0)
  if (d !== 0) return d
  return (b.dt_tournament ?? '').localeCompare(a.dt_tournament ?? '')
}

/** The pre-JSONB best counts, used only while a season has no bucket rules. */
export interface CountFallback {
  ppwBestCount: number
  pewBestCount: number
}

export interface CountedResults {
  /** id_result of every result that counts. */
  ids: Set<number>
  ppwTotal: number
  mpwTotal: number
  domesticTotal: number
  internationalTotal: number
  grandTotal: number
}

const round1 = (x: number): number => Math.round(x * 10) / 10
const sumPts = (rows: CountableScore[]): number => rows.reduce((acc, s) => acc + (s.num_final_score ?? 0), 0)

export function countResults(
  scores: CountableScore[],
  rules: RankingRules | null,
  fallback: CountFallback | null,
): CountedResults {
  const bestK = rules
    ? (rules.domestic.find((b) => b.types.includes('PPW'))?.best ?? 4)
    : (fallback?.ppwBestCount ?? 4)
  const bestJ = rules
    ? (rules.international.find((b) => b.types.some(isInternational))?.best ?? 3)
    : (fallback?.pewBestCount ?? 3)

  const ppwBest = scores.filter((s) => s.enum_type === 'PPW').sort(byPointsDesc).slice(0, bestK)
  const mpw = scores.find((s) => s.enum_type === 'MPW')
  const ppwTotal = round1(sumPts(ppwBest))
  const mpwTotal = round1(mpw?.num_final_score ?? 0)

  let intlCounted: CountableScore[]
  let internationalTotal: number
  if (rules) {
    intlCounted = scores.filter((s) => isInternational(s.enum_type)).sort(byPointsDesc).slice(0, bestJ)
    internationalTotal = round1(sumPts(intlCounted))
  } else {
    // Legacy: best-J PEW plus the MEW; no other international type counts.
    const pewBest = scores.filter((s) => s.enum_type === 'PEW').sort(byPointsDesc).slice(0, bestJ)
    const mew = scores.find((s) => s.enum_type === 'MEW')
    intlCounted = mew ? [...pewBest, mew] : pewBest
    internationalTotal = round1(round1(sumPts(pewBest)) + round1(mew?.num_final_score ?? 0))
  }

  const domesticTotal = round1(ppwTotal + mpwTotal)
  const ids = new Set([...ppwBest, ...(mpw ? [mpw] : []), ...intlCounted].map((s) => s.id_result))
  return {
    ids,
    ppwTotal,
    mpwTotal,
    domesticTotal,
    internationalTotal,
    grandTotal: round1(domesticTotal + internationalTotal),
  }
}

// <EVENT>-V<n>-<gender>-<weapon>-<YYYY>-<YYYY>, the code every tournament carries.
const CODE_RE = /^([A-Za-z0-9]+)-V[0-4]-[MFK]-(?:EPEE|FOIL|SABRE)-(\d{4})-(\d{4})$/i
// A name that only repeats the sub-ranking ("V3 M EPEE") says nothing new.
const GENERIC_NAME_RE = /^V[0-4]\s+[MFK]\s+(?:EPEE|FOIL|SABRE)$/i

/**
 * The row label: the tournament's own name when it has a real one (EVF
 * circuit rows: "EVF Grand Prix 4"), otherwise event and season from the
 * code ("PPW1 · 2026/27"). A code that does not parse is shown as it is.
 */
export function shortTournamentName(s: Pick<ScoreRow, 'txt_tournament_code' | 'txt_tournament_name'>): string {
  const name = (s.txt_tournament_name ?? '').trim()
  if (name && !GENERIC_NAME_RE.test(name)) return name
  const m = CODE_RE.exec(s.txt_tournament_code)
  if (!m) return s.txt_tournament_code
  return `${m[1]} · ${m[2]}/${m[3].slice(2)}`
}

/** ADR-104 §6: the premium and cap reduction of an EVF_JOINED result, else null. */
export function joinedBracketDetails(
  s: Partial<Pick<ScoreRow, 'enum_score_method' | 'num_joined_premium' | 'num_cap_reduction'>>,
): { premium: number; cap: number } | null {
  if (s.enum_score_method !== 'EVF_JOINED') return null
  return { premium: Math.max(0, Number(s.num_joined_premium ?? 0)), cap: Math.max(0, Number(s.num_cap_reduction ?? 0)) }
}
