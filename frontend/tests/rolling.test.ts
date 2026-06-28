// ADR-018/021 + ADR-077 — rolling carry-over gate for the ranklist view.
// Regression: a future (non-active) season must show rolling carry-over, not an
// empty list (the promoted SPWS-2026-2027 skeleton case).

import { describe, it, expect } from 'vitest'
import { shouldUseRolling } from '../src/lib/rolling'

const TODAY = '2026-06-28'

describe('shouldUseRolling (ADR-077 rolling gate)', () => {
  it('active season → rolling on', () => {
    expect(shouldUseRolling({ bool_active: true, dt_end: '2026-07-15' }, TODAY)).toBe(true)
  })

  it('future season (not active, ends after today) → rolling on (carry-over preview)', () => {
    expect(shouldUseRolling({ bool_active: false, dt_end: '2027-07-15' }, TODAY)).toBe(true)
  })

  it('past season (ended before today) → rolling OFF (show finals)', () => {
    expect(shouldUseRolling({ bool_active: false, dt_end: '2025-07-15' }, TODAY)).toBe(false)
  })

  it('season ending exactly today → rolling on', () => {
    expect(shouldUseRolling({ bool_active: false, dt_end: TODAY }, TODAY)).toBe(true)
  })

  it('null / undefined season → rolling off', () => {
    expect(shouldUseRolling(null, TODAY)).toBe(false)
    expect(shouldUseRolling(undefined, TODAY)).toBe(false)
  })
})
