// Plan tests: 8.01, 8.02, 8.03, 8.04 — CERT/PROD env toggle.
// See doc/m8_implementation_plan.md §T8.0.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'

// Mock the api module before importing App
vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
}))

import App from '../src/App.svelte'
import { initClient } from '../src/lib/api'

const CERT_URL = 'https://cert.supabase.co'
const CERT_KEY = 'cert-key-123'
const PROD_URL = 'https://prod.supabase.co'
const PROD_KEY = 'prod-key-456'

describe('Env toggle (T8.0)', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // 8.01 — Both CERT + PROD creds → env toggle rendered
  it('renders env toggle when both CERT and PROD creds provided', () => {
    const { container } = render(App, {
      props: {
        'supabase-cert-url': CERT_URL,
        'supabase-cert-key': CERT_KEY,
        'supabase-prod-url': PROD_URL,
        'supabase-prod-key': PROD_KEY,
      },
    })
    const toggle = container.querySelector('.env-toggle')
    expect(toggle).not.toBeNull()
    const buttons = toggle!.querySelectorAll('.env-btn')
    expect(buttons.length).toBe(2)
    expect(buttons[0].textContent).toBe('CT')
    expect(buttons[1].textContent).toBe('PD')
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

  // 8.03 — Click PD → activeEnv = PROD, initClient called with PROD URL
  it('switches to PROD when PD button clicked', async () => {
    const { container } = render(App, {
      props: {
        'supabase-cert-url': CERT_URL,
        'supabase-cert-key': CERT_KEY,
        'supabase-prod-url': PROD_URL,
        'supabase-prod-key': PROD_KEY,
      },
    })

    // Initially CERT is active
    const buttons = container.querySelectorAll('.env-btn')
    expect(buttons[0].classList.contains('active')).toBe(true) // CT active

    // Click PD
    await fireEvent.click(buttons[1])

    // PD should now be active
    expect(buttons[1].classList.contains('active')).toBe(true)
    // initClient should have been called with PROD creds
    expect(initClient).toHaveBeenCalledWith(PROD_URL, PROD_KEY)
  })

  // 8.04 — Click CT → activeEnv = CERT, initClient called with CERT URL
  it('switches back to CERT when CT button clicked after PROD', async () => {
    const { container } = render(App, {
      props: {
        'supabase-cert-url': CERT_URL,
        'supabase-cert-key': CERT_KEY,
        'supabase-prod-url': PROD_URL,
        'supabase-prod-key': PROD_KEY,
      },
    })

    const buttons = container.querySelectorAll('.env-btn')

    // Switch to PROD first
    await fireEvent.click(buttons[1])
    vi.clearAllMocks()

    // Switch back to CERT
    await fireEvent.click(buttons[0])

    expect(buttons[0].classList.contains('active')).toBe(true)
    expect(initClient).toHaveBeenCalledWith(CERT_URL, CERT_KEY)
  })
})
