// Plan test IDs ES.1–ES.11 — see doc/adr/037-derived-display-status-awaiting-results.md.
// FR-94 in Project Specification RTM.

import { describe, it, expect } from 'vitest'
import { getEventDisplayStatus } from '../src/lib/eventStatus'

const TODAY = '2026-04-20'
const YESTERDAY = '2026-04-19'
const TOMORROW = '2026-04-21'

describe('getEventDisplayStatus (ADR-037)', () => {
  // ES.1 — PLANNED future date: no flip
  it('PLANNED with future dt_end → status_planned', () => {
    const out = getEventDisplayStatus('PLANNED', TOMORROW, null, TODAY)
    expect(out.labelKey).toBe('status_planned')
    expect(out.cssClass).toBe('status-planned')
  })

  // ES.2 — PLANNED past date: the "awaiting" flip (core behaviour)
  it('PLANNED with past dt_end → status_awaiting_results (amber)', () => {
    const out = getEventDisplayStatus('PLANNED', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_awaiting_results')
    expect(out.cssClass).toBe('status-awaiting')
  })

  // ES.3 — dt_end null, fall back to dt_start
  it('PLANNED with past dt_start and null dt_end falls back to dt_start', () => {
    const out = getEventDisplayStatus('PLANNED', null, YESTERDAY, TODAY)
    expect(out.labelKey).toBe('status_awaiting_results')
  })

  // ES.4 — both dates null: no flip, keep PLANNED
  it('PLANNED with both dates null → status_planned (no awaiting flip)', () => {
    const out = getEventDisplayStatus('PLANNED', null, null, TODAY)
    expect(out.labelKey).toBe('status_planned')
    expect(out.cssClass).toBe('status-planned')
  })

  // ES.5 — SCHEDULED never flips
  it('SCHEDULED → status_scheduled (never flips)', () => {
    const out = getEventDisplayStatus('SCHEDULED', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_scheduled')
    expect(out.cssClass).toBe('status-scheduled')
  })

  // ES.6 — CHANGED pass-through
  it('CHANGED → status_changed', () => {
    const out = getEventDisplayStatus('CHANGED', TOMORROW, null, TODAY)
    expect(out.labelKey).toBe('status_changed')
    expect(out.cssClass).toBe('status-changed')
  })

  // ES.7 — IN_PROGRESS never flips (even for past events)
  it('IN_PROGRESS → status_in_progress (even if past)', () => {
    const out = getEventDisplayStatus('IN_PROGRESS', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_in_progress')
    expect(out.cssClass).toBe('status-inprogress')
  })

  // ES.8 — COMPLETED pass-through
  it('COMPLETED → status_completed', () => {
    const out = getEventDisplayStatus('COMPLETED', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_completed')
    expect(out.cssClass).toBe('status-completed')
  })

  // ES.9 — CANCELLED pass-through
  it('CANCELLED → status_cancelled', () => {
    const out = getEventDisplayStatus('CANCELLED', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_cancelled')
    expect(out.cssClass).toBe('status-cancelled')
  })

  // ES.10 — same-day grace: dt_end == today still reads as PLANNED
  it('PLANNED with dt_end == today does NOT flip (same-day grace)', () => {
    const out = getEventDisplayStatus('PLANNED', TODAY, null, TODAY)
    expect(out.labelKey).toBe('status_planned')
  })

  // ES.11 — default `today` arg
  it('default `today` arg resolves to current date without arg', () => {
    const out = getEventDisplayStatus('COMPLETED', null)
    expect(out.labelKey).toBe('status_completed')
  })
})
