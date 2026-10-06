// The calendar's title is its menu name, squeezed by MEASURED fit (D5).
// ADR-090 amendment 2026-10-06; FR-148 as amended. Test IDs TITLE.01–TITLE.02.
// Plan: doc/plans/kalendarz-beben-strzalki-plan-2026-10-06.html §2.7.
//
// The title unfolds to „Znajdź zawody" / "Competition Finder" wherever it fits
// and squeezes to „Zawody" ("Competitions", then "Events") only for lack of
// room — the room the title actually has, not a screen width. jsdom lays
// nothing out, so TITLE.02 stubs the widths; the browser measures them for
// real in WP.BAR.05.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render } from '@testing-library/svelte'
import { tick, type ComponentProps } from 'svelte'

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  fetchScoringEngines: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchRankingFull: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchScoringConfig: vi.fn().mockResolvedValue(null),
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))

import App from '../src/App.svelte'
import { pickTitle } from '../src/lib/fitTitle'
import { setLocale } from '../src/lib/locale.svelte'

describe('TITLE.01 — pickTitle', () => {
  const widths = [180, 120, 60]

  it('returns the first candidate that fits', () => {
    expect(pickTitle(widths, 500)).toBe(0)
    expect(pickTitle(widths, 150)).toBe(1)
    expect(pickTitle(widths, 100)).toBe(2)
  })

  it('returns the last candidate when none fits', () => {
    expect(pickTitle(widths, 30)).toBe(2)
    expect(pickTitle(widths, 0)).toBe(2)
  })

  it('a candidate exactly as wide as the room fits', () => {
    expect(pickTitle(widths, 180)).toBe(0)
    expect(pickTitle(widths, 179.9)).toBe(1)
    expect(pickTitle(widths, 120)).toBe(1)
  })

  it('a single candidate is always the one shown', () => {
    expect(pickTitle([400], 10)).toBe(0)
  })
})

describe('TITLE.02 — the title is picked again on a language switch', () => {
  // 10 px per character, and a fixed room: what a browser would measure.
  const PX = 10
  let own: PropertyDescriptor | undefined
  let room = 150

  beforeEach(() => {
    setLocale('pl')
    own = Object.getOwnPropertyDescriptor(Element.prototype, 'getBoundingClientRect')
    Object.defineProperty(Element.prototype, 'getBoundingClientRect', {
      configurable: true,
      value(this: Element) {
        const box = (width: number) => ({ width, height: 20, top: 0, left: 0, right: width, bottom: 20, x: 0, y: 0, toJSON() {} })
        if (this.closest('.title-measure')) return box((this.textContent ?? '').length * PX)
        if (this.matches('.site-title')) return box(room)
        // github.io: the header's room is what is left after its other items.
        if (this.matches('.app-header')) return box(room + 130)
        if (this.matches('.app-header .hamburger-btn')) return box(30)
        if (this.matches('.app-header .header-right')) return box(60)
        if (this.matches('.app-header .header-logo')) return box(40)
        return box(0)
      },
    })
  })

  afterEach(() => {
    if (own) Object.defineProperty(Element.prototype, 'getBoundingClientRect', own)
    setLocale('pl')
  })

  const shown = (container: HTMLElement) =>
    (container.querySelector('.site-title-fit') ?? container.querySelector('.app-title-fit'))?.textContent?.trim()

  const BARS: Record<string, ComponentProps<typeof App>> = {
    'WordPress bar': {
      'supabase-prod-url': 'https://prod.supabase.co',
      'supabase-prod-key': 'prod-key',
      chrome: 'site',
      view: 'calendar',
      'href-home': 'https://weteraniszermierki.pl/',
    },
    'github.io header': {
      'supabase-cert-url': 'https://cert.supabase.co',
      'supabase-cert-key': 'cert-key',
      view: 'calendar',
    },
  }

  for (const [name, props] of Object.entries(BARS)) {
    it(`${name}: full name in Polish, then the first English candidate that fits`, async () => {
      room = 150
      const { container } = render(App, { props })
      await tick()
      expect(shown(container)).toBe('Znajdź zawody') // 130 px of 150
      setLocale('en')
      await tick()
      expect(shown(container)).toBe('Competitions') // 180 px does not fit; 120 px does
      setLocale('pl')
      await tick()
      expect(shown(container)).toBe('Znajdź zawody')
    })

    it(`${name}: with less room, „Zawody" and "Events"`, async () => {
      room = 100
      const { container } = render(App, { props })
      await tick()
      expect(shown(container)).toBe('Zawody')
      setLocale('en')
      await tick()
      expect(shown(container)).toBe('Events')
    })
  }
})
