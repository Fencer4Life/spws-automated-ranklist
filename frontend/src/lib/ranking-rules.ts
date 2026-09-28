// Ranking-bucket checks for the Admin scoring editor (ADM27).
//
// They mirror fn_validate_ranking_rules_write (migration 20260928000002), which
// refuses the same two-pool rules when fn_import_scoring_config is asked to
// CHANGE them. The server stops at the first fault; this module lists every
// fault so the editor can flag each bucket. Neither changes how stored rules
// are read: fn_ranking_rules_canonical still drops what it always dropped, so a
// season saved before these checks existed ranks exactly as before.

import type { RankingRules } from './types'

export type Pool = 'domestic' | 'international'

/** The types each pool admits, in picker order. */
export const POOL_TYPES: Record<Pool, readonly string[]> = {
  domestic: ['PPW', 'MPW'],
  international: ['PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'],
}

const KNOWN_TYPES = new Set([...POOL_TYPES.domestic, ...POOL_TYPES.international])

export type BucketProblem =
  | { kind: 'no_types' }
  | { kind: 'unknown_type', type: string }
  | { kind: 'wrong_pool', type: string }
  | { kind: 'duplicate', type: string }
  | { kind: 'best_or_always' }
  | { kind: 'best_below_one', best: unknown }

export interface RulesProblem {
  pool: Pool
  /** Zero-based position of the bucket within its pool. */
  index: number
  problem: BucketProblem
}

/** Every fault in the two-pool rules, in pool then bucket order. */
export function rankingRulesProblems(rules: RankingRules | null | undefined): RulesProblem[] {
  const problems: RulesProblem[] = []
  if (!rules) return problems
  const seen = new Set<string>()
  for (const pool of ['domestic', 'international'] as const) {
    ;(rules[pool] ?? []).forEach((bucket, index) => {
      const add = (problem: BucketProblem) => problems.push({ pool, index, problem })
      const types = Array.isArray(bucket.types) ? bucket.types : []
      if (types.length === 0) add({ kind: 'no_types' })
      for (const type of types) {
        if (!KNOWN_TYPES.has(type)) add({ kind: 'unknown_type', type })
        else if (!POOL_TYPES[pool].includes(type)) add({ kind: 'wrong_pool', type })
        else if (seen.has(type)) add({ kind: 'duplicate', type })
        seen.add(type)
      }
      const hasBest = bucket.best !== undefined && bucket.best !== null
      const hasAlways = bucket.always === true
      if (hasBest === hasAlways) add({ kind: 'best_or_always' })
      else if (hasBest && !(Number.isInteger(bucket.best) && (bucket.best as number) >= 1)) {
        add({ kind: 'best_below_one', best: bucket.best })
      }
    })
  }
  return problems
}

/** A JSON value with object keys sorted, so equality ignores key order. */
function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical)
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value as Record<string, unknown>)
        .sort()
        .map((key) => [key, canonical((value as Record<string, unknown>)[key])]),
    )
  }
  return value
}

/**
 * Whether two rule sets are the same JSON, as jsonb equality decides on the
 * server: key order is ignored, array order is not. null and undefined are
 * both "no rules".
 */
export function sameRankingRules(a: RankingRules | null | undefined, b: RankingRules | null | undefined): boolean {
  return JSON.stringify(canonical(a ?? null)) === JSON.stringify(canonical(b ?? null))
}
