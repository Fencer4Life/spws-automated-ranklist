// Plan tests: 8.27 (hamburger), 8.33, 8.34, 8.37, BY.1-BY.7
// See doc/archive/MVP_development_plan.md §M8 T8.4, §M10 birth year subtitle.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick } from 'svelte'
import { setLocale } from '../src/lib/locale.svelte'

// Mock the api module before importing App
vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
  // ADR-084 — the calendar view spans every season, so App loads through this.
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
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

  // 8.37 — Season selector in the ranklist filter bar (moved from the header).
  //
  // REWRITTEN by the ADR-084 triage. This used to assert the selector survived
  // the switch INTO the calendar. It no longer does, and that is the decision,
  // not a regression: the barrel owns season state with no season clamp, and
  // the seam carries the season code, which is what allowed the dropdown to be
  // deleted. The ranklist half of the original assertion still stands and is
  // the half that was actually protecting something.
  it('keeps the season selector in the ranklist, and drops it in the calendar', async () => {
    const { fetchSeasons } = await import('../src/lib/api')
    vi.mocked(fetchSeasons).mockResolvedValue(MOCK_SEASONS)
    const { container } = renderApp()
    await vi.waitFor(() => {
      expect(container.querySelector('.season-select')).not.toBeNull()
    })
    await tick()

    // Season select present in ranklist filter bar
    const seasonSelect = container.querySelector('.season-select')
    expect(seasonSelect).not.toBeNull()

    // Switch to calendar view
    const hamburger = container.querySelector('.hamburger-btn')
    await fireEvent.click(hamburger!)
    const navItems = container.querySelectorAll('.nav-item')
    const calendarItem = Array.from(navItems).find((el) =>
      el.textContent?.includes('Kalendarz'),
    )
    await fireEvent.click(calendarItem!)
    await tick()

    // ADR-084 — the calendar has no season dropdown; the barrel is the control.
    expect(container.querySelector('.season-select')).toBeNull()
    expect(container.querySelector('.calendar-view')).not.toBeNull()
  })
})

const MOCK_SEASONS = [
  { id_season: 1, txt_code: 'SPWS-2025-2026', dt_start: '2025-08-01', dt_end: '2026-07-15', bool_active: true },
  { id_season: 2, txt_code: 'SPWS-2024-2025', dt_start: '2024-08-15', dt_end: '2025-07-15', bool_active: false },
]

describe('Birth Year Subtitle (BY.1–BY.7)', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setLocale('pl')
  })

  function renderApp(extraProps = {}) {
    return render(App, {
      props: {
        'supabase-cert-url': 'https://cert.supabase.co',
        'supabase-cert-key': 'cert-key-123',
        ...extraProps,
      },
    })
  }

  async function renderWithSeasons(extraProps = {}) {
    const { fetchSeasons } = await import('../src/lib/api')
    vi.mocked(fetchSeasons).mockResolvedValue(MOCK_SEASONS)
    const result = renderApp(extraProps)
    // Wait for init() to complete: seasons loaded → options rendered
    await vi.waitFor(() => {
      const options = result.container.querySelectorAll('.season-select option')
      expect(options.length).toBeGreaterThan(0)
    })
    await tick()
    return result
  }

  // BY.1 — Subtitle renders when season loaded
  it('renders .category-subtitle when season is loaded', async () => {
    const { container } = await renderWithSeasons()
    expect(container.querySelector('.category-subtitle')).not.toBeNull()
  })

  // BY.2 — V1 + season 2026 → 1986, 1985, .. 1977
  it('shows correct birth years for V1 with season ending 2026', async () => {
    const { container } = await renderWithSeasons()
    const subtitle = container.querySelector('.category-subtitle')
    expect(subtitle?.textContent).toContain('1986, 1985, .. 1977')
  })

  // BY.3 — V0 + season 2026 → 1996, 1995, .. 1987
  it('shows correct birth years for V0 with season ending 2026', async () => {
    const { container } = await renderWithSeasons()
    // Change category to V0
    const categorySelect = container.querySelectorAll('.filter-bar select')[3]
    await fireEvent.change(categorySelect, { target: { value: 'V0' } })
    await tick()
    const subtitle = container.querySelector('.category-subtitle')
    expect(subtitle?.textContent).toContain('1996, 1995, .. 1987')
  })

  // BY.4 — V4 + season 2026 → open-ended with "i starsi"
  it('shows open-ended range for V4 with "i starsi"', async () => {
    const { container } = await renderWithSeasons()
    // Change category to V4
    const categorySelect = container.querySelectorAll('.filter-bar select')[3]
    await fireEvent.change(categorySelect, { target: { value: 'V4' } })
    await tick()
    const subtitle = container.querySelector('.category-subtitle')
    expect(subtitle?.textContent).toContain('1956, 1955, ..')
    expect(subtitle?.textContent).toContain('i starsi')
  })

  // BY.5 — EN locale uses English labels
  it('shows English labels when locale is EN', async () => {
    setLocale('en')
    const { container } = await renderWithSeasons()
    // Change category to V4 to test "and older"
    const categorySelect = container.querySelectorAll('.filter-bar select')[3]
    await fireEvent.change(categorySelect, { target: { value: 'V4' } })
    await tick()
    const subtitle = container.querySelector('.category-subtitle')
    expect(subtitle?.textContent).toContain('cat.')
    expect(subtitle?.textContent).toContain('birth years:')
    expect(subtitle?.textContent).toContain('and older')
  })

  // BY.6 — No season → no subtitle
  it('does not render subtitle when no season is selected', () => {
    // Default mock returns [] for fetchSeasons → no season selected
    const { container } = renderApp()
    expect(container.querySelector('.category-subtitle')).toBeNull()
  })

  // BY.7 — Season change updates birth years dynamically
  it('updates birth years when season changes', async () => {
    const { container } = await renderWithSeasons()

    // Initially season 1 (end year 2026): V1 → 1986..1977
    const subtitle = container.querySelector('.category-subtitle')
    expect(subtitle?.textContent).toContain('1986, 1985, .. 1977')

    // Switch to season 2 (end year 2025)
    const seasonSelect = container.querySelector('.season-select') as HTMLSelectElement
    await fireEvent.change(seasonSelect, { target: { value: '2' } })
    await tick()
    await tick()

    // V1 → 1985..1976
    const subtitleAfter = container.querySelector('.category-subtitle')
    expect(subtitleAfter?.textContent).toContain('1985, 1984, .. 1976')
  })
})

// ---------------------------------------------------------------------------
// The calendar's dataset spans EVERY season (ADR-084 §4). `fetchCalendarEvents`
// is season-scoped and cannot feed the drum — api.ts says so above
// `fetchAllCalendarEvents` — yet six sites in App refilled `calendarEvents`
// from it, every admin write path among them. Saving an event therefore
// replaced 66 month rows with 10 while the barrel still held a selection from
// the wider set, which is what crashed the calendar on PROD on 2026-09-02
// (CalendarBarrel CB.30).
//
// Structural, like 9.17 above: the assignment happens inside handlers that need
// an authenticated admin session and a mounted EventManager to reach, and the
// contract worth pinning is simply that this pairing never returns.
// ---------------------------------------------------------------------------
describe('App — the calendar dataset', () => {
  async function appSource(): Promise<string> {
    const fs = await import('fs')
    const path = await import('path')
    return fs.readFileSync(path.resolve(__dirname, '../src/App.svelte'), 'utf-8')
  }

  it('AS.1: never fills the calendar from the season-scoped query', async () => {
    const src = await appSource()
    const offenders = src.match(/calendarEvents\s*=\s*await\s+fetchCalendarEvents\b/g) ?? []
    expect(offenders).toEqual([])
  })

  it('AS.2: refills it through one function, so every path agrees', async () => {
    const src = await appSource()
    // The season-scoped query keeps its legitimate callers (the carry-over and
    // prior-season pickers), so this asserts the pairing, not the import.
    expect(src).toContain('async function reloadCalendar()')
    expect(src.match(/calendarEvents\s*=\s*await\s+fetchAllCalendarEvents\(\)/g) ?? []).toHaveLength(1)
  })
})
