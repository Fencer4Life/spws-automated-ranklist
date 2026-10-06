// SE27.UI.09 (ADR-103 §2): the released scoring engines reach the Admin
// scoring editor after an in-page sign-in.
//
// tbl_scoring_engine is readable by `authenticated` only (policy "Admin read
// scoring engines", 20260919000005). App used to fetch the list once in init(),
// which runs anonymous on every page load. App also resets the auth step at
// mount, so an admin always signs in on the open page — and got an empty list:
// no season engine, and no option in any per-type engine selector, unless
// supabase-js happened to hold a session from an earlier sign-in when the page
// loaded. Every public visitor also made a request that could only answer 401.
// The list now loads when the admin signs in, and never for an anonymous visitor.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render } from '@testing-library/svelte'
import { tick } from 'svelte'

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  fetchSeasons: vi.fn().mockResolvedValue([
    { id_season: 1, txt_code: 'SPWS-2026-2027', dt_start: '2026-07-13', dt_end: '2027-07-15', bool_active: true },
  ]),
  fetchScoringEngines: vi.fn().mockResolvedValue([
    { code: 'EVF_CLASSIC_V1_2025_2026', label: 'EVF klasyczny (do sezonu 2025/2026)', module: 'PER_CATEGORY_RENUMBER' },
  ]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchRankingFull: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchScoringConfig: vi.fn().mockResolvedValue(null),
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))

vi.mock('../src/lib/admin-auth.svelte', () => import('./helpers/fakeAdminAuth.svelte'))

import App from '../src/App.svelte'
import { fetchScoringEngines, fetchSeasons } from '../src/lib/api'
import { setAuthStep } from './helpers/fakeAdminAuth.svelte'

describe('SE27.UI.09 — the engine list loads with an admin session', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setAuthStep('idle')
  })

  async function renderLoaded() {
    const view = render(App, {
      props: { 'supabase-cert-url': 'https://cert.supabase.co', 'supabase-cert-key': 'cert-key-123' },
    })
    await vi.waitFor(() => expect(fetchSeasons).toHaveBeenCalled())
    await tick()
    return view
  }

  it('an anonymous visitor never requests the admin-only engine list', async () => {
    await renderLoaded()
    await tick()
    expect(fetchScoringEngines).not.toHaveBeenCalled()
  })

  it('an admin who signs in on the open page gets the list', async () => {
    await renderLoaded()
    expect(fetchScoringEngines).not.toHaveBeenCalled()
    setAuthStep('authenticated')
    await tick()
    await vi.waitFor(() => expect(fetchScoringEngines).toHaveBeenCalledTimes(1))
  })

  it('App resets the auth step at mount, so the in-page sign-in is the only path', async () => {
    setAuthStep('authenticated')
    await renderLoaded()
    await tick()
    expect(fetchScoringEngines).not.toHaveBeenCalled()
    setAuthStep('authenticated')
    await tick()
    await vi.waitFor(() => expect(fetchScoringEngines).toHaveBeenCalledTimes(1))
  })
})
