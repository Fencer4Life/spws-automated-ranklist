// Plan tests: 8.27 (hamburger), 8.33, 8.34, 8.37
// See doc/m8_implementation_plan.md §T8.4.

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
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
}))

import App from '../src/App.svelte'

const CERT_URL = 'https://cert.supabase.co'
const CERT_KEY = 'cert-key-123'

describe('App Shell (T8.4)', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  function renderApp(extraProps = {}) {
    return render(App, {
      props: {
        'supabase-cert-url': CERT_URL,
        'supabase-cert-key': CERT_KEY,
        ...extraProps,
      },
    })
  }

  // 8.27 — Hamburger button opens sidebar
  it('has a hamburger button that opens sidebar', async () => {
    const { container } = renderApp()
    const hamburger = container.querySelector('.hamburger-btn')
    expect(hamburger).not.toBeNull()

    // Sidebar should not be open initially
    expect(container.querySelector('.sidebar.open')).toBeNull()

    // Click hamburger
    await fireEvent.click(hamburger!)

    // Sidebar should now be open
    expect(container.querySelector('.sidebar.open')).not.toBeNull()
  })

  // 8.33 — Default view is ranklist (POC backward compatible)
  it('defaults to ranklist view', () => {
    const { container } = renderApp()
    // Ranklist content should be visible (FilterBar)
    const filterBar = container.querySelector('.filter-bar')
    expect(filterBar).not.toBeNull()
  })

  // 8.34 — Header title updates when view changes
  it('updates header title when view changes', async () => {
    const { container } = renderApp()
    // Default: ranklist title
    const title = container.querySelector('.app-title')
    expect(title?.textContent).toContain('Ranking')
    expect(title?.querySelector('.header-logo')).not.toBeNull()

    // Open sidebar and click Kalendarz
    const hamburger = container.querySelector('.hamburger-btn')
    await fireEvent.click(hamburger!)
    const navItems = container.querySelectorAll('.nav-item')
    const calendarItem = Array.from(navItems).find((el) =>
      el.textContent?.includes('Kalendarz'),
    )
    await fireEvent.click(calendarItem!)

    // Title should change
    expect(title?.textContent).toContain('Kalendarz')
    expect(title?.querySelector('.header-logo')).not.toBeNull()
  })

  // 8.37 — Season selector shared between both views
  it('keeps season selector visible in both views', async () => {
    const { container } = renderApp()

    // Season selector present in ranklist view
    const seasonSelector = container.querySelector('.season-selector')
    expect(seasonSelector).not.toBeNull()

    // Switch to calendar view
    const hamburger = container.querySelector('.hamburger-btn')
    await fireEvent.click(hamburger!)
    const navItems = container.querySelectorAll('.nav-item')
    const calendarItem = Array.from(navItems).find((el) =>
      el.textContent?.includes('Kalendarz'),
    )
    await fireEvent.click(calendarItem!)

    // Season selector still present
    const seasonSelectorAfter = container.querySelector('.season-selector')
    expect(seasonSelectorAfter).not.toBeNull()
  })
})
