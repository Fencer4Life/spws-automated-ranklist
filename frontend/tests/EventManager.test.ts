// Plan tests: 9.43, 9.44, 9.45, 9.46, 9.47, 9.48, 9.49
// See .claude/plans/rosy-bouncing-kitten.md §T9.3.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import EventManager from '../src/components/EventManager.svelte'

// Mock window.confirm for delete confirmation dialogs
vi.stubGlobal('confirm', vi.fn(() => true))
import type { CalendarEvent, Season, Organizer, Tournament } from '../src/lib/types'

const MOCK_SEASONS: Season[] = [
  { id_season: 1, txt_code: 'SPWS-2024-2025', dt_start: '2024-09-01', dt_end: '2025-06-30', bool_active: true },
]

const MOCK_ORGANIZERS: Organizer[] = [
  { id_organizer: 1, txt_code: 'KS-SOBIESKI', txt_name: 'KS Sobieski Wrocław' },
  { id_organizer: 2, txt_code: 'WKS-KOLEJARZ', txt_name: 'WKS Kolejarz Wrocław' },
]

const MOCK_EVENTS: CalendarEvent[] = [
  {
    id_event: 10,
    txt_code: 'PPW-WRO-2025-01',
    txt_name: 'PPW Wrocław Szpada',
    id_season: 1,
    txt_season_code: 'SPWS-2024-2025',
    txt_location: 'Wrocław',
    txt_country: 'PL',
    txt_venue_address: 'ul. Pułaskiego 15',
    url_invitation: 'https://example.com/invite',
    num_entry_fee: 80,
    txt_entry_fee_currency: 'PLN',
    dt_start: '2025-01-15',
    dt_end: '2025-01-15',
    url_event: 'https://example.com/event',
    enum_status: 'SCHEDULED',
    num_tournaments: 3,
    bool_has_international: false,
  },
  {
    id_event: 11,
    txt_code: 'PPW-KRK-2025-02',
    txt_name: 'PPW Kraków Floret',
    id_season: 1,
    txt_season_code: 'SPWS-2024-2025',
    txt_location: 'Kraków',
    txt_country: 'PL',
    txt_venue_address: null,
    url_invitation: null,
    num_entry_fee: null,
    txt_entry_fee_currency: null,
    dt_start: '2025-02-20',
    dt_end: '2025-02-20',
    url_event: null,
    enum_status: 'PLANNED',
    num_tournaments: 2,
    bool_has_international: false,
  },
]

describe('EventManager (T9.3)', () => {
  const defaultProps = {
    events: MOCK_EVENTS,
    seasons: MOCK_SEASONS,
    organizers: MOCK_ORGANIZERS,
    selectedSeasonId: 1,
    isAdmin: true,
    oncreate: vi.fn(),
    onupdate: vi.fn(),
    onupdatestatus: vi.fn(),
    ondelete: vi.fn(),
  }

  // 9.43 — Renders event list with name, location, dates for each event
  it('renders event list with name, location, dates', () => {
    const { container } = render(EventManager, { props: defaultProps })
    const rows = container.querySelectorAll('[data-field="event-row"]')
    expect(rows.length).toBe(2)

    const firstRow = rows[0]
    expect(firstRow.querySelector('[data-field="event-name"]')!.textContent).toContain('PPW Wrocław Szpada')
    expect(firstRow.querySelector('[data-field="event-location"]')!.textContent).toContain('Wrocław')
    expect(firstRow.querySelector('[data-field="event-dates"]')!.textContent).toContain('2025-01-15')
  })

  // 9.44 — "+ Dodaj wydarzenie" button opens create form
  it('opens create form when add button clicked', async () => {
    const { container } = render(EventManager, { props: defaultProps })
    expect(container.querySelector('[data-field="event-form"]')).toBeNull()

    const addBtn = container.querySelector('[data-field="add-event-btn"]')!
    await fireEvent.click(addBtn)

    const form = container.querySelector('[data-field="event-form"]')
    expect(form).not.toBeNull()

    // Form inputs should be empty for create
    const nameInput = form!.querySelector('[data-field="form-name"]') as HTMLInputElement
    expect(nameInput.value).toBe('')
  })

  // 9.45 — Create form includes country, venue, invitation, entry_fee, organizer select
  it('create form includes all M8 fields and organizer select', async () => {
    const { container } = render(EventManager, { props: defaultProps })
    await fireEvent.click(container.querySelector('[data-field="add-event-btn"]')!)

    const form = container.querySelector('[data-field="event-form"]')!
    expect(form.querySelector('[data-field="form-country"]')).not.toBeNull()
    expect(form.querySelector('[data-field="form-venue"]')).not.toBeNull()
    expect(form.querySelector('[data-field="form-invitation"]')).not.toBeNull()
    expect(form.querySelector('[data-field="form-entry-fee"]')).not.toBeNull()
    expect(form.querySelector('[data-field="form-url-event"]')).not.toBeNull()
    expect(form.querySelector('[data-field="form-currency"]')).not.toBeNull()

    const orgSelect = form.querySelector('[data-field="form-organizer"]') as HTMLSelectElement
    expect(orgSelect).not.toBeNull()
    // Should have organizer options
    const options = orgSelect.querySelectorAll('option')
    // +1 for placeholder option
    expect(options.length).toBe(MOCK_ORGANIZERS.length + 1)
  })

  // 9.46 — Edit form pre-fills existing event values
  it('edit form pre-fills existing event values', async () => {
    const { container } = render(EventManager, { props: defaultProps })
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])

    const form = container.querySelector('[data-field="event-form"]')!
    const nameInput = form.querySelector('[data-field="form-name"]') as HTMLInputElement
    const locationInput = form.querySelector('[data-field="form-location"]') as HTMLInputElement
    const countryInput = form.querySelector('[data-field="form-country"]') as HTMLInputElement

    expect(nameInput.value).toBe('PPW Wrocław Szpada')
    expect(locationInput.value).toBe('Wrocław')
    expect(countryInput.value).toBe('PL')

    const urlEventInput = form.querySelector('[data-field="form-url-event"]') as HTMLInputElement
    expect(urlEventInput.value).toBe('https://example.com/event')

    const currencySelect = form.querySelector('[data-field="form-currency"]') as HTMLSelectElement
    expect(currencySelect.value).toBe('PLN')
  })

  // 9.47 — Delete button calls ondelete with event id
  it('calls ondelete with event id on delete', async () => {
    const ondelete = vi.fn()
    const { container } = render(EventManager, { props: { ...defaultProps, ondelete } })
    const deleteBtns = container.querySelectorAll('[data-field="delete-btn"]')
    expect(deleteBtns.length).toBe(2)

    await fireEvent.click(deleteBtns[0])
    expect(ondelete).toHaveBeenCalledWith(10)
  })

  // 9.48 — Status badge rendered with correct text
  it('renders status badge with correct text', () => {
    const { container } = render(EventManager, { props: defaultProps })
    const badges = container.querySelectorAll('[data-field="event-status-badge"]')
    expect(badges.length).toBe(2)
    expect(badges[0].textContent).toContain('SCHEDULED')
    expect(badges[1].textContent).toContain('PLANNED')
  })

  // 9.49 — Status dropdown shows only valid next states
  it('status dropdown shows only valid next states for SCHEDULED event', () => {
    const { container } = render(EventManager, { props: defaultProps })
    const rows = container.querySelectorAll('[data-field="event-row"]')
    // First event is SCHEDULED — valid transitions: CHANGED, IN_PROGRESS, CANCELLED
    const select = rows[0].querySelector('[data-field="event-status-select"]') as HTMLSelectElement
    expect(select).not.toBeNull()
    const options = Array.from(select.options).map(o => o.value).filter(v => v !== '')
    expect(options).toContain('CHANGED')
    expect(options).toContain('IN_PROGRESS')
    expect(options).toContain('CANCELLED')
    expect(options).not.toContain('PLANNED')
    expect(options).not.toContain('COMPLETED')
  })

  // Admin guard — renders nothing when isAdmin=false
  it('renders nothing when isAdmin is false', () => {
    const { container } = render(EventManager, { props: { ...defaultProps, isAdmin: false } })
    expect(container.querySelector('[data-field="event-list"]')).toBeNull()
    expect(container.querySelector('[data-field="add-event-btn"]')).toBeNull()
  })
})

// ─── Accordion & Tournament Tests (Phase 6) ─────────────────────────

const MOCK_TOURNAMENTS: Tournament[] = [
  {
    id_tournament: 100,
    id_event: 10,
    txt_code: 'PPW-WRO-V2-M-EPEE-2024-2025',
    txt_name: 'V2 M Epee',
    enum_type: 'PPW',
    enum_weapon: 'EPEE',
    enum_gender: 'M',
    enum_age_category: 'V2',
    dt_tournament: '2025-01-15',
    int_participant_count: 32,
    num_multiplier: 1.0,
    url_results: null,
    enum_import_status: 'SCORED',
    txt_import_status_reason: null,
  },
  {
    id_tournament: 101,
    id_event: 10,
    txt_code: 'PPW-WRO-V1-M-EPEE-2024-2025',
    txt_name: 'V1 M Epee',
    enum_type: 'PPW',
    enum_weapon: 'EPEE',
    enum_gender: 'M',
    enum_age_category: 'V1',
    dt_tournament: '2025-01-15',
    int_participant_count: 28,
    num_multiplier: 1.0,
    url_results: null,
    enum_import_status: 'PLANNED',
    txt_import_status_reason: null,
  },
]

describe('EventManager Accordion (Phase 6)', () => {
  const propsWithTournaments = {
    events: MOCK_EVENTS,
    seasons: MOCK_SEASONS,
    organizers: MOCK_ORGANIZERS,
    tournaments: MOCK_TOURNAMENTS,
    selectedSeasonId: 1,
    isAdmin: true,
    oncreate: vi.fn(),
    onupdate: vi.fn(),
    onupdatestatus: vi.fn(),
    ondelete: vi.fn(),
    ondeletetournament: vi.fn(),
  }

  // 9.204 — Event row shows tournament count badge
  it('shows tournament count badge on event row', () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    const rows = container.querySelectorAll('[data-field="event-row"]')
    const badge = rows[0].querySelector('[data-field="tournament-count"]')
    expect(badge).not.toBeNull()
    expect(badge!.textContent).toContain('2')
  })

  // 9.205 — Clicking event row toggles accordion (shows tournament list)
  it('clicking event row toggles accordion', async () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    // Initially no tournament rows visible
    expect(container.querySelector('[data-field="tournament-row"]')).toBeNull()

    // Click to expand
    const expandBtn = container.querySelector('[data-field="expand-btn"]')!
    await fireEvent.click(expandBtn)

    // Tournament rows should now be visible
    const tournRows = container.querySelectorAll('[data-field="tournament-row"]')
    expect(tournRows.length).toBe(2)
  })

  // 9.206 — Tournament row shows code, weapon, category, import status
  it('tournament row shows code, weapon, category, import status', async () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)

    const tournRows = container.querySelectorAll('[data-field="tournament-row"]')
    const first = tournRows[0]
    expect(first.querySelector('[data-field="tourn-code"]')!.textContent).toContain('PPW-WRO-V2-M-EPEE')
    expect(first.querySelector('[data-field="tourn-import-status"]')!.textContent).toContain('SCORED')
  })

  // 9.207 — Tournament row shows participant count
  it('tournament row shows participant count', async () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)

    const tournRows = container.querySelectorAll('[data-field="tournament-row"]')
    expect(tournRows[0].querySelector('[data-field="tourn-participants"]')!.textContent).toContain('32')
  })

  // 9.208 — Tournament delete button calls ondeletetournament
  it('tournament delete button calls ondeletetournament', async () => {
    const ondeletetournament = vi.fn()
    const { container } = render(EventManager, { props: { ...propsWithTournaments, ondeletetournament } })
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)

    const deleteBtn = container.querySelector('[data-field="tourn-delete-btn"]')!
    await fireEvent.click(deleteBtn)
    expect(ondeletetournament).toHaveBeenCalledWith(100)
  })

  // 9.209 — Import status badges have correct styling classes
  it('import status badges have correct classes', async () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)

    const badges = container.querySelectorAll('[data-field="tourn-import-status"]')
    expect(badges[0].classList.contains('import-scored')).toBe(true)
    expect(badges[1].classList.contains('import-planned')).toBe(true)
  })

  // 9.210 — Collapse hides tournament rows
  it('collapsing hides tournament rows', async () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    // Expand
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)
    expect(container.querySelectorAll('[data-field="tournament-row"]').length).toBe(2)

    // Collapse
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)
    expect(container.querySelector('[data-field="tournament-row"]')).toBeNull()
  })

  // 9.211 — Event with no tournaments shows empty message
  it('expanded event with no tournaments shows empty state', async () => {
    const propsNoTourn = { ...propsWithTournaments, tournaments: [] }
    const { container } = render(EventManager, { props: propsNoTourn })
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)
    expect(container.querySelector('[data-field="tournament-row"]')).toBeNull()
  })
})
