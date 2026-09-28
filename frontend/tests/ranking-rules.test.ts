// ADM27.RULES.12/13 — the checks behind the editor's bucket warnings and its
// save guard. They mirror fn_validate_ranking_rules_write
// (20260928000002), which refuses the same rules on the server; see
// doc/plans/admin-ui-ranking-buckets-and-skeletons-2026-09-28.html, Part 2 · A.

import { describe, it, expect } from 'vitest'
import { POOL_TYPES, rankingRulesProblems, sameRankingRules } from '../src/lib/ranking-rules'
import type { RankingRules } from '../src/lib/types'

const TARGET_2026_27: RankingRules = {
  domestic: [{ types: ['PPW'], best: 2 }, { types: ['MPW'], always: true }],
  international: [{ types: ['PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'], best: 5 }],
}

describe('ranking-rules — bucket checks mirrored from the server', () => {
  it('each pool admits only its own types', () => {
    expect(POOL_TYPES.domestic).toEqual(['PPW', 'MPW'])
    expect(POOL_TYPES.international).toEqual(['PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'])
  })

  it('the 2026/27 target has no problems', () => {
    expect(rankingRulesProblems(TARGET_2026_27)).toEqual([])
  })

  it('a domestic type in the international pool is out of its pool', () => {
    const rules: RankingRules = {
      domestic: [{ types: ['PPW'], best: 2 }],
      international: [{ types: ['PPW'], best: 1 }],
    }
    expect(rankingRulesProblems(rules)).toContainEqual({ pool: 'international', index: 0, problem: { kind: 'wrong_pool', type: 'PPW' } })
  })

  it('an international type in the domestic pool is out of its pool', () => {
    const rules: RankingRules = { domestic: [{ types: ['PEW'], best: 2 }], international: [] }
    expect(rankingRulesProblems(rules)).toEqual([{ pool: 'domestic', index: 0, problem: { kind: 'wrong_pool', type: 'PEW' } }])
  })

  it('a type in a second bucket is a duplicate, in either pool', () => {
    const rules: RankingRules = {
      domestic: [{ types: ['PPW'], best: 2 }, { types: ['PPW', 'MPW'], always: true }],
      international: [{ types: ['PEW'], best: 2 }, { types: ['PEW'], best: 3 }],
    }
    const problems = rankingRulesProblems(rules)
    expect(problems).toContainEqual({ pool: 'domestic', index: 1, problem: { kind: 'duplicate', type: 'PPW' } })
    expect(problems).toContainEqual({ pool: 'international', index: 1, problem: { kind: 'duplicate', type: 'PEW' } })
  })

  it('best below 1 is refused; both or neither of best and always is refused', () => {
    const rules: RankingRules = {
      domestic: [{ types: ['PPW'], best: 2, always: true }, { types: ['MPW'], best: 0 }],
      international: [{ types: ['PEW'] }],
    }
    const problems = rankingRulesProblems(rules)
    expect(problems).toContainEqual({ pool: 'domestic', index: 0, problem: { kind: 'best_or_always' } })
    expect(problems).toContainEqual({ pool: 'domestic', index: 1, problem: { kind: 'best_below_one', best: 0 } })
    expect(problems).toContainEqual({ pool: 'international', index: 0, problem: { kind: 'best_or_always' } })
  })

  it('always: false beside a best is a best bucket, as the editor writes it', () => {
    const rules: RankingRules = { domestic: [{ types: ['PPW'], best: 3, always: false }], international: [] }
    expect(rankingRulesProblems(rules)).toEqual([])
  })

  it('an empty bucket and an unknown type are refused', () => {
    const rules: RankingRules = { domestic: [{ types: [], best: 1 }], international: [{ types: ['XYZ'], best: 1 }] }
    const problems = rankingRulesProblems(rules)
    expect(problems).toContainEqual({ pool: 'domestic', index: 0, problem: { kind: 'no_types' } })
    expect(problems).toContainEqual({ pool: 'international', index: 0, problem: { kind: 'unknown_type', type: 'XYZ' } })
  })

  it('no rules at all has no problems', () => {
    expect(rankingRulesProblems(null)).toEqual([])
    expect(rankingRulesProblems({ domestic: [], international: [] })).toEqual([])
  })

  it('rules compare equal whatever the key order, as jsonb does on the server', () => {
    const a = { domestic: [{ types: ['PPW'], best: 2 }], international: [] } as RankingRules
    const b = JSON.parse('{"international":[],"domestic":[{"best":2,"types":["PPW"]}]}') as RankingRules
    expect(sameRankingRules(a, b)).toBe(true)
    expect(sameRankingRules(a, { ...a, domestic: [{ types: ['PPW'], best: 3 }] })).toBe(false)
    expect(sameRankingRules(null, undefined)).toBe(true)
  })
})
