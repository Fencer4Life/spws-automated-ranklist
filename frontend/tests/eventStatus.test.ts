import { describe, it, expect } from 'vitest'
import { getEventDisplayStatus } from '../src/lib/eventStatus'

const TODAY = '2026-04-20'
const YESTERDAY = '2026-04-19'
const TOMORROW = '2026-04-21'

describe('getEventDisplayStatus', () => {
  it('PLANNED with future dt_end → status_planned', () => {
    const out = getEventDisplayStatus('PLANNED', TOMORROW, null, TODAY)
    expect(out.labelKey).toBe('status_planned')
    expect(out.cssClass).toBe('status-planned')
  })

  it('PLANNED with past dt_end → status_awaiting_results (amber)', () => {
    const out = getEventDisplayStatus('PLANNED', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_awaiting_results')
    expect(out.cssClass).toBe('status-awaiting')
  })

  it('PLANNED with past dt_start and null dt_end falls back to dt_start', () => {
    const out = getEventDisplayStatus('PLANNED', null, YESTERDAY, TODAY)
    expect(out.labelKey).toBe('status_awaiting_results')
  })

  it('PLANNED with both dates null → status_planned (no awaiting flip)', () => {
    const out = getEventDisplayStatus('PLANNED', null, null, TODAY)
    expect(out.labelKey).toBe('status_planned')
    expect(out.cssClass).toBe('status-planned')
  })

  it('SCHEDULED → status_scheduled (never flips)', () => {
    const out = getEventDisplayStatus('SCHEDULED', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_scheduled')
    expect(out.cssClass).toBe('status-scheduled')
  })

  it('CHANGED → status_changed', () => {
    const out = getEventDisplayStatus('CHANGED', TOMORROW, null, TODAY)
    expect(out.labelKey).toBe('status_changed')
    expect(out.cssClass).toBe('status-changed')
  })

  it('IN_PROGRESS → status_in_progress (even if past)', () => {
    const out = getEventDisplayStatus('IN_PROGRESS', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_in_progress')
    expect(out.cssClass).toBe('status-inprogress')
  })

  it('COMPLETED → status_completed', () => {
    const out = getEventDisplayStatus('COMPLETED', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_completed')
    expect(out.cssClass).toBe('status-completed')
  })

  it('CANCELLED → status_cancelled', () => {
    const out = getEventDisplayStatus('CANCELLED', YESTERDAY, null, TODAY)
    expect(out.labelKey).toBe('status_cancelled')
    expect(out.cssClass).toBe('status-cancelled')
  })

  it('PLANNED with dt_end == today does NOT flip (same-day grace)', () => {
    const out = getEventDisplayStatus('PLANNED', TODAY, null, TODAY)
    expect(out.labelKey).toBe('status_planned')
  })

  it('default `today` arg resolves to current date without arg', () => {
    // Smoke: helper callable without explicit today
    const out = getEventDisplayStatus('COMPLETED', null)
    expect(out.labelKey).toBe('status_completed')
  })
})
