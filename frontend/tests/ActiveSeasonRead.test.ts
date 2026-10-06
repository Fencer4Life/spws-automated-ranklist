// AS.UI.01 (ADR-031 amendment 2026-10-06): the active season is computed by the
// database on every read, so the page only reads it.
//
// App used to call fn_refresh_active_season on every mount, a write that moves
// the whole system's active season. Since 23 Jul 2026 (ADR-083) anon may not
// execute it, so every public page load on LOCAL, CERT and PROD logged a 401.
// Now tbl_season.bool_active is a computed field: fetchSeasons() reads it like
// a column, and nothing writes it. This test fakes only the Supabase client and
// keeps the real api.ts, so it sees exactly what the page sends.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render } from '@testing-library/svelte'
import { tick } from 'svelte'

const { mockRpc, mockFrom } = vi.hoisted(() => {
  // Any query builder chain resolves to an empty result.
  const chain = (): unknown =>
    new Proxy(function () {}, {
      get: (_t, prop) =>
        prop === 'then'
          ? (ok: (v: unknown) => unknown) => Promise.resolve({ data: [], error: null }).then(ok)
          : chain(),
      apply: () => chain(),
    })
  return {
    mockRpc: vi.fn(() => Promise.resolve({ data: null, error: null })),
    mockFrom: vi.fn(() => chain()),
  }
})

vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn(() => ({ rpc: mockRpc, from: mockFrom })),
}))

vi.mock('../src/lib/admin-auth.svelte', () => import('./helpers/fakeAdminAuth.svelte'))

import App from '../src/App.svelte'
import { setAuthStep } from './helpers/fakeAdminAuth.svelte'

describe('AS.UI.01 — the page reads the active season and never refreshes it', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setAuthStep('idle')
  })

  it('a page load reads the seasons and sends no fn_refresh_active_season', async () => {
    render(App, {
      props: { 'supabase-cert-url': 'https://cert.supabase.co', 'supabase-cert-key': 'cert-key-123' },
    })
    await vi.waitFor(() => expect(mockFrom).toHaveBeenCalledWith('tbl_season'))
    await tick()
    const rpcNames = mockRpc.mock.calls.map((call) => (call as unknown[])[0])
    expect(rpcNames).not.toContain('fn_refresh_active_season')
  })
})
