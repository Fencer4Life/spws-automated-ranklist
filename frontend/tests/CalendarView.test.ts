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
  url_registration: null,
  dt_registration_deadline: null,
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

  // 11.1 — PEW event card gets evf-circuit class
  it('11.1: PEW event gets evf-circuit class on timeline-event', () => {
    const events = [
      makeEvent({ id_event: 1, txt_code: 'PEW1-2025-2026', txt_name: 'EVF Circuit Stockholm', dt_start: '2026-03-14', enum_status: 'COMPLETED', bool_has_international: true }),
    ]
    const { container } = render(CalendarView, {
      props: { events, showEvfToggle: true },
    })
    // Click +EVF to show international
    const evfBtn = Array.from(container.querySelectorAll('.scope-filter-btn')).find(b => b.textContent?.trim() === '+EVF')
    evfBtn && fireEvent.click(evfBtn)
    const card = container.querySelector('.timeline-event.evf-circuit')
    expect(card).not.toBeNull()
  })

  // 11.2 — IMEW event card gets evf-intl class
  it('11.2: IMEW event gets evf-intl class on timeline-event', () => {
    const events = [
      makeEvent({ id_event: 1, txt_code: 'IMEW-2025-2026', txt_name: 'European Champs', dt_start: '2026-05-14', enum_status: 'PLANNED', bool_has_international: true }),
    ]
    const { container } = render(CalendarView, {
      props: { events, showEvfToggle: true },
    })
    const evfBtn = Array.from(container.querySelectorAll('.scope-filter-btn')).find(b => b.textContent?.trim() === '+EVF')
    evfBtn && fireEvent.click(evfBtn)
    const card = container.querySelector('.timeline-event.evf-intl')
    expect(card).not.toBeNull()
  })

  // 11.3 — MSW event card gets evf-intl class (same as IMEW)
  it('11.3: MSW event gets evf-intl class on timeline-event', () => {
    const events = [
      makeEvent({ id_event: 1, txt_code: 'MSW-2025-2026', txt_name: 'World Championships', dt_start: '2026-10-15', enum_status: 'PLANNED', bool_has_international: true }),
    ]
    const { container } = render(CalendarView, {
      props: { events, showEvfToggle: true },
    })
    const evfBtn = Array.from(container.querySelectorAll('.scope-filter-btn')).find(b => b.textContent?.trim() === '+EVF')
    evfBtn && fireEvent.click(evfBtn)
    const card = container.querySelector('.timeline-event.evf-intl')
    expect(card).not.toBeNull()
  })

  // 11.4 — PPW event card has no evf class
  it('11.4: PPW event has no evf-circuit or evf-intl class', () => {
    const events = [
      makeEvent({ id_event: 1, txt_code: 'PP1-2025-2026', enum_status: 'COMPLETED', dt_start: '2025-09-28' }),
    ]
    const { container } = render(CalendarView, { props: { events } })
    const card = container.querySelector('.timeline-event')
    expect(card).not.toBeNull()
    expect(card!.classList.contains('evf-circuit')).toBe(false)
    expect(card!.classList.contains('evf-intl')).toBe(false)
  })

  // 11.5 — Slot box shows city name from txt_location
  it('11.5: slot box shows city name', () => {
    const events = [
      makeEvent({ id_event: 1, txt_code: 'PP1-2025-2026', enum_status: 'COMPLETED', dt_start: '2025-09-28', txt_location: 'Konin' }),
    ]
    const { container } = render(CalendarView, {
      props: { events, isActiveSeason: true },
    })
    const city = container.querySelector('.slot-city')
    expect(city).not.toBeNull()
    expect(city!.textContent).toBe('Konin')
  })

  // 11.6 — Slot type classes: PEW slot gets pew class
  it('11.6: PEW slot gets pew type class', () => {
    const events = [
      makeEvent({ id_event: 1, txt_code: 'PEW1-2025-2026', enum_status: 'COMPLETED', dt_start: '2025-10-15', bool_has_international: true }),
    ]
    const { container } = render(CalendarView, {
      props: { events, isActiveSeason: true, showEvfToggle: true },
    })
    // Click +EVF
    const evfBtn = Array.from(container.querySelectorAll('.scope-filter-btn')).find(b => b.textContent?.trim() === '+EVF')
    evfBtn && fireEvent.click(evfBtn)
    const slot = container.querySelector('.slot.pew')
    expect(slot).not.toBeNull()
  })

  // 8.21 — Registration link + deadline shown when both set and today <= deadline
  it('8.21: shows registration link and deadline when both set and before deadline', () => {
    const futureDate = new Date()
    futureDate.setMonth(futureDate.getMonth() + 2)
    const futureStr = futureDate.toISOString().slice(0, 10)
    const futureStartStr = new Date(futureDate.getTime() + 30 * 86400000).toISOString().slice(0, 10)
    const events = [makeEvent({
      id_event: 99, dt_start: futureStartStr, enum_status: 'SCHEDULED',
      url_registration: 'https://example.com/register',
      dt_registration_deadline: futureStr,
    })]
    const { container } = render(CalendarView, { props: { events } })
    const regLink = container.querySelector('.registration-link')
    expect(regLink).not.toBeNull()
    expect(regLink!.getAttribute('href')).toBe('https://example.com/register')
    const deadline = container.querySelector('.registration-deadline')
    expect(deadline).not.toBeNull()
  })

  // 8.22 — Registration link only shown (no deadline) when URL set and today <= dt_start
  it('8.22: shows registration link without deadline when only URL set and before dt_start', () => {
    const futureStart = new Date()
    futureStart.setMonth(futureStart.getMonth() + 2)
    const futureStartStr = futureStart.toISOString().slice(0, 10)
    const events = [makeEvent({
      id_event: 99, dt_start: futureStartStr, enum_status: 'SCHEDULED',
      url_registration: 'https://example.com/register',
      dt_registration_deadline: null,
    })]
    const { container } = render(CalendarView, { props: { events } })
    const regLink = container.querySelector('.registration-link')
    expect(regLink).not.toBeNull()
    const deadline = container.querySelector('.registration-deadline')
    expect(deadline).toBeNull()
  })

  // 8.23 — Registration deadline text shown without link when only deadline set
  it('8.23: shows deadline text without link when only deadline set', () => {
    const futureDate = new Date()
    futureDate.setMonth(futureDate.getMonth() + 2)
    const futureStr = futureDate.toISOString().slice(0, 10)
    const events = [makeEvent({
      id_event: 99, dt_start: futureStr, enum_status: 'SCHEDULED',
      url_registration: null,
      dt_registration_deadline: futureStr,
    })]
    const { container } = render(CalendarView, { props: { events } })
    const regLink = container.querySelector('.registration-link')
    expect(regLink).toBeNull()
    const deadline = container.querySelector('.registration-deadline')
    expect(deadline).not.toBeNull()
  })

  // 8.24 — Nothing shown when both null
  it('8.24: shows no registration block when both fields are null', () => {
    const events = [makeEvent({
      id_event: 99, enum_status: 'SCHEDULED',
      url_registration: null, dt_registration_deadline: null,
    })]
    const { container } = render(CalendarView, { props: { events } })
    expect(container.querySelector('.registration-link')).toBeNull()
    expect(container.querySelector('.registration-deadline')).toBeNull()
  })

  // 8.26 — Registration block green when 7+ days remain, red when < 7 days
  it('8.26: registration block has reg-urgent class when < 7 days remain', () => {
    const soon = new Date()
    soon.setDate(soon.getDate() + 3)
    const soonStr = soon.toISOString().slice(0, 10)
    const farStart = new Date()
    farStart.setDate(farStart.getDate() + 30)
    const farStartStr = farStart.toISOString().slice(0, 10)
    const events = [makeEvent({
      id_event: 99, dt_start: farStartStr, enum_status: 'SCHEDULED',
      url_registration: 'https://example.com/register',
      dt_registration_deadline: soonStr,
    })]
    const { container } = render(CalendarView, { props: { events } })
    const regBlock = container.querySelector('.timeline-registration')
    expect(regBlock).not.toBeNull()
    expect(regBlock!.classList.contains('reg-urgent')).toBe(true)
  })

  it('8.26b: registration block has no reg-urgent class when 7+ days remain', () => {
    const far = new Date()
    far.setDate(far.getDate() + 14)
    const farStr = far.toISOString().slice(0, 10)
    const farStart = new Date()
    farStart.setDate(farStart.getDate() + 30)
    const farStartStr = farStart.toISOString().slice(0, 10)
    const events = [makeEvent({
      id_event: 99, dt_start: farStartStr, enum_status: 'SCHEDULED',
      url_registration: 'https://example.com/register',
      dt_registration_deadline: farStr,
    })]
    const { container } = render(CalendarView, { props: { events } })
    const regBlock = container.querySelector('.timeline-registration')
    expect(regBlock).not.toBeNull()
    expect(regBlock!.classList.contains('reg-urgent')).toBe(false)
  })

  // 8.25 — Nothing shown when deadline/dt_start has passed
  it('8.25: hides registration when deadline has passed', () => {
    const events = [makeEvent({
      id_event: 99, dt_start: '2020-01-01', enum_status: 'COMPLETED',
      url_registration: 'https://example.com/register',
      dt_registration_deadline: '2019-12-20',
    })]
    const { container } = render(CalendarView, { props: { events } })
    expect(container.querySelector('.registration-link')).toBeNull()
    expect(container.querySelector('.registration-deadline')).toBeNull()
  })

  // 11.8 — Season dropdown renders in calendar-filters when seasons provided
  it('11.8: renders season dropdown in calendar filters when seasons provided', () => {
    const seasons = [
      { id_season: 1, txt_code: 'SPWS-2024-2025', dt_start: '2024-09-01', dt_end: '2025-06-30', bool_active: false },
      { id_season: 2, txt_code: 'SPWS-2025-2026', dt_start: '2025-09-01', dt_end: '2026-06-30', bool_active: true },
    ]
    const { container } = render(CalendarView, {
      props: { events: EVENTS, seasons, selectedSeasonId: 2 },
    })
    const filters = container.querySelector('.calendar-filters')
    expect(filters).not.toBeNull()
    const seasonSelect = filters!.querySelector('.season-select')
    expect(seasonSelect).not.toBeNull()
    expect(seasonSelect!.textContent).toContain('SPWS-2025-2026')
  })
})
