// WP.ADM.04–05 — the administrator reaches the calendar, and with it „Usuń”,
// on PROD (I7). PROD administration exists only on /ranking/ (`admin-entry`,
// FR-149). Following the drawer's link to /znajdz-zawody/ mounts the app
// afresh, and every mount resets the sign-in, so the administrator arrived as
// a visitor. Signed in, the entry now opens the calendar in place.
// Plan: doc/plans/i7-admin-reaches-remove-on-prod-2026-11-18.html §04.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick, type ComponentProps } from 'svelte'
import { fetchAllCalendarEvents } from '../src/lib/api'

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  fetchScoringEngines: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))

vi.mock('../src/lib/admin-auth.svelte', () => import('./helpers/fakeAdminAuth.svelte'))
vi.mock('../src/components/CalendarView.svelte', () => import('./helpers/CalendarViewProbe.svelte'))

import App from '../src/App.svelte'
import { setLocale } from '../src/lib/locale.svelte'
import { setAuthStep } from './helpers/fakeAdminAuth.svelte'

type AppProps = ComponentProps<typeof App>

/** A WordPress page body: the PROD pair, chrome="site", the five addresses. */
const siteProps = (extra: Partial<AppProps> = {}): AppProps => ({
  'supabase-prod-url': 'https://prod.supabase.co',
  'supabase-prod-key': 'prod-key-456',
  'asset-base': 'https://fencer4life.github.io/spws-automated-ranklist/',
  chrome: 'site',
  view: 'ranklist',
  'href-home': 'https://weteraniszermierki.pl/',
  'href-ranking': '/ranking/',
  'href-calendar': '/znajdz-zawody/',
  'href-calculator': '/kalkulator-punktow/',
  'href-table': '/tabela-punktacji/',
  ...extra,
})

/** The Ranking page, signed in. */
async function signedInOnRanking() {
  window.history.replaceState(null, '', '/?admin=1')
  const r = render(App, { props: siteProps({ 'admin-entry': true }) })
  await tick()
  setAuthStep('authenticated')
  await tick()
  return r
}

/** Opens the drawer and chooses „Znajdź zawody”; returns whether the link was cancelled. */
async function chooseCalendar(container: HTMLElement): Promise<boolean> {
  await fireEvent.click(container.querySelector('header.site-bar .hamburger-btn')!)
  const entry = container.querySelectorAll('.sidebar .nav-list .nav-item')[1] as HTMLAnchorElement
  expect(entry.getAttribute('href')).toBe('/znajdz-zawody/')
  const click = new MouseEvent('click', { bubbles: true, cancelable: true })
  entry.dispatchEvent(click)
  await tick()
  await tick()
  return click.defaultPrevented
}

beforeEach(() => {
  vi.clearAllMocks()
  setLocale('pl')
  setAuthStep('idle')
  window.history.replaceState(null, '', '/')
})

afterEach(() => {
  window.history.replaceState(null, '', '/')
})

describe('WP.ADM.04 — signed in on /ranking/, „Znajdź zawody” opens the calendar in place', () => {
  it('shows the calendar on the same element, told an administrator is signed in', async () => {
    const { container } = await signedInOnRanking()
    expect(container.querySelector('.calendar-probe')).toBeNull()

    expect(await chooseCalendar(container)).toBe(true)

    const probe = container.querySelector('.calendar-probe')
    expect(probe).not.toBeNull()
    expect(probe!.getAttribute('data-is-admin')).toBe('true')
    expect(fetchAllCalendarEvents).toHaveBeenCalled()
    expect(container.querySelector('header.site-bar')?.textContent).toContain('Znajdź zawody')
    expect(container.querySelector('.sidebar .admin-section')).not.toBeNull()
    expect(container.querySelector('.sidebar.open')).toBeNull()
  })

  // Q1 (signed 2026-11-18): signing out leaves the visitor on the calendar.
  it('signing out keeps the calendar, now told nobody is signed in', async () => {
    const { container } = await signedInOnRanking()
    await chooseCalendar(container)
    setAuthStep('idle')
    await tick()
    expect(container.querySelector('.calendar-probe')?.getAttribute('data-is-admin')).toBe('false')
    expect(container.querySelector('.sidebar .admin-section')).toBeNull()
  })
})

describe('WP.ADM.05 — a calendar opened in place takes the full screen height', () => {
  it('the Ranking element showing the calendar carries the height class', async () => {
    const { container } = await signedInOnRanking()
    expect(container.querySelector('.ranklist-app.site-own-height')).toBeNull()
    await chooseCalendar(container)
    expect(container.querySelector('.ranklist-app.site-fill.site-own-height')).not.toBeNull()
  })

  it('the calendar page never carries it, signed in or not', async () => {
    const { container } = render(App, { props: siteProps({ view: 'calendar' }) })
    await tick()
    expect(container.querySelector('.ranklist-app.site-fill')).not.toBeNull()
    expect(container.querySelector('.site-own-height')).toBeNull()
    setAuthStep('authenticated')
    await tick()
    expect(container.querySelector('.site-own-height')).toBeNull()
  })
})
