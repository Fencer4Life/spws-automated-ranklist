// PROD deployment step 1 — the WordPress embed interface.
// Plan: doc/plans/prod-deployment-wordpress-2026-09-05.html §06.
//
// The embed is the same application as the Pages build, mounted with
// `view="calendar" chrome="none"` and given ONLY the PROD credential pair.
// That last part is what these tests mostly guard: every credential defect
// this repo has had came from resolution logic that assumed both pairs exist.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick, type ComponentProps } from 'svelte'

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))

import App from '../src/App.svelte'
import CalendarElement from '../src/ce/CalendarElement.svelte'
import { initClient, fetchAllCalendarEvents } from '../src/lib/api'
import { setAssetBase, assetUrl } from '../src/lib/assetBase'
import { setLocale } from '../src/lib/locale.svelte'

const PROD_URL = 'https://prod.supabase.co'
const PROD_KEY = 'prod-key-456'
const CERT_URL = 'https://cert.supabase.co'
const CERT_KEY = 'cert-key-123'

type AppProps = ComponentProps<typeof App>

/** The attribute set WordPress actually delivers: PROD pair only. */
const embedProps = (extra: Partial<AppProps> = {}): AppProps => ({
  'supabase-prod-url': PROD_URL,
  'supabase-prod-key': PROD_KEY,
  view: 'calendar',
  chrome: 'none',
  ...extra,
})

describe('WordPress embed — credential resolution', () => {
  beforeEach(() => { vi.clearAllMocks() })

  // The embed is given no CERT pair at all. `activeEnv` starts at 'CERT', so a
  // resolution that reads certUrl first yields '' and the init effect never
  // runs — a blank embed with no error anywhere.
  it('initialises against PROD when only the PROD pair is supplied', () => {
    render(App, { props: embedProps() })
    expect(initClient).toHaveBeenCalledWith(PROD_URL, PROD_KEY)
  })

  it('renders no CERT/PROD switch when only the PROD pair is supplied', () => {
    const { container } = render(App, { props: embedProps() })
    expect(container.querySelector('.env-toggle')).toBeNull()
  })

  // Guard against fixing the above by making PROD win unconditionally: the
  // Pages app supplies both pairs and must still open on CERT with the toggle.
  it('still opens on CERT and shows the switch when both pairs are supplied', () => {
    const { container } = render(App, {
      props: {
        'supabase-cert-url': CERT_URL,
        'supabase-cert-key': CERT_KEY,
        'supabase-prod-url': PROD_URL,
        'supabase-prod-key': PROD_KEY,
      },
    })
    expect(initClient).toHaveBeenCalledWith(CERT_URL, CERT_KEY)
    expect(container.querySelector('.env-toggle')).not.toBeNull()
  })
})

describe('WordPress embed — chrome="none"', () => {
  beforeEach(() => { vi.clearAllMocks() })

  it('removes the application header', () => {
    const { container } = render(App, { props: embedProps() })
    expect(container.querySelector('.app-header')).toBeNull()
  })

  it('removes the hamburger button', () => {
    const { container } = render(App, { props: embedProps() })
    expect(container.querySelector('.hamburger-btn')).toBeNull()
  })

  it('removes the drawer', () => {
    const { container } = render(App, { props: embedProps() })
    expect(container.querySelector('.sidebar')).toBeNull()
  })

  it('keeps the header when chrome is full (the Pages app)', () => {
    const { container } = render(App, {
      props: {
        'supabase-cert-url': CERT_URL,
        'supabase-cert-key': CERT_KEY,
      },
    })
    expect(container.querySelector('.app-header')).not.toBeNull()
  })
})

describe('WordPress embed — view routing', () => {
  beforeEach(() => { vi.clearAllMocks() })

  it('opens on the calendar when view="calendar"', () => {
    const { container } = render(App, { props: embedProps() })
    expect(container.querySelector('.calendar-view, .calendar-barrel')).not.toBeNull()
  })

  it('opens on the ranklist when view="ranklist"', () => {
    const { container } = render(App, { props: embedProps({ view: 'ranklist' }) })
    expect(container.querySelector('.filter-bar, .ranklist-table')).not.toBeNull()
  })

  it('defaults to the ranklist when no view is given (the Pages app)', () => {
    const { container } = render(App, {
      props: { 'supabase-cert-url': CERT_URL, 'supabase-cert-key': CERT_KEY },
    })
    expect(container.querySelector('.filter-bar, .ranklist-table')).not.toBeNull()
  })
})

// One row carries everything the removed application header used to, at no
// extra height: the way back to the association's site, the page's own name,
// the language toggle, and fullscreen.
describe('WordPress embed — the top row', () => {
  beforeEach(() => { vi.clearAllMocks(); setLocale('pl') })

  it('renders the embed bar only when embedded', () => {
    const { container } = render(App, { props: embedProps() })
    expect(container.querySelector('.embed-bar')).not.toBeNull()
  })

  it('does not render the embed bar in the Pages app', () => {
    const { container } = render(App, {
      props: { 'supabase-cert-url': CERT_URL, 'supabase-cert-key': CERT_KEY },
    })
    expect(container.querySelector('.embed-bar')).toBeNull()
  })

  // The host page hides the theme's header, navigation and footer, so this mark
  // is the ONLY route back to weteraniszermierki.pl from the calendar. It was
  // briefly removed on 2026-09-05 and that broke the way out — hence two tests.
  it('links the SPWS mark to the association site', () => {
    const { container } = render(App, { props: embedProps() })
    const home = container.querySelector('.embed-bar a.embed-home') as HTMLAnchorElement
    expect(home).not.toBeNull()
    expect(home.getAttribute('href')).toBe('https://weteraniszermierki.pl')
    expect(home.querySelector('img.embed-logo')).not.toBeNull()
  })

  it('resolves the embed mark through asset-base', () => {
    const { container } = render(App, {
      props: embedProps({ 'asset-base': 'https://spws.github.io/ranklist/' }),
    })
    const img = container.querySelector('.embed-bar a.embed-home img') as HTMLImageElement
    expect(img.getAttribute('src')).toBe('https://spws.github.io/ranklist/SPWS-logo.png')
  })

  // The embed has its own language toggle, so it names itself in ONE language
  // at a time — never the bilingual slash form the WordPress menu item uses.
  it('names the page in Polish by default', () => {
    const { container } = render(App, { props: embedProps() })
    const title = container.querySelector('.embed-title')
    expect(title?.textContent?.trim()).toBe('Znajdź zawody')
    expect(title?.textContent).not.toContain('/')
  })

  it('names the page in English once the language is switched', async () => {
    const { container } = render(App, { props: embedProps() })
    setLocale('en')
    await tick()
    expect(container.querySelector('.embed-title')?.textContent?.trim())
      .toBe('Competition finder')
  })

  it('carries the language toggle lifted out of the deleted header', () => {
    const { container } = render(App, { props: embedProps() })
    expect(container.querySelector('.embed-bar .lang-toggle')).not.toBeNull()
  })

  it('offers a fullscreen control', () => {
    const { container } = render(App, { props: embedProps() })
    const btn = container.querySelector('button.embed-fullscreen')
    expect(btn).not.toBeNull()
    expect(btn?.getAttribute('aria-label')).toBeTruthy()
  })

  // The Fullscreen API only grants on a user gesture, so this cannot be forced
  // on load — it must hang off the button.
  it('requests fullscreen on click', async () => {
    const { container } = render(App, { props: embedProps() })
    const requestFullscreen = vi.fn().mockResolvedValue(undefined)
    const root = container.querySelector('.ranklist-app') as HTMLElement
    root.requestFullscreen = requestFullscreen
    await fireEvent.click(container.querySelector('button.embed-fullscreen')!)
    expect(requestFullscreen).toHaveBeenCalled()
  })
})

// The element WordPress actually instantiates. Until now it was a mock stub
// whose only prop was `demo` — it had never talked to a database.
describe('<spws-calendar> element', () => {
  beforeEach(() => { vi.clearAllMocks(); setAssetBase('') })

  it('mounts the real application against PROD, not the mock stub', () => {
    render(CalendarElement, {
      props: { 'supabase-prod-url': PROD_URL, 'supabase-prod-key': PROD_KEY },
    })
    expect(initClient).toHaveBeenCalledWith(PROD_URL, PROD_KEY)
  })

  // Opening straight on the calendar must load the calendar. App.init() used to
  // end in an unconditional loadRanking(), which was invisible while the app
  // always started on the ranklist: the embed fetched ranking rows nobody sees
  // and rendered an empty barrel. Awaited because init() is async.
  it('loads every season, not one — the barrel crosses season boundaries', async () => {
    render(CalendarElement, {
      props: { 'supabase-prod-url': PROD_URL, 'supabase-prod-key': PROD_KEY },
    })
    await vi.waitFor(() => expect(fetchAllCalendarEvents).toHaveBeenCalled())
  })

  it('renders the calendar with no application chrome', () => {
    const { container } = render(CalendarElement, {
      props: { 'supabase-prod-url': PROD_URL, 'supabase-prod-key': PROD_KEY },
    })
    expect(container.querySelector('.calendar-view')).not.toBeNull()
    expect(container.querySelector('.app-header')).toBeNull()
    expect(container.querySelector('.sidebar')).toBeNull()
  })

  it('applies asset-base so the organizer marks resolve off the site root', () => {
    render(CalendarElement, {
      props: {
        'supabase-prod-url': PROD_URL,
        'supabase-prod-key': PROD_KEY,
        'asset-base': 'https://spws.github.io/ranklist/',
      },
    })
    expect(assetUrl('SPWS-logo.png')).toBe('https://spws.github.io/ranklist/SPWS-logo.png')
  })
})
