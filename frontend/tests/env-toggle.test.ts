// Plan tests: 8.02 — CERT/PROD environment pairs (T8.0).
// See doc/archive/m8_implementation_plan.md §T8.0.
//
// WP.ENV.01–02 — each host serves one environment (ADR-109, FR-151; plan
// doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html §05).
// github.io gets both pairs but shows CERT only, with a TEST ribbon and no CT/PD
// switch; the PROD pair stays there for one read: which seasons already exist on
// PROD (ADR-077 promotion). WordPress gets the PROD pair only. WP.ENV.01 replaces
// 8.01, 8.03 and 8.04, which asserted the switch that ADR-109 removes.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick } from 'svelte'

// Mock the api module before importing App
vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  // SS26.LOCK.01/§05 (governance lock, 2026-09-19) — released scoring-engine
  // codes for ScoringConfigEditor's engine selectors, loaded once an admin signs in (SE27.UI.09).
  fetchScoringEngines: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchRankingFull: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchScoringConfig: vi.fn().mockResolvedValue(null),
  // ADR-084 — the calendar view spans every season, so App loads through this.
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
  // ADR-077 — the promotion state of each season, read on the Seasons view.
  fetchSeasonChildState: vi.fn().mockResolvedValue({}),
  fetchProdSeasonCodes: vi.fn().mockResolvedValue([]),
}))

vi.mock('../src/lib/admin-auth.svelte', () => import('./helpers/fakeAdminAuth.svelte'))

import App from '../src/App.svelte'
import { initClient, fetchSeasons, fetchProdSeasonCodes } from '../src/lib/api'
import { setAuthStep } from './helpers/fakeAdminAuth.svelte'

const CERT_URL = 'https://cert.supabase.co'
const CERT_KEY = 'cert-key-123'
const PROD_URL = 'https://prod.supabase.co'
const PROD_KEY = 'prod-key-456'

const BOTH = {
  'supabase-cert-url': CERT_URL,
  'supabase-cert-key': CERT_KEY,
  'supabase-prod-url': PROD_URL,
  'supabase-prod-key': PROD_KEY,
}

describe('Env toggle (T8.0)', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setAuthStep('idle')
  })

  // 8.02 — Only CERT creds → env toggle hidden
  it('hides env toggle when only CERT creds provided', () => {
    const { container } = render(App, {
      props: {
        'supabase-cert-url': CERT_URL,
        'supabase-cert-key': CERT_KEY,
        'supabase-prod-url': '',
        'supabase-prod-key': '',
      },
    })
    const toggle = container.querySelector('.env-toggle')
    expect(toggle).toBeNull()
  })
})

describe('WP.ENV.01 — github.io (both pairs) is CERT only', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setAuthStep('idle')
    vi.mocked(fetchSeasons).mockResolvedValue([
      { id_season: 1, txt_code: 'SPWS-2026-2027', dt_start: '2026-07-13', dt_end: '2027-07-15', bool_active: true },
    ] as never)
  })

  it('shows no CT/PD switch and a TEST ribbon, and works on CERT', () => {
    const { container } = render(App, { props: BOTH })
    expect(container.querySelector('.env-toggle')).toBeNull()
    expect(container.querySelector('.env-btn')).toBeNull()
    expect(container.querySelector('.env-ribbon')?.textContent?.trim()).toBe('TEST')
    expect(initClient).toHaveBeenCalledWith(CERT_URL, CERT_KEY)
    expect(initClient).not.toHaveBeenCalledWith(PROD_URL, PROD_KEY)
  })

  it('still reads from PROD which seasons are already there (promotion, ADR-077)', async () => {
    const { container } = render(App, { props: BOTH })
    await vi.waitFor(() => expect(fetchSeasons).toHaveBeenCalled())
    await tick()
    setAuthStep('authenticated')
    await tick()

    const seasonsItem = Array.from(container.querySelectorAll('.sidebar .admin-item'))
      .find((b) => b.textContent?.trim() === 'Sezony')
    expect(seasonsItem).toBeDefined()
    await fireEvent.click(seasonsItem!)

    await vi.waitFor(() => expect(fetchProdSeasonCodes).toHaveBeenCalledWith(PROD_URL, PROD_KEY))
    // A read of PROD, never a switch of the whole page to PROD.
    expect(initClient).not.toHaveBeenCalledWith(PROD_URL, PROD_KEY)
    expect(container.querySelector('.env-ribbon')).not.toBeNull()
  })
})

// A guard for the WordPress side: it already works on PROD with no switch; this
// keeps it there (and keeps the ribbon off it) once github.io gains the ribbon.
// Proven by mutation (an unconditional ribbon, or CERT as the default, turns it red).
describe('WP.ENV.02 — WordPress (the PROD pair only) is PROD, without a ribbon', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setAuthStep('idle')
  })

  for (const chrome of ['none', 'site'] as const) {
    it(`chrome="${chrome}": no ribbon, no switch, and the client — and so every dispatch — targets PROD`, () => {
      const { container } = render(App, {
        props: { 'supabase-prod-url': PROD_URL, 'supabase-prod-key': PROD_KEY, chrome, view: 'calendar' },
      })
      expect(container.querySelector('.env-ribbon')).toBeNull()
      expect(container.querySelector('.env-toggle')).toBeNull()
      expect(initClient).toHaveBeenCalledWith(PROD_URL, PROD_KEY)
      expect(initClient).not.toHaveBeenCalledWith(CERT_URL, CERT_KEY)
    })
  }
})
