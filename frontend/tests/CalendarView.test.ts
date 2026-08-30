// CalendarView — the calendar ORCHESTRATOR (ADR-084). Test IDs CV.1–CV.14.
//
// The 659-line timeline this replaced carried 49 tests. Every one has a
// recorded decision below; none was dropped silently.
//
// MOVED to the pure module or the components (the behaviour survives, the
// assertion moved to where it can be made without mounting):
//   cancelled 7-day notice window ............ CQ.15, CQ.16
//   CREATED skeletons hidden ................. CQ.14
//   international detection + PPW scope ...... CQ.19–CQ.23
//   next-upcoming derived from filtered set .. CQ.26
//   registration/entry-list visibility rules . CQ.27–CQ.35, EC.20–EC.24
//   fee tiers and currency fallback .......... EC.15–EC.19
//   status + awaiting-results badge .......... EC.27
//   results and invitation links ............. EC.25, EC.29, EC.30
//   date / name / location rendering ......... EC.1–EC.11
//   event-type classes (evf-circuit etc.) .... CQ.11–CQ.13, CB.11, CB.12
//   code prefix normalisation ................ CQ.57, CQ.58
//
// DELETED as retired mechanisms (ADR-084 replaces them; nothing to re-home):
//   reverse-chronological order, month grouping and month headers — the drum
//     is quantised into rows and runs ascending (CQ.1–CQ.4).
//   past/future/all time filter — "the drum IS the time control" (ADR-084).
//   season dropdown — the barrel owns season state, the seam carries the code.
//   .timeline-event / .timeline-links block layout — markup no longer exists.
//   R.23, R.24, R.25 rolling-progress slots — retired by ADR-084 and recorded
//     as an amendment to ADR-018, which pinned .rolling-progress/.slot.
//   tournament count on the tile — the card drops the field (its unpluralised
//     string is a live defect tracked separately).
//
// What is left here is what only the orchestrator can be responsible for:
// wiring the three children together, and the scope control it owns.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'
import CalendarView from '../src/components/CalendarView.svelte'
import type { CalendarEvent } from '../src/lib/types'

// ADR-079 amend — the SPWS-hosted registration/entry-list links open an
// in-app RegistrationModal (which fetches via api.ts) instead of navigating.
vi.mock('../src/lib/api', () => ({
  fetchEventForRegistration: vi.fn(),
  matchRegistrationFencer: vi.fn(),
  createRegistration: vi.fn(),
  fetchEntryList: vi.fn(),
}))
import { fetchEventForRegistration, fetchEntryList } from '../src/lib/api'

const mockFetchEvent = vi.mocked(fetchEventForRegistration)
const mockFetchEntryList = vi.mocked(fetchEntryList)

beforeEach(() => {
  vi.clearAllMocks()
})

const makeEvent = (overrides: Partial<CalendarEvent> = {}): CalendarEvent => ({
  id_event: 1,
  txt_code: 'PPW1-2024-2025',
  txt_name: 'I Puchar Polski Weteranów',
  id_season: 1,
  txt_season_code: 'SPWS-2024-2025',
  txt_location: 'Konin',
  txt_country: 'Polska',
  id_organizer: null,
  txt_organizer_name: null,
  txt_venue_address: null,
  url_invitation: null,
  num_entry_fee: null,
  txt_entry_fee_currency: null,
  dt_start: '2024-09-28',
  dt_end: '2024-09-28',
  arr_weapons: [],
  url_event: null,
  enum_status: 'COMPLETED',
  num_tournaments: 5,
  bool_has_international: false,
  url_registration: null,
  dt_registration_deadline: null,
  url_event_2: null,
  url_event_3: null,
  url_event_4: null,
  url_event_5: null,
  ...overrides,
})

/**
 * Dates are computed from the run date, not hardcoded.
 *
 * The barrel fills every row between the first and last event (CQ.4), so a
 * 2099 fixture would build ~300 rows and assert nothing extra. Relative dates
 * keep the model small AND stop the suite from silently changing meaning as
 * real time passes a hardcoded boundary.
 */
function monthsOut(months: number): string {
  const d = new Date()
  d.setDate(15)
  d.setMonth(d.getMonth() + months)
  return d.toISOString().slice(0, 10)
}

/**
 * Three dates inside one future MONTH, so the anchor row has three panels.
 *
 * This used to spread them across the three months of a quarter, which landed
 * them in a single quarter row. Under monthly seams that would put each event
 * in a row of its own and leave the focused row with one panel.
 */
function futureMonth(): [string, string, string] {
  const d = new Date()
  d.setDate(1)
  d.setMonth(d.getMonth() + 4)
  const stamp = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  return [`${stamp}-07`, `${stamp}-14`, `${stamp}-21`]
}

const [F1, F2, F3] = futureMonth()

const EVENTS: CalendarEvent[] = [
  makeEvent({ id_event: 1, txt_code: 'PPW1-2025-2026', txt_name: 'Puchar Konin', dt_start: monthsOut(-8) }),
  makeEvent({
    id_event: 2, txt_code: 'PEW1-2025-2026', txt_name: 'EVF Budapeszt',
    dt_start: monthsOut(-5), bool_has_international: true,
  }),
  makeEvent({
    id_event: 3, txt_code: 'PPW4-2026-2027', txt_name: 'Puchar Gdansk',
    dt_start: F1, dt_end: F1, enum_status: 'SCHEDULED',
  }),
  makeEvent({
    id_event: 4, txt_code: 'PEW7-2026-2027', txt_name: 'EVF Wieden',
    dt_start: F2, dt_end: F2, enum_status: 'SCHEDULED', bool_has_international: true,
  }),
  makeEvent({
    id_event: 5, txt_code: 'PPW5-2026-2027', txt_name: 'Puchar Krakow',
    dt_start: F3, dt_end: F3, enum_status: 'SCHEDULED',
  }),
]

const panels = (c: HTMLElement) => c.querySelectorAll('.p')
const midPanels = (c: HTMLElement) => c.querySelectorAll('.ln.mid .p')
const cardName = (c: HTMLElement) => c.querySelector('.cnm')?.textContent?.trim() ?? null

describe('CalendarView orchestrator (ADR-084)', () => {
  // CV.1 — the whole point of the rewrite: it holds state and mounts children.
  it('CV.1: renders the barrel and a card for the opening selection', () => {
    const { container } = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })
    expect(container.querySelector('.vp')).not.toBeNull()
    expect(container.querySelector('.card')).not.toBeNull()
    // findNextUpcoming picks the earliest future event, which is F1.
    expect(cardName(container)).toBe('Puchar Gdansk')
  })

  // CV.2 / CV.3 — the scope segment is the one control that survived, and it
  // only appears when the season config turns it on.
  it('CV.2: hides the scope segment when showEvfToggle is false', () => {
    const { container } = render(CalendarView, { props: { events: EVENTS } })
    expect(container.querySelectorAll('.scope-filter-btn').length).toBe(0)
  })

  it('CV.3: shows the scope segment when showEvfToggle is true', () => {
    const { container } = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })
    expect(container.querySelectorAll('.scope-filter-btn').length).toBe(2)
  })

  // CV.4 — ADR-044 amend. The flag arrives async, so the default has to re-sync
  // rather than being fixed at mount.
  it('CV.4: defaults to the richer EVF+FIE view when the flag is on', () => {
    const { container } = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })
    expect(panels(container).length).toBe(5)
    const evf = [...container.querySelectorAll('.scope-filter-btn')]
      .find((b) => b.textContent?.trim() === '+EVF')
    expect(evf!.classList.contains('active')).toBe(true)
  })

  it('CV.5: shows domestic events only when the flag is off', () => {
    const { container } = render(CalendarView, { props: { events: EVENTS } })
    expect(panels(container).length).toBe(3)
  })

  // CV.6 — picking PPW explicitly must stick, and must drop the EVF events.
  it('CV.6: switching to PPW drops the international events', async () => {
    const { container } = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })
    expect(panels(container).length).toBe(5)

    const ppw = [...container.querySelectorAll('.scope-filter-btn')]
      .find((b) => b.textContent?.trim() === 'PPW')!
    await fireEvent.click(ppw)

    expect(panels(container).length).toBe(3)
    expect(ppw.classList.contains('active')).toBe(true)
  })

  it('CV.7: rebuilds when the events prop changes', async () => {
    const { container, rerender } = render(CalendarView, {
      props: { events: EVENTS, showEvfToggle: true },
    })
    expect(panels(container).length).toBe(5)

    await rerender({ events: [EVENTS[0]!], showEvfToggle: true })
    expect(panels(container).length).toBe(1)
  })

  // CV.8 — the wiring the orchestrator exists for: the barrel reports a
  // selection and the card follows it.
  it('CV.8: swaps the card when a panel is selected', async () => {
    const { container } = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })
    const row = midPanels(container)
    expect(row.length).toBe(3)
    expect(cardName(container)).toBe('Puchar Gdansk')

    await fireEvent.click(row[1]!)
    expect(cardName(container)).toBe('EVF Wieden')
  })

  // CV.9 — a selection can outlive the model that produced it. Switching to PPW
  // removes the selected EVF event; the card must fall back rather than render
  // an event the barrel no longer shows.
  it('CV.9: falls back when the selection leaves the model', async () => {
    const { container } = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })
    await fireEvent.click(midPanels(container)[1]!)
    expect(cardName(container)).toBe('EVF Wieden')

    const ppw = [...container.querySelectorAll('.scope-filter-btn')]
      .find((b) => b.textContent?.trim() === 'PPW')!
    await fireEvent.click(ppw)

    expect(cardName(container)).toBe('Puchar Gdansk')
  })

  it('CV.10: renders the empty state when nothing is visible', () => {
    const { container } = render(CalendarView, { props: { events: [] } })
    expect(container.querySelector('.no-events')).not.toBeNull()
    expect(container.querySelector('.vp')).toBeNull()
  })

  // CV.11 — activeEnv is $bindable and App re-points the Supabase client from
  // it, so dropping the env toggle fails only at runtime.
  it('CV.11: shows the CERT/PROD toggle only when dualEnv is set', () => {
    const off = render(CalendarView, { props: { events: EVENTS } })
    expect(off.container.querySelector('.calendar-footer')).toBeNull()

    const on = render(CalendarView, { props: { events: EVENTS, dualEnv: true } })
    const btns = on.container.querySelectorAll('.env-btn')
    expect([...btns].map((b) => b.textContent?.trim())).toEqual(['CT', 'PD'])
  })

  // CV.11b — both segments share one footer row, scope first. Pinned because
  // the ordering is the requirement, not an accident of markup order.
  it('CV.11b: puts the scope segment left of the env toggle in one footer row', () => {
    const { container } = render(CalendarView, {
      props: { events: EVENTS, showEvfToggle: true, dualEnv: true },
    })
    const footer = container.querySelector('.calendar-footer')!
    expect(footer).not.toBeNull()
    // Svelte appends a scoped-style hash to className, so compare first tokens.
    const kids = [...footer.children].map((e) => e.classList[0])
    expect(kids).toEqual(['scope-filters', 'env-toggle'])
    // and the scope segment still renders without the env toggle
    const scopeOnly = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })
    expect(scopeOnly.container.querySelectorAll('.scope-filter-btn').length).toBe(2)
    expect(scopeOnly.container.querySelector('.env-toggle')).toBeNull()
  })

  // ADR-079 amend — the modal wiring moved from the timeline row to the card,
  // but the orchestrator still owns the modal. EC.24 covers the card emitting;
  // these cover the orchestrator acting on it.
  function spwsEvent(overrides: Partial<CalendarEvent> = {}) {
    return makeEvent({
      id_event: 99, txt_code: 'PPW4-2026-2027', dt_start: F1, dt_end: F1,
      enum_status: 'SCHEDULED',
      url_registration: 'https://host/register.html?event=PPW4-2026-2027',
      url_entry_list: 'https://host/register.html?event=PPW4-2026-2027&view=list',
      dt_registration_deadline: F1,
      bool_use_spws_registration: true,
      ...overrides,
    })
  }

  it('CV.12: opens the registration modal from the card instead of navigating', async () => {
    mockFetchEvent.mockResolvedValue(null)
    const { container, findByText } = render(CalendarView, { props: { events: [spwsEvent()] } })
    await fireEvent.click(container.querySelector('.registration-link') as HTMLAnchorElement)
    await findByText(/Nie znaleziono wydarzenia/)
    expect(container.querySelector('.modal-overlay')).not.toBeNull()
    expect(mockFetchEvent).toHaveBeenCalledWith('PPW4-2026-2027')
  })

  it('CV.13: opens the modal in list view from the entry-list link', async () => {
    mockFetchEntryList.mockResolvedValue([])
    const { container } = render(CalendarView, { props: { events: [spwsEvent()] } })
    await fireEvent.click(container.querySelector('.entry-list-link') as HTMLAnchorElement)
    await waitFor(() => expect(container.querySelector('.el-card')).not.toBeNull())
    expect(mockFetchEntryList).toHaveBeenCalledWith(99)
  })

  it('CV.14: closing the modal returns to the calendar', async () => {
    mockFetchEvent.mockResolvedValue(null)
    const { container, findByText } = render(CalendarView, { props: { events: [spwsEvent()] } })
    await fireEvent.click(container.querySelector('.registration-link') as HTMLAnchorElement)
    await findByText(/Nie znaleziono wydarzenia/)

    await fireEvent.click(container.querySelector('.modal-overlay') as HTMLElement)
    expect(container.querySelector('.modal-overlay')).toBeNull()
    expect(container.querySelector('.card')).not.toBeNull()
  })
})
