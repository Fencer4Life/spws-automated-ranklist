// Plan tests: 8.38, 8.39, 8.40, 8.41, 8.42, 8.43, 8.44, 8.45, 8.46, 8.47, 8.76, 8.77
// See doc/m8_implementation_plan.md §T8.5.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import CalendarView from '../src/components/CalendarView.svelte'
import type { CalendarEvent } from '../src/lib/types'

const makeEvent = (overrides: Partial<CalendarEvent> = {}): CalendarEvent => ({
  id_event: 1,
  txt_code: 'PP1-2024-2025',
  txt_name: 'I Puchar Polski Weteranów',
  id_season: 1,
  txt_season_code: 'SPWS-2024-2025',
  txt_location: 'Konin',
  txt_country: 'Polska',
  txt_venue_address: null,
  url_invitation: null,
  num_entry_fee: null,
  txt_entry_fee_currency: null,
  dt_start: '2024-09-28',
  dt_end: '2024-09-28',
  url_event: null,
  enum_status: 'COMPLETED',
  num_tournaments: 5,
  bool_has_international: false,
  ...overrides,
})

const EVENTS: CalendarEvent[] = [
  makeEvent({
    id_event: 1,
    txt_code: 'PP1-2024-2025',
    txt_name: 'I Puchar Polski Weteranów',
    dt_start: '2024-09-28',
    txt_location: 'Konin',
    enum_status: 'COMPLETED',
    num_tournaments: 5,
    bool_has_international: false,
  }),
  makeEvent({
    id_event: 2,
    txt_code: 'PP2-2024-2025',
    txt_name: 'II Puchar Polski Weteranów',
    dt_start: '2024-10-25',
    txt_location: 'Kraków',
    enum_status: 'COMPLETED',
    num_tournaments: 8,
    bool_has_international: false,
  }),
  makeEvent({
    id_event: 3,
    txt_code: 'PEW1-2024-2025',
    txt_name: 'EVF Grand Prix 1 — Budapeszt',
    dt_start: '2024-10-15',
    txt_location: 'Budapeszt',
    enum_status: 'COMPLETED',
    num_tournaments: 10,
    bool_has_international: true,
    url_invitation: 'https://example.com/invite',
    url_event: 'https://example.com/results',
    num_entry_fee: 50,
    txt_entry_fee_currency: 'EUR',
  }),
  makeEvent({
    id_event: 4,
    txt_code: 'PP4-2025-2026',
    txt_name: 'IV Puchar Polski Weteranów',
    dt_start: '2026-04-15',
    txt_location: 'Gdańsk',
    enum_status: 'SCHEDULED',
    num_tournaments: 6,
    bool_has_international: false,
  }),
]

describe('CalendarView (T8.5)', () => {
  // 8.38 — Renders events in reverse chronological order (future first)
  it('renders events in reverse chronological order', () => {
    const { container } = render(CalendarView, { props: { events: EVENTS } })
    const items = container.querySelectorAll('.timeline-event')
    expect(items.length).toBeGreaterThanOrEqual(3)
    // First item should be April (latest / most future)
    expect(items[0].textContent).toContain('IV Puchar Polski')
  })

  // 8.39 — Groups events by month with month headers
  it('groups events by month with month headers', () => {
    const { container } = render(CalendarView, { props: { events: EVENTS } })
    const monthHeaders = container.querySelectorAll('.timeline-month')
    expect(monthHeaders.length).toBeGreaterThanOrEqual(2)
  })

  // 8.40 — Event card shows date, name, location, tournament count
  it('shows date, name, location, tournament count on timeline event', () => {
    const { container } = render(CalendarView, {
      props: { events: [EVENTS[0]] },
    })
    const item = container.querySelector('.timeline-event')
    expect(item).not.toBeNull()
    expect(item!.textContent).toContain('I Puchar Polski')
    expect(item!.textContent).toContain('Konin')
    expect(item!.textContent).toContain('5')
  })

  // 8.41 — Status badge color-coded
  it('renders color-coded status badge', () => {
    const { container } = render(CalendarView, {
      props: { events: [EVENTS[0]] },
    })
    const badge = container.querySelector('.status-badge')
    expect(badge).not.toBeNull()
    expect(badge!.classList.contains('status-completed')).toBe(true)
  })

  // 8.42 — "Komunikat organizatora" link present when url_invitation set
  it('shows invitation link when url_invitation is set', () => {
    const evt = makeEvent({ url_invitation: 'https://example.com/invite' })
    const { container } = render(CalendarView, {
      props: { events: [evt] },
    })
    const link = container.querySelector('.invitation-link') as HTMLAnchorElement
    expect(link).not.toBeNull()
    expect(link.href).toContain('example.com/invite')
  })

  // 8.43 — "Komunikat organizatora" link absent when url_invitation null
  it('hides invitation link when url_invitation is null', () => {
    const { container } = render(CalendarView, {
      props: { events: [EVENTS[0]] },
    })
    const link = container.querySelector('.invitation-link')
    expect(link).toBeNull()
  })

  // 8.44 — Past/future/all toggle filters events relative to today
  it('filters events by past/future/all toggle', async () => {
    const { container } = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })

    // Default: PPW scope — international event filtered out
    let items = container.querySelectorAll('.timeline-event')
    expect(items.length).toBe(3)

    // Select "future" filter
    const select = container.querySelector('.time-filter-select') as HTMLSelectElement
    expect(select).not.toBeNull()
    await fireEvent.change(select, { target: { value: 'future' } })

    // Only future events (dt_start > today 2026-03-27)
    items = container.querySelectorAll('.timeline-event')
    expect(items.length).toBe(1)
    expect(items[0].textContent).toContain('IV Puchar Polski')
  })

  // 8.45 — PPW shows domestic only; +EVF shows all events
  it('PPW mode hides international events; +EVF shows all', async () => {
    const { container } = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })

    // Click PPW filter
    const modeBtns = container.querySelectorAll('.scope-filter-btn')
    const ppwBtn = Array.from(modeBtns).find((btn) =>
      btn.textContent?.trim() === 'PPW',
    )
    expect(ppwBtn).not.toBeUndefined()
    await fireEvent.click(ppwBtn!)

    // Only domestic events (3 out of 4)
    let items = container.querySelectorAll('.timeline-event')
    expect(items.length).toBe(3)

    // Click +EVF filter
    const evfBtn = Array.from(modeBtns).find((btn) =>
      btn.textContent?.trim() === '+EVF',
    )
    await fireEvent.click(evfBtn!)

    // All events shown
    items = container.querySelectorAll('.timeline-event')
    expect(items.length).toBe(4)
  })

  // 8.46 — Mobile layout: cards stack at 375px viewport
  it('renders timeline events as block elements (stackable)', () => {
    const { container } = render(CalendarView, {
      props: { events: [EVENTS[0]] },
    })
    const item = container.querySelector('.timeline-event')
    expect(item).not.toBeNull()
    expect(item!.tagName).toBe('DIV')
  })

  // 8.76 — Results link shown when COMPLETED + url_event set
  it('shows results link when event is completed and url_event is set', () => {
    const evt = makeEvent({ enum_status: 'COMPLETED', url_event: 'https://example.com/results' })
    const { container } = render(CalendarView, {
      props: { events: [evt] },
    })
    const link = container.querySelector('.results-link') as HTMLAnchorElement
    expect(link).not.toBeNull()
    expect(link.href).toContain('example.com/results')
  })

  // 8.77 — Results link hidden when not COMPLETED or url_event null
  it('hides results link when event is not completed or url_event is null', () => {
    // SCHEDULED event (no results yet)
    const { container: c1 } = render(CalendarView, {
      props: { events: [EVENTS[3]] }, // SCHEDULED, no url_event
    })
    expect(c1.querySelector('.results-link')).toBeNull()

    // COMPLETED but no url_event
    const { container: c2 } = render(CalendarView, {
      props: { events: [EVENTS[0]] }, // COMPLETED, url_event null
    })
    expect(c2.querySelector('.results-link')).toBeNull()
  })

  // 8.78 — Calendar links stacked vertically
  it('renders event links in a stacked .timeline-links container', () => {
    const evt = makeEvent({ enum_status: 'COMPLETED', url_event: 'https://example.com/results', url_invitation: 'https://example.com/invite' })
    const { container } = render(CalendarView, {
      props: { events: [evt] },
    })
    const linksContainer = container.querySelector('.timeline-links')
    expect(linksContainer).not.toBeNull()
    const links = linksContainer!.querySelectorAll('a')
    expect(links.length).toBe(2)
  })

  // 8.79 — scope filter hidden when showEvfToggle=false (default)
  it('hides scope filter buttons when showEvfToggle is false', () => {
    const { container } = render(CalendarView, { props: { events: EVENTS } })
    const scopeBtns = container.querySelectorAll('.scope-filter-btn')
    expect(scopeBtns.length).toBe(0)
  })

  // 8.80 — scope filter visible when showEvfToggle=true
  it('shows scope filter buttons when showEvfToggle is true', () => {
    const { container } = render(CalendarView, { props: { events: EVENTS, showEvfToggle: true } })
    const scopeBtns = container.querySelectorAll('.scope-filter-btn')
    expect(scopeBtns.length).toBe(2)
  })

  // 8.47 — Season filter changes displayed events (tested via events prop)
  it('updates when events prop changes', () => {
    const { container, rerender } = render(CalendarView, {
      props: { events: EVENTS, showEvfToggle: true },
    })
    // Default PPW scope — international event filtered out
    let items = container.querySelectorAll('.timeline-event')
    expect(items.length).toBe(3)

    // Simulate season change: pass only 1 event
    rerender({ events: [EVENTS[0]] })
    items = container.querySelectorAll('.timeline-event')
    expect(items.length).toBe(1)
  })

  // R.23 — rolling progress bar with slot elements for active season
  it('R.23: shows rolling-progress with slot elements for active season', () => {
    const events = [
      makeEvent({ id_event: 1, txt_code: 'PP1-2025-2026', enum_status: 'COMPLETED', dt_start: '2025-09-28' }),
      makeEvent({ id_event: 2, txt_code: 'PP2-2025-2026', enum_status: 'SCHEDULED', dt_start: '2025-10-26' }),
      makeEvent({ id_event: 3, txt_code: 'MPW-2025-2026', enum_status: 'SCHEDULED', dt_start: '2026-06-07' }),
    ]
    const { container } = render(CalendarView, {
      props: { events, isActiveSeason: true },
    })
    const progress = container.querySelector('.rolling-progress')
    expect(progress).not.toBeNull()
    const slots = progress!.querySelectorAll('.slot')
    expect(slots.length).toBe(3)
  })

  // R.24 — no rolling progress for non-active season
  it('R.24: hides rolling-progress for non-active season', () => {
    const events = [
      makeEvent({ id_event: 1, txt_code: 'PP1-2025-2026', enum_status: 'COMPLETED', dt_start: '2025-09-28' }),
    ]
    const { container } = render(CalendarView, {
      props: { events, isActiveSeason: false },
    })
    expect(container.querySelector('.rolling-progress')).toBeNull()
  })

  // R.25 — correct slot states
  it('R.25: slot states match event statuses (completed/planned)', () => {
    const events = [
      makeEvent({ id_event: 1, txt_code: 'PP1-2025-2026', enum_status: 'COMPLETED', dt_start: '2025-09-28' }),
      makeEvent({ id_event: 2, txt_code: 'PP2-2025-2026', enum_status: 'COMPLETED', dt_start: '2025-10-26' }),
      makeEvent({ id_event: 3, txt_code: 'PP3-2025-2026', enum_status: 'SCHEDULED', dt_start: '2025-11-30' }),
      makeEvent({ id_event: 4, txt_code: 'MPW-2025-2026', enum_status: 'SCHEDULED', dt_start: '2026-06-07' }),
    ]
    const { container } = render(CalendarView, {
      props: { events, isActiveSeason: true },
    })
    const completedSlots = container.querySelectorAll('.slot.completed')
    const plannedSlots = container.querySelectorAll('.slot.planned')
    expect(completedSlots.length).toBe(2)
    expect(plannedSlots.length).toBe(2)
  })
})
