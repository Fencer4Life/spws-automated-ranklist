// Plan-test-ID 5.3: api.regenStagingReport
//
// LOCAL: VITE_DEPLOY_ENV unset/'LOCAL' — function is a no-op (returns
// {skipped: 'local'} without any network call). Operator continues to
// rerun phase5_report from shell after triage. ADR-061.
//
// CERT/PROD: VITE_DEPLOY_ENV='CERT' or 'PROD' — function calls the
// dispatch-workflow edge fn with workflow='regen-report.yml' + inputs.

import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock supabase client BEFORE importing api.
vi.mock('../src/lib/api', async (importOriginal) => {
  const mod = await importOriginal<typeof import('../src/lib/api')>()
  return mod
})

describe('regenStagingReport', () => {
  let mockInvoke: ReturnType<typeof vi.fn>

  beforeEach(() => {
    mockInvoke = vi.fn()
    vi.resetModules()
  })

  // 5.3.1 — LOCAL is a no-op
  it('LOCAL (VITE_DEPLOY_ENV unset) → no network call, returns skipped', async () => {
    vi.stubEnv('VITE_DEPLOY_ENV', '')
    const { regenStagingReport, _setClientForTesting } = await import('../src/lib/api')
    _setClientForTesting?.({ functions: { invoke: mockInvoke } } as any)
    const out = await regenStagingReport('EVENT-A-2024-2025')
    expect(mockInvoke).not.toHaveBeenCalled()
    expect(out).toEqual({ skipped: 'local' })
  })

  // 5.3.2 — CERT calls dispatch-workflow with regen-report.yml
  it('CERT → invokes dispatch-workflow with regen-report.yml', async () => {
    vi.stubEnv('VITE_DEPLOY_ENV', 'CERT')
    mockInvoke.mockResolvedValue({ data: { ok: true }, error: null })
    const { regenStagingReport, _setClientForTesting } = await import('../src/lib/api')
    _setClientForTesting?.({ functions: { invoke: mockInvoke } } as any)
    await regenStagingReport('EVENT-A-2024-2025')
    expect(mockInvoke).toHaveBeenCalledWith('dispatch-workflow', {
      body: {
        workflow: 'regen-report.yml',
        inputs: { event_code: 'EVENT-A-2024-2025', target: 'cert' },
      },
    })
  })

  // 5.3.3 — PROD passes target=prod
  it('PROD → invokes dispatch-workflow with target=prod', async () => {
    vi.stubEnv('VITE_DEPLOY_ENV', 'PROD')
    mockInvoke.mockResolvedValue({ data: { ok: true }, error: null })
    const { regenStagingReport, _setClientForTesting } = await import('../src/lib/api')
    _setClientForTesting?.({ functions: { invoke: mockInvoke } } as any)
    await regenStagingReport('EVENT-B')
    expect(mockInvoke).toHaveBeenCalledWith('dispatch-workflow', expect.objectContaining({
      body: expect.objectContaining({ inputs: expect.objectContaining({ target: 'prod' }) }),
    }))
  })

  // 5.3.4 — error from invoke surfaces
  it('error from invoke is surfaced as thrown', async () => {
    vi.stubEnv('VITE_DEPLOY_ENV', 'CERT')
    mockInvoke.mockResolvedValue({ data: null, error: { message: 'denied' } })
    const { regenStagingReport, _setClientForTesting } = await import('../src/lib/api')
    _setClientForTesting?.({ functions: { invoke: mockInvoke } } as any)
    await expect(regenStagingReport('X')).rejects.toThrow(/denied/)
  })
})

// 5.3.5 — the alias screen's step line says what has happened: GitHub accepted the
// start. The report is rendered and sent by regen-report.yml afterwards, and that run
// can still fail, so "regenerated · sent to Telegram" claimed too much.
describe('regenStagingReportStep', () => {
  it('a dispatched regen reads as started, with the report still to come', async () => {
    const { regenStagingReportStep } = await import('../src/lib/api')
    const line = regenStagingReportStep('PPW1-2026-2027', { ok: true })
    expect(line).toBe('✓ PPW1-2026-2027/full.md regeneration started · the report arrives on Telegram')
    expect(line).not.toMatch(/regenerated|sent to Telegram/)
  })

  it('LOCAL keeps its skip line', async () => {
    const { regenStagingReportStep } = await import('../src/lib/api')
    expect(regenStagingReportStep('X', { skipped: 'local' })).toBe(
      'ℹ X/full.md regen skipped on LOCAL (rerun phase5_report from shell)',
    )
  })
})
