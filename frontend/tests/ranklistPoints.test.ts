// Plan tests: RT.ROUND.01–05 (ADR-114) — the main ranklist's points display.
// See doc/plans/ranklist-whole-points-2026-10-18.html §6.
// Whole points everywhere; in the column that orders the list, a run of
// neighbours showing the same whole number whose exact totals differ shows
// its decimal (one, or two when one would still look equal). Exact ties stay whole.

import { describe, it, expect } from 'vitest'
import { wholePoints, closeCallDecimals, splitPoints } from '../src/lib/ranklist-points'

describe('ranklist points (ADR-114)', () => {
  it('RT.ROUND.01 — whole points, a half rounding up; an empty value is a dash', () => {
    expect(wholePoints(96.35)).toBe('96')
    expect(wholePoints(22.5)).toBe('23')
    expect(wholePoints(22.49)).toBe('22')
    expect(wholePoints(0)).toBe('0')
    expect(wholePoints(null)).toBe('—')
  })

  it('RT.ROUND.02 — a close call: neighbours with the same whole number and different totals get one decimal', () => {
    expect(closeCallDecimals([22.96, 22.09, 21.51, 20.44])).toEqual([0, 1, 1, 0])
    expect(splitPoints(22.09, 1)).toEqual({ whole: '22', frac: '1' })
    expect(splitPoints(21.51, 1)).toEqual({ whole: '21', frac: '5' })
  })

  it('RT.ROUND.03 — an exact tie stays whole', () => {
    expect(closeCallDecimals([22, 22])).toEqual([0, 0])
    expect(closeCallDecimals([30, 22, 22, 10])).toEqual([0, 0, 0, 0])
  })

  it('RT.ROUND.04 — two decimals when one would still look equal', () => {
    expect(closeCallDecimals([22.14, 22.12])).toEqual([2, 2])
    // PROD, épée women V0 2026/27 as the site shows it (rolling), #5 and #6
    expect(closeCallDecimals([71.34, 71.31])).toEqual([2, 2])
    expect(splitPoints(22.14, 2)).toEqual({ whole: '22', frac: '14' })
    expect(splitPoints(22.12, 2)).toEqual({ whole: '22', frac: '12' })
    expect(splitPoints(22.05, 2)).toEqual({ whole: '22', frac: '05' })
  })

  it('RT.ROUND.05 — a run that differs shows the decimal on every row, the tie inside too', () => {
    expect(closeCallDecimals([22.4, 22, 22, 21.6])).toEqual([1, 1, 1, 1])
    expect(splitPoints(22, 1)).toEqual({ whole: '22', frac: '0' })
    expect(closeCallDecimals([])).toEqual([])
    expect(closeCallDecimals([172.6])).toEqual([0])
  })
})
