// WP.BAR.01–02, WP.ADM.01–02 — the SPWS bar and drawer on the association's
// WordPress pages (chrome="site"), and PROD admin at /ranking/?admin=1.
// ADR-090 amendment 2026-10-03; FR-148, FR-149.
// Plan: doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html §05.
//
// A WordPress page body holds one element with the PROD pair, chrome="site",
// the file host as asset-base and the five addresses the bar and the drawer
// lead to. Nothing about navigation is taken from WordPress itself, so the
// same tag works unchanged under another CMS.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick, type ComponentProps } from 'svelte'

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  fetchScoringEngines: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))

vi.mock('../src/lib/admin-auth.svelte', () => import('./helpers/fakeAdminAuth.svelte'))

import App from '../src/App.svelte'
import RanklistElement from '../src/ce/RanklistElement.svelte'
import CalendarElement from '../src/ce/CalendarElement.svelte'
import { setLocale } from '../src/lib/locale.svelte'
import { setAssetBase } from '../src/lib/assetBase'
import { setAuthStep } from './helpers/fakeAdminAuth.svelte'

const PROD_URL = 'https://prod.supabase.co'
const PROD_KEY = 'prod-key-456'
const CERT_URL = 'https://cert.supabase.co'
const CERT_KEY = 'cert-key-123'
const ASSET_BASE = 'https://fencer4life.github.io/spws-automated-ranklist/'
const HREFS = {
  'href-home': 'https://weteraniszermierki.pl/',
  'href-ranking': '/ranking/',
  'href-calendar': '/znajdz-zawody/',
  'href-calculator': '/kalkulator-punktow/',
  'href-table': '/tabela-punktacji/',
}

type AppProps = ComponentProps<typeof App>

/** What a WordPress page body delivers: the PROD pair, chrome="site", the addresses. */
const siteProps = (extra: Partial<AppProps> = {}): AppProps => ({
  'supabase-prod-url': PROD_URL,
  'supabase-prod-key': PROD_KEY,
  'asset-base': ASSET_BASE,
  chrome: 'site',
  view: 'ranklist',
  ...HREFS,
  ...extra,
})

beforeEach(() => {
  vi.clearAllMocks()
  setLocale('pl')
  setAuthStep('idle')
  setAssetBase('')
  window.history.replaceState(null, '', '/')
})

afterEach(() => {
  window.history.replaceState(null, '', '/')
  setAssetBase('')
})

describe('WP.BAR.01 — the SPWS bar on a WordPress page', () => {
  it('draws the hamburger, the logo linked home, the title and the PL/EN switch', () => {
    const { container } = render(App, { props: siteProps() })
    const bar = container.querySelector('header.site-bar')
    expect(bar).not.toBeNull()
    expect(bar!.querySelector('button.hamburger-btn')).not.toBeNull()
    const home = bar!.querySelector('a.site-home') as HTMLAnchorElement | null
    expect(home?.getAttribute('href')).toBe('https://weteraniszermierki.pl/')
    expect(home?.querySelector('img')?.getAttribute('src')).toBe(`${ASSET_BASE}SPWS-logo.png`)
    expect(bar!.querySelector('.site-title')).not.toBeNull()
    expect(bar!.querySelector('.lang-toggle')).not.toBeNull()
  })

  it('shows neither the CT/PD switch, nor the Pages header, nor the old embed row', () => {
    const { container } = render(App, { props: siteProps() })
    expect(container.querySelector('header.site-bar')).not.toBeNull()
    expect(container.querySelector('.env-toggle')).toBeNull()
    expect(container.querySelector('.app-header')).toBeNull()
    expect(container.querySelector('.embed-bar')).toBeNull()
  })

  it('the published elements pass chrome="site" and the addresses through', () => {
    const ranking = render(RanklistElement, {
      props: {
        'supabase-prod-url': PROD_URL,
        'supabase-prod-key': PROD_KEY,
        'asset-base': ASSET_BASE,
        chrome: 'site',
        view: 'ranklist',
        ...HREFS,
      },
    })
    expect(ranking.container.querySelector('header.site-bar a.site-home')?.getAttribute('href'))
      .toBe('https://weteraniszermierki.pl/')

    const calendar = render(CalendarElement, {
      props: {
        'supabase-prod-url': PROD_URL,
        'supabase-prod-key': PROD_KEY,
        'asset-base': ASSET_BASE,
        chrome: 'site',
        ...HREFS,
      },
    })
    expect(calendar.container.querySelector('header.site-bar')).not.toBeNull()
    expect(calendar.container.querySelector('.calendar-view')).not.toBeNull()
  })
})

// The bar carries both titles; CSS shows the short one below 430 px. jsdom
// evaluates no media query, so the width switch itself is measured in a real
// browser by WP.BAR.03 (frontend/e2e/site-chrome.spec.ts).
describe('WP.BAR.02 — the long title and the short phone title', () => {
  const titles = (container: HTMLElement) => [
    container.querySelector('header.site-bar .site-title-long')?.textContent?.trim(),
    container.querySelector('header.site-bar .site-title-short')?.textContent?.trim(),
  ]

  it('the Ranking page: Ranking / Ranking, and Ranklist / Ranklist in English', async () => {
    const { container } = render(App, { props: siteProps() })
    expect(titles(container)).toEqual(['Ranking', 'Ranking'])
    setLocale('en')
    await tick()
    expect(titles(container)).toEqual(['Ranklist', 'Ranklist'])
  })

  it('the calendar page: Znajdź zawody / Kalendarz, and Competition Finder / Calendar', async () => {
    const { container } = render(App, { props: siteProps({ view: 'calendar' }) })
    expect(titles(container)).toEqual(['Znajdź zawody', 'Kalendarz'])
    setLocale('en')
    await tick()
    expect(titles(container)).toEqual(['Competition Finder', 'Calendar'])
  })
})

describe('WP.ADM.01 — ?admin=1 opens the sign-in only where the page asks for it', () => {
  beforeEach(() => { window.history.replaceState(null, '', '/?admin=1') })

  it('the Ranking page (admin-entry) opens the sign-in modal at load; github.io still does', async () => {
    const { container } = render(App, { props: siteProps({ 'admin-entry': true }) })
    await tick()
    expect(container.querySelector('header.site-bar')).not.toBeNull()
    expect(container.querySelector('.admin-modal-title')?.textContent?.trim())
      .toBe('Logowanie administratora')

    // github.io (chrome="full") keeps today's behaviour, exactly.
    setAuthStep('idle')
    const pages = render(App, { props: { 'supabase-cert-url': CERT_URL, 'supabase-cert-key': CERT_KEY } })
    await tick()
    expect(pages.container.querySelector('.admin-modal-title')).not.toBeNull()
  })

  it('a page without admin-entry ignores ?admin=1 (the calendar page)', async () => {
    const { container } = render(App, { props: siteProps({ view: 'calendar' }) })
    await tick()
    expect(container.querySelector('header.site-bar')).not.toBeNull()
    expect(container.querySelector('.admin-modal')).toBeNull()
  })
})

describe('WP.ADM.02 — after sign-in the drawer holds the admin section, closed until ☰', () => {
  it('stays closed after sign-in, holds the admin section, and opens on the hamburger', async () => {
    window.history.replaceState(null, '', '/?admin=1')
    const { container } = render(App, { props: siteProps({ 'admin-entry': true }) })
    await tick()
    setAuthStep('authenticated')
    await tick()

    expect(container.querySelector('.sidebar.open')).toBeNull()
    expect(container.querySelector('.sidebar .admin-section')).not.toBeNull()

    const burger = container.querySelector('header.site-bar .hamburger-btn')
    expect(burger).not.toBeNull()
    await fireEvent.click(burger!)
    expect(container.querySelector('.sidebar.open')).not.toBeNull()
  })
})
