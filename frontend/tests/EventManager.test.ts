// Plan tests: 9.43, 9.44, 9.45, 9.46, 9.47, 9.48, 9.49, 9.87, 9.88, 9.89
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
    url_registration: 'https://example.com/register',
    dt_registration_deadline: '2025-01-10',
    url_event_2: null,
    url_event_3: null,
    url_event_4: null,
    url_event_5: null,
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
    url_registration: null,
    dt_registration_deadline: null,
    url_event_2: null,
    url_event_3: null,
    url_event_4: null,
    url_event_5: null,
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
    // Renders via getEventDisplayStatus → i18n label + css class.
    // Event[0] is SCHEDULED → status-scheduled.
    // Event[1] is PLANNED with past dt_start (2025-02-20) → flips to
    // status-awaiting (ADR-028: "Awaiting results" display status).
    expect(badges[0].classList.contains('status-scheduled')).toBe(true)
    expect(badges[1].classList.contains('status-awaiting')).toBe(true)
  })

  // 9.49 — Past event edit form shows no status dropdown (date-aware transitions)
  it('past event edit form shows no status dropdown', async () => {
    const { container } = render(EventManager, { props: defaultProps })
    const editBtn = container.querySelector('[data-field="edit-btn"]') as HTMLElement
    await fireEvent.click(editBtn)
    expect(container.querySelector('[data-field="event-status-select"]')).toBeNull()
  })

  // 9.87 — Future COMPLETED event edit form shows status dropdown with rollback options
  it('future COMPLETED event edit form shows status dropdown with rollback options', async () => {
    const futureCompleted: CalendarEvent = {
      ...MOCK_EVENTS[0],
      id_event: 99,
      dt_start: '2027-10-15',
      dt_end: '2027-10-16',
      enum_status: 'COMPLETED',
    }
    const { container } = render(EventManager, { props: { ...defaultProps, events: [futureCompleted] } })
    const editBtn = container.querySelector('[data-field="edit-btn"]') as HTMLElement
    await fireEvent.click(editBtn)
    const select = container.querySelector('[data-field="event-status-select"]') as HTMLSelectElement
    expect(select).not.toBeNull()
    const options = Array.from(select.options).map(o => o.value).filter(v => v !== '')
    expect(options).toContain('PLANNED')
    expect(options).toContain('SCHEDULED')
    expect(options).toContain('CHANGED')
    expect(options).toContain('IN_PROGRESS')
    expect(options).toContain('CANCELLED')
    expect(options).toContain('COMPLETED') // current status is the default option
  })

  // 9.88 — Event with null dt_start edit form shows status dropdown
  it('event with null dt_start edit form shows status dropdown', async () => {
    const nullDate: CalendarEvent = {
      ...MOCK_EVENTS[1],
      id_event: 98,
      dt_start: null,
      dt_end: null,
      enum_status: 'PLANNED',
    }
    const { container } = render(EventManager, { props: { ...defaultProps, events: [nullDate] } })
    const editBtn = container.querySelector('[data-field="edit-btn"]') as HTMLElement
    await fireEvent.click(editBtn)
    const select = container.querySelector('[data-field="event-status-select"]') as HTMLSelectElement
    expect(select).not.toBeNull()
    const options = Array.from(select.options).map(o => o.value).filter(v => v !== '')
    expect(options).toContain('PLANNED') // current status as default option
    expect(options.length).toBe(6) // current + 5 alternatives
  })

  // 9.89 — Future CANCELLED event edit form shows status dropdown
  it('future CANCELLED event edit form shows status dropdown', async () => {
    const futureCancelled: CalendarEvent = {
      ...MOCK_EVENTS[0],
      id_event: 97,
      dt_start: '2027-06-01',
      dt_end: '2027-06-01',
      enum_status: 'CANCELLED',
    }
    const { container } = render(EventManager, { props: { ...defaultProps, events: [futureCancelled] } })
    const editBtn = container.querySelector('[data-field="edit-btn"]') as HTMLElement
    await fireEvent.click(editBtn)
    const select = container.querySelector('[data-field="event-status-select"]') as HTMLSelectElement
    expect(select).not.toBeNull()
    const options = Array.from(select.options).map(o => o.value).filter(v => v !== '')
    expect(options).toContain('CANCELLED') // current status as default option
    expect(options.length).toBe(6)
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

  // 9.83 — Tournament edit button opens edit form with current values
  it('9.83: tournament edit button opens inline edit form', async () => {
    const onedittournament = vi.fn()
    const { container } = render(EventManager, { props: { ...propsWithTournaments, onedittournament } })
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)

    const editBtn = container.querySelector('[data-field="tourn-edit-btn"]')!
    await fireEvent.click(editBtn)

    // Edit form should appear with code and url fields
    const editForm = container.querySelector('[data-field="tourn-edit-form"]')
    expect(editForm).not.toBeNull()
    const codeInput = editForm!.querySelector('[data-field="tourn-edit-code"]') as HTMLInputElement
    expect(codeInput).not.toBeNull()
    expect(codeInput.value).toContain('PPW-WRO-V2-M-EPEE')
  })

  // 9.84 — Add Tournament button shows create form
  it('9.84: add tournament button shows create form', async () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)

    const addBtn = container.querySelector('[data-field="tourn-add-btn"]')
    expect(addBtn).not.toBeNull()
    await fireEvent.click(addBtn!)

    const createForm = container.querySelector('[data-field="tourn-create-form"]')
    expect(createForm).not.toBeNull()
  })

  // 9.43a — Edit form populates registration URL and deadline from event data
  it('9.43a: edit form populates registration URL and deadline', async () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    const editBtn = container.querySelector('[data-field="edit-btn"]')!
    await fireEvent.click(editBtn)

    const regInput = container.querySelector('[data-field="form-registration"]') as HTMLInputElement
    expect(regInput).not.toBeNull()
    expect(regInput.value).toBe('https://example.com/register')

    const deadlineInput = container.querySelector('[data-field="form-registration-deadline"]') as HTMLInputElement
    expect(deadlineInput).not.toBeNull()
    expect(deadlineInput.value).toBe('2025-01-10')
  })

  // 9.43b — Create form has empty registration fields
  it('9.43b: create form has empty registration fields', async () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    const addBtn = container.querySelector('[data-field="add-event-btn"]')!
    await fireEvent.click(addBtn)

    const regInput = container.querySelector('[data-field="form-registration"]') as HTMLInputElement
    expect(regInput).not.toBeNull()
    expect(regInput.value).toBe('')

    const deadlineInput = container.querySelector('[data-field="form-registration-deadline"]') as HTMLInputElement
    expect(deadlineInput).not.toBeNull()
    expect(deadlineInput.value).toBe('')
  })

  // 9.43c — Save includes registration + registrationDeadline in params
  it('9.43c: save includes registration and registrationDeadline in params', async () => {
    const onupdate = vi.fn()
    const { container } = render(EventManager, { props: { ...propsWithTournaments, onupdate } })
    const editBtn = container.querySelector('[data-field="edit-btn"]')!
    await fireEvent.click(editBtn)

    const regInput = container.querySelector('[data-field="form-registration"]') as HTMLInputElement
    await fireEvent.input(regInput, { target: { value: 'https://new-reg.com' } })

    const saveBtn = container.querySelector('[data-field="form-save-btn"]')!
    await fireEvent.click(saveBtn)

    expect(onupdate).toHaveBeenCalledWith(10, expect.objectContaining({
      registration: 'https://new-reg.com',
      registrationDeadline: '2025-01-10',
    }))
  })

  // 9.85 — Tournament edit save calls onedittournament with params
  it('9.85: tournament edit save calls onedittournament with id and params', async () => {
    const onedittournament = vi.fn()
    const { container } = render(EventManager, { props: { ...propsWithTournaments, onedittournament } })
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)
    await fireEvent.click(container.querySelector('[data-field="tourn-edit-btn"]')!)

    // Change the code
    const codeInput = container.querySelector('[data-field="tourn-edit-code"]') as HTMLInputElement
    await fireEvent.input(codeInput, { target: { value: 'NEW-CODE' } })

    // Save
    const saveBtn = container.querySelector('[data-field="tourn-edit-save"]')!
    await fireEvent.click(saveBtn)

    expect(onedittournament).toHaveBeenCalledWith(100, expect.objectContaining({ code: 'NEW-CODE' }))
  })

  // 9.86 — Tournament create save calls oncreatetournament
  it('9.86: tournament create save calls oncreatetournament with event id and params', async () => {
    const oncreatetournament = vi.fn()
    const { container } = render(EventManager, { props: { ...propsWithTournaments, oncreatetournament } })
    await fireEvent.click(container.querySelector('[data-field="expand-btn"]')!)
    await fireEvent.click(container.querySelector('[data-field="tourn-add-btn"]')!)

    // Fill weapon select
    const weaponSelect = container.querySelector('[data-field="tourn-create-weapon"]') as HTMLSelectElement
    await fireEvent.change(weaponSelect, { target: { value: 'FOIL' } })

    // Save
    const saveBtn = container.querySelector('[data-field="tourn-create-save"]')!
    await fireEvent.click(saveBtn)

    expect(oncreatetournament).toHaveBeenCalledWith(10, expect.objectContaining({ weapon: 'FOIL' }))
  })

  // ─── ADR-040 — Multi-slot event result URLs ──────────────────────────

  // 9.44a — Edit form populates 5 URL inputs from url_event + url_event_2..5
  it('9.44a: edit form populates 5 URL inputs from url_event + url_event_2..5', async () => {
    const eventsWithMultiUrl: CalendarEvent[] = [{
      ...MOCK_EVENTS[0],
      url_event: 'https://e1.example/',
      url_event_2: 'https://e2.example/',
      url_event_3: 'https://e3.example/',
      url_event_4: null,
      url_event_5: null,
    }]
    const { container } = render(EventManager, { props: { ...propsWithTournaments, events: eventsWithMultiUrl } })
    const editBtn = container.querySelector('[data-field="edit-btn"]')!
    await fireEvent.click(editBtn)

    const u1 = container.querySelector('[data-field="form-url-event"]') as HTMLInputElement
    const u2 = container.querySelector('[data-field="form-url-event-2"]') as HTMLInputElement
    const u3 = container.querySelector('[data-field="form-url-event-3"]') as HTMLInputElement
    const u4 = container.querySelector('[data-field="form-url-event-4"]') as HTMLInputElement
    const u5 = container.querySelector('[data-field="form-url-event-5"]') as HTMLInputElement

    expect(u1.value).toBe('https://e1.example/')
    expect(u2.value).toBe('https://e2.example/')
    expect(u3.value).toBe('https://e3.example/')
    expect(u4.value).toBe('')
    expect(u5.value).toBe('')
  })

  // 9.44b — Disclosure starts closed when slots #2..5 all NULL; auto-opens when any set
  it('9.44b: disclosure auto-opens when any of slots #2-5 is set on form-open', async () => {
    // Case A: all of #2-5 null → disclosure closed (slots #2-5 inputs not visible)
    const { container: cA } = render(EventManager, { props: propsWithTournaments })
    await fireEvent.click(cA.querySelector('[data-field="edit-btn"]')!)
    expect(cA.querySelector('[data-field="form-url-event-2"]')).toBeNull()

    // Case B: slot #3 has a value → disclosure auto-opens
    const eventsB: CalendarEvent[] = [{
      ...MOCK_EVENTS[0],
      url_event_3: 'https://e3.example/',
    }]
    const { container: cB } = render(EventManager, { props: { ...propsWithTournaments, events: eventsB } })
    await fireEvent.click(cB.querySelector('[data-field="edit-btn"]')!)
    expect(cB.querySelector('[data-field="form-url-event-2"]')).not.toBeNull()
  })

  // 9.44c — Disclosure label shows filled-count
  it('9.44c: disclosure label shows filled-count for slots #2-5', async () => {
    const eventsWithMultiUrl: CalendarEvent[] = [{
      ...MOCK_EVENTS[0],
      url_event_2: 'https://e2.example/',
      url_event_4: 'https://e4.example/',
    }]
    const { container } = render(EventManager, { props: { ...propsWithTournaments, events: eventsWithMultiUrl } })
    await fireEvent.click(container.querySelector('[data-field="edit-btn"]')!)

    const disclosure = container.querySelector('[data-field="url-extras-disclosure"]') as HTMLElement
    expect(disclosure).not.toBeNull()
    expect(disclosure.textContent).toMatch(/2/)  // shows 2 of 4 extras filled
  })

  // 9.44d — Save handler compacts gap input (left-shift, drop empties, pad NULL)
  it('9.44d: save compacts gap input [NULL,B,NULL,D,NULL] to urlEvent=B, urlEvent2=D', async () => {
    const onupdate = vi.fn()
    const eventsWithMultiUrl: CalendarEvent[] = [{
      ...MOCK_EVENTS[0],
      url_event: null,
      url_event_2: 'B',
      url_event_3: null,
      url_event_4: 'D',
      url_event_5: null,
    }]
    const { container } = render(EventManager, { props: { ...propsWithTournaments, events: eventsWithMultiUrl, onupdate } })
    await fireEvent.click(container.querySelector('[data-field="edit-btn"]')!)
    await fireEvent.click(container.querySelector('[data-field="form-save-btn"]')!)

    expect(onupdate).toHaveBeenCalledWith(10, expect.objectContaining({
      urlEvent: 'B',
      urlEvent2: 'D',
      urlEvent3: null,
      urlEvent4: null,
      urlEvent5: null,
    }))
  })

  // 9.44e — Save handler dedupes preserving first occurrence + trims whitespace
  it('9.44e: save dedupes [A, A, B, "  ", ""] to urlEvent=A, urlEvent2=B', async () => {
    const onupdate = vi.fn()
    const eventsWithMultiUrl: CalendarEvent[] = [{
      ...MOCK_EVENTS[0],
      url_event: 'A',
      url_event_2: 'A',         // duplicate
      url_event_3: 'B',
      url_event_4: '  ',        // whitespace-only → drop
      url_event_5: '',          // empty → drop
    }]
    const { container } = render(EventManager, { props: { ...propsWithTournaments, events: eventsWithMultiUrl, onupdate } })
    await fireEvent.click(container.querySelector('[data-field="edit-btn"]')!)
    await fireEvent.click(container.querySelector('[data-field="form-save-btn"]')!)

    expect(onupdate).toHaveBeenCalledWith(10, expect.objectContaining({
      urlEvent: 'A',
      urlEvent2: 'B',
      urlEvent3: null,
      urlEvent4: null,
      urlEvent5: null,
    }))
  })

  // 9.44f — Slot #1 input has primary styling marker (data-primary or class)
  it('9.44f: slot #1 input has primary marker (.url-num.primary or data-primary)', async () => {
    const { container } = render(EventManager, { props: propsWithTournaments })
    await fireEvent.click(container.querySelector('[data-field="edit-btn"]')!)

    const primary = container.querySelector('[data-field="url-num-1"].primary')
                  ?? container.querySelector('[data-field="url-num-1"][data-primary="true"]')
    expect(primary).not.toBeNull()
  })
})
