// A render failure inside the calendar must not take the application with it.
//
// Until 2026-09-02 it did. A throw out of a `$derived` in CalendarBarrel tore
// down the whole component tree: the calendar stopped, and so did the header,
// the navigation and the hamburger, because they are all children of the same
// root. The page stayed live — the main thread was never blocked and clicks
// still arrived — it simply had nothing left listening to them, and only a
// reload brought it back. That is a far worse failure than a broken calendar,
// and it is the part worth guarding permanently: the specific crash is fixed
// (CalendarBarrel CB.30–CB.32), but the next one should be survivable.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))

// The calendar throws on render, standing in for any future defect in it.
vi.mock('../src/components/CalendarView.svelte', () => ({
  default: () => { throw new Error('calendar exploded') },
}))

import App from '../src/App.svelte'

describe('App — a calendar that fails to render', () => {
  function renderApp() {
    return render(App, {
      props: { 'supabase-cert-url': 'https://cert.supabase.co', 'supabase-cert-key': 'k' },
    })
  }

  it('CBD.1: shows the calendar as failed instead of taking the page down', async () => {
    const { container, getByText } = renderApp()
    await fireEvent.click([...container.querySelectorAll('button')].find((b) => /Kalendarz|Calendar/.test(b.textContent ?? ''))!)
    expect(container.querySelector('.calendar-failed')).not.toBeNull()
    expect(getByText(/calendar exploded/)).toBeTruthy()
  })

  it('CBD.2: leaves the rest of the application working', async () => {
    const { container } = renderApp()
    await fireEvent.click([...container.querySelectorAll('button')].find((b) => /Kalendarz|Calendar/.test(b.textContent ?? ''))!)
    // The hamburger was the clearest symptom on PROD: dead alongside everything
    // else. It must still open the sidebar with the calendar broken.
    const hamburger = container.querySelector('.hamburger-btn') as HTMLElement
    expect(hamburger).not.toBeNull()
    await fireEvent.click(hamburger)
    expect(container.querySelector('.sidebar.open')).not.toBeNull()
  })
})
