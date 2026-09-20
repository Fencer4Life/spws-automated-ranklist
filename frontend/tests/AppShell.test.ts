// Plan tests: 8.27 (hamburger), 8.33, 8.34, 8.37, BY.1-BY.7
// See doc/archive/MVP_development_plan.md §M8 T8.4, §M10 birth year subtitle.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick } from 'svelte'
import { setLocale } from '../src/lib/locale.svelte'
import type { Season } from '../src/lib/types'

// Mock the api module before importing App
vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  // SS26.LOCK.01/§05 (governance lock, 2026-09-19) — released scoring-engine
  // codes for ScoringConfigEditor's engine selector, fetched once in init().
  fetchScoringEngines: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  // SS26.UI (design step 7, ADR-101): fn_ranking_full replaces fn_ranking_kadra
  // as the frontend's RANKING-mode source.
  fetchRankingFull: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  // SS26.UIHIST (design step 7): refreshEvfToggle() reads default_ranking_mode
  // from this same call to normalize filters.mode on season selection.
  fetchScoringConfig: vi.fn().mockResolvedValue(null),
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

const MOCK_SEASONS: Season[] = [
  { id_season: 1, txt_code: 'SPWS-2025-2026', dt_start: '2025-08-01', dt_end: '2026-07-15', bool_active: true, enum_ranking_publication: 'FULL' },
  { id_season: 2, txt_code: 'SPWS-2024-2025', dt_start: '2024-08-15', dt_end: '2025-07-15', bool_active: false, enum_ranking_publication: 'PPW_ONLY' },
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
// SS26.UIHIST (design step 7, ADR-101): season selection normalizes the
// Ranking/PPW switch from the season's own publication capability and
// configured default, and a stale ranking response never overwrites state a
// newer request already set. MOCK_SEASONS below (season 1: FULL; season 2:
// PPW_ONLY) is the shared fixture the Birth Year Subtitle tests above also use.
// ---------------------------------------------------------------------------
describe('SS26.UIHIST — publication boundary and staleness', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setLocale('en')
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

  async function mockConfigs(bySeasonId: Record<number, { show_evf_toggle: boolean; default_ranking_mode: 'PPW' | 'RANKING' }>) {
    const { fetchSeasons, fetchScoringConfig } = await import('../src/lib/api')
    vi.mocked(fetchSeasons).mockResolvedValue(MOCK_SEASONS)
    vi.mocked(fetchScoringConfig).mockImplementation(async (seasonId: number) => {
      const cfg = bySeasonId[seasonId]
      if (!cfg) return null
      return {
        season_code: 'x', mp_value: 50, podium_gold: 3, podium_silver: 2, podium_bronze: 1,
        ppw_multiplier: 1, ppw_best_count: 4, ppw_total_rounds: 5, mpw_multiplier: 1.2, mpw_droppable: false,
        pew_multiplier: 1, pew_best_count: 3, mew_multiplier: 2, mew_droppable: false, msw_multiplier: 1.2,
        psw_multiplier: 2, min_participants_evf: 5, min_participants_ppw: 1, ranking_rules: null,
        show_evf_toggle: cfg.show_evf_toggle, show_evf_toggle_calendar: true,
        default_ranking_mode: cfg.default_ranking_mode,
      } as never
    })
  }

  // Scoped to the FilterBar's own toggle — the app header also mounts
  // LangToggle, which renders two .toggle-btn flag buttons of its own, so an
  // unscoped '.toggle-btn' count is satisfied by the header alone before the
  // ranklist (or even its season dropdown) has finished loading.
  function modeButtons(container: HTMLElement): NodeListOf<HTMLButtonElement> {
    return container.querySelectorAll('.filter-bar .toggle-btn')
  }

  async function waitForSeasonOptions(container: HTMLElement) {
    await vi.waitFor(() => {
      expect(container.querySelectorAll('.season-select option').length).toBeGreaterThan(0)
    })
    await tick()
  }

  // SS26.UIHIST: a FULL season with the toggle enabled shows the switch and
  // adopts that season's own configured default mode.
  it('a FULL season shows the switch and defaults to its configured mode', async () => {
    await mockConfigs({ 1: { show_evf_toggle: true, default_ranking_mode: 'RANKING' } })
    const { container } = renderApp()
    await waitForSeasonOptions(container)
    await vi.waitFor(() => {
      expect(modeButtons(container).length).toBe(2)
    })
    const btns = modeButtons(container)
    expect(btns[1].classList.contains('active')).toBe(true) // Ranking is active
  })

  // SS26.UIHIST: a PPW_ONLY season forces PPW and hides the switch entirely —
  // even though season 2's own config has show_evf_toggle: true, publication
  // capability wins.
  it('a PPW_ONLY season forces PPW and hides the switch regardless of the config flag', async () => {
    await mockConfigs({
      1: { show_evf_toggle: true, default_ranking_mode: 'RANKING' },
      2: { show_evf_toggle: true, default_ranking_mode: 'RANKING' },
    })
    const { container } = renderApp()
    await waitForSeasonOptions(container)
    await vi.waitFor(() => {
      expect(modeButtons(container).length).toBe(2)
    })
    const seasonSelect = container.querySelector('.season-select') as HTMLSelectElement
    await fireEvent.change(seasonSelect, { target: { value: '2' } })
    await vi.waitFor(() => {
      expect(modeButtons(container).length).toBe(0)
    })
  })

  // SS26.UIHIST: returning to a FULL season restores the switch and its own
  // configured default (design §09 scenario E).
  it('returning to a FULL season restores the switch and its own default', async () => {
    await mockConfigs({
      1: { show_evf_toggle: true, default_ranking_mode: 'RANKING' },
      2: { show_evf_toggle: true, default_ranking_mode: 'RANKING' },
    })
    const { container } = renderApp()
    await waitForSeasonOptions(container)
    await vi.waitFor(() => expect(modeButtons(container).length).toBe(2))

    const seasonSelect = container.querySelector('.season-select') as HTMLSelectElement
    await fireEvent.change(seasonSelect, { target: { value: '2' } })
    await vi.waitFor(() => expect(modeButtons(container).length).toBe(0))

    await fireEvent.change(seasonSelect, { target: { value: '1' } })
    await vi.waitFor(() => expect(modeButtons(container).length).toBe(2))
    const btns = modeButtons(container)
    expect(btns[1].classList.contains('active')).toBe(true)
  })

  // SS26.UIHIST: a slow response from an abandoned mode switch is discarded —
  // the ranklist ends up reflecting only the LAST selected mode's data, not a
  // late-arriving response from the one the user already switched away from.
  it('discards a stale ranking response that resolves after a newer request started', async () => {
    await mockConfigs({ 1: { show_evf_toggle: true, default_ranking_mode: 'PPW' } })
    const { fetchRankingPpw, fetchRankingFull } = await import('../src/lib/api')

    let resolveStaleFull: (rows: unknown[]) => void = () => {}
    // First PPW load (init) resolves immediately with an empty list.
    vi.mocked(fetchRankingPpw).mockResolvedValueOnce([])
    const { container } = renderApp()
    await waitForSeasonOptions(container)
    await vi.waitFor(() => {
      expect(modeButtons(container).length).toBe(2)
    })

    // Switch to Ranking: hang this fetchRankingFull call deliberately.
    const hungFull = new Promise((resolve) => {
      resolveStaleFull = resolve as (rows: unknown[]) => void
    })
    vi.mocked(fetchRankingFull).mockReturnValueOnce(hungFull as never)
    const rankingBtn = modeButtons(container)[1]
    await fireEvent.click(rankingBtn)

    // Before it resolves, switch back to PPW — a newer generation starts.
    vi.mocked(fetchRankingPpw).mockResolvedValueOnce([
      { rank: 1, id_fencer: 1, fencer_name: 'LATE Arrival', ppw_score: 90, mpw_score: 9, total_score: 99 },
    ])
    const ppwBtn = modeButtons(container)[0]
    await fireEvent.click(ppwBtn)
    await vi.waitFor(() => {
      expect(container.textContent).toContain('LATE Arrival')
    })

    // Now let the abandoned Ranking-mode fetch resolve late.
    resolveStaleFull([{ rank: 1, id_fencer: 2, fencer_name: 'STALE Response', spws_total: 1, evf_plus_total: 1, total_score: 2 }])
    await tick()
    await tick()
    // The stale RANKING-mode row must never have overwritten the PPW rows
    // the user is now looking at.
    expect(container.textContent).not.toContain('STALE Response')
    expect(container.textContent).toContain('LATE Arrival')
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
