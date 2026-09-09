// Phase 2 (P2.7, FR-123) — EntryList.svelte: on-demand public roster fetch +
// nazwisko/broń/kategoria/płeć filters. No birth year or club (GDPR
// minimisation) — vw_registration_entry_list already excludes them.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'

vi.mock('../src/lib/api', () => ({
  fetchEntryList: vi.fn(),
}))
import { fetchEntryList } from '../src/lib/api'
import EntryList from '../src/components/EntryList.svelte'
import type { RegistrationEntry } from '../src/lib/types'

const mockFetchEntryList = vi.mocked(fetchEntryList)

const ROWS: RegistrationEntry[] = [
  { id_registration: 1, id_event: 3, txt_surname: 'KOWALSKI', txt_first_name: 'Jan', enum_gender: 'M', arr_weapons: ['EPEE', 'SABRE'], enum_age_category: 'V2' },
  { id_registration: 2, id_event: 3, txt_surname: 'NOWAK', txt_first_name: 'Piotr', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V1' },
  { id_registration: 3, id_event: 3, txt_surname: 'WISNIEWSKA', txt_first_name: 'Anna', enum_gender: 'F', arr_weapons: ['FOIL'], enum_age_category: 'V2' },
]

beforeEach(() => {
  vi.clearAllMocks()
})

describe('EntryList', () => {
  it('fetches and renders every registration for the event', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    await findByText('NOWAK Piotr')
    await findByText('WISNIEWSKA Anna')
    expect(mockFetchEntryList).toHaveBeenCalledWith(3)
  })

  it('does not render birth year or club anywhere (GDPR minimisation)', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    expect(container.textContent).not.toMatch(/\b19\d{2}\b/)
  })

  it('filters by surname search', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText, queryByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    const search = container.querySelector('input[name="search"]') as HTMLInputElement
    await fireEvent.input(search, { target: { value: 'nowak' } })
    await waitFor(() => expect(queryByText('KOWALSKI Jan')).toBeNull())
    expect(queryByText('NOWAK Piotr')).not.toBeNull()
  })

  it('filters by weapon', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText, queryByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    const weaponSelect = container.querySelector('select[name="weaponFilter"]') as HTMLSelectElement
    await fireEvent.change(weaponSelect, { target: { value: 'FOIL' } })
    await waitFor(() => expect(queryByText('WISNIEWSKA Anna')).not.toBeNull())
    expect(queryByText('KOWALSKI Jan')).toBeNull()
    expect(queryByText('NOWAK Piotr')).toBeNull()
  })

  it('filters by gender', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText, queryByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    const genderSelect = container.querySelector('select[name="genderFilter"]') as HTMLSelectElement
    await fireEvent.change(genderSelect, { target: { value: 'F' } })
    await waitFor(() => expect(queryByText('WISNIEWSKA Anna')).not.toBeNull())
    expect(queryByText('KOWALSKI Jan')).toBeNull()
  })

  it('shows an empty state when no rows match the filters', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    const search = container.querySelector('input[name="search"]') as HTMLInputElement
    await fireEvent.input(search, { target: { value: 'zzz-no-such-name' } })
    await findByText(/Brak wyników/)
  })

  // FR-123 mockup parity (2026-07-05) — doc/mockups/registration_entry_list.html
  // shows a "Kat." column + category filter that this component never had.
  it('renders the category badge in a "Kat." column for each row', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    const badges = container.querySelectorAll('.el-cat')
    expect(badges.length).toBe(3)
    expect(badges[0].textContent).toBe('V2')
    expect(badges[1].textContent).toBe('V1')
  })

  it('filters by category', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText, queryByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    const categorySelect = container.querySelector('select[name="categoryFilter"]') as HTMLSelectElement
    await fireEvent.change(categorySelect, { target: { value: 'V1' } })
    await waitFor(() => expect(queryByText('NOWAK Piotr')).not.toBeNull())
    expect(queryByText('KOWALSKI Jan')).toBeNull()
    expect(queryByText('WISNIEWSKA Anna')).toBeNull()
  })

  it('renders category filter options matching the FilterBar V0–V4 convention, with a "--" placeholder under its own label', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    const categorySelect = container.querySelector('select[name="categoryFilter"]') as HTMLSelectElement
    const optionTexts = Array.from(categorySelect.options).map((o) => o.textContent)
    expect(optionTexts).toEqual([
      '--', 'V0 (30+)', 'V1 (40+)', 'V2 (50+)', 'V3 (60+)', 'V4 (70+)',
    ])
  })

  it('renders a label next to each filter dropdown instead of folding the name into the "all" option', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    const weaponSelect = container.querySelector('select[name="weaponFilter"]') as HTMLSelectElement
    const genderSelect = container.querySelector('select[name="genderFilter"]') as HTMLSelectElement
    expect(weaponSelect.options[0].textContent).toBe('--')
    expect(genderSelect.options[0].textContent).toBe('--')
    const labels = Array.from(container.querySelectorAll('.el-flabel span')).map((s) => s.textContent)
    expect(labels).toEqual(['Broń', 'Kategoria', 'Płeć'])
  })
})

describe('EntryList — modal-embed close affordance', () => {
  it('renders no close button by default (standalone page has nowhere to close to)', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    expect(container.querySelector('button.el-close')).toBeNull()
  })

  // Return path from the registration flow. The roster is reachable from the
  // payment step, which is the only place the transfer data (payee, IBAN,
  // title, amount) exists — so it must be possible to get back to it.
  it('renders a back button and calls onback when provided (in-flow)', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const onback = vi.fn()
    const { container, findByText } = render(EntryList, { props: { eventId: 3, onback } })
    await findByText('KOWALSKI Jan')
    const backBtn = container.querySelector('button.el-back') as HTMLButtonElement
    expect(backBtn).not.toBeNull()
    await fireEvent.click(backBtn)
    expect(onback).toHaveBeenCalled()
  })

  it('renders no back button without onback (cold ?view=list link)', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('KOWALSKI Jan')
    // Someone who opened the shared roster link, or the entry list straight
    // from a calendar card, never passed through the form — there is nothing
    // to go back to. Same conditional pattern as onclose.
    expect(container.querySelector('button.el-back')).toBeNull()
  })

  // In the calendar modal the roster carries both: back goes to the step it
  // was opened from (the transfer details), close dismisses the whole modal to
  // the calendar. Different destinations, so both must be present and neither
  // may fire the other.
  it('renders back and close together in the modal, each firing only its own handler', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const onback = vi.fn()
    const onclose = vi.fn()
    const { container, findByText } = render(EntryList, { props: { eventId: 3, onback, onclose } })
    await findByText('KOWALSKI Jan')
    const backBtn = container.querySelector('button.el-back') as HTMLButtonElement
    const closeBtn = container.querySelector('button.el-close') as HTMLButtonElement
    expect(backBtn).not.toBeNull()
    expect(closeBtn).not.toBeNull()

    await fireEvent.click(backBtn)
    expect(onback).toHaveBeenCalledTimes(1)
    expect(onclose).not.toHaveBeenCalled()

    await fireEvent.click(closeBtn)
    expect(onclose).toHaveBeenCalledTimes(1)
    expect(onback).toHaveBeenCalledTimes(1)
  })

  it('renders a close button and calls onclose when provided (modal-embed)', async () => {
    mockFetchEntryList.mockResolvedValue(ROWS)
    const onclose = vi.fn()
    const { container, findByText } = render(EntryList, { props: { eventId: 3, onclose } })
    await findByText('KOWALSKI Jan')
    const closeBtn = container.querySelector('button.el-close') as HTMLButtonElement
    expect(closeBtn).not.toBeNull()
    await fireEvent.click(closeBtn)
    expect(onclose).toHaveBeenCalled()
  })
})

// Surname ordering (2026-09-09). The roster arrives in registration order —
// fetchEntryList orders by id_registration — which means nothing to a fencer
// scanning for their own name. Polish collation is the whole difficulty: a
// naive Array.sort() compares UTF-16 code units, so Ć, Ł and Ż all land after
// Z and ŁUKASIEWICZ renders below ŻAK.
const UNSORTED: RegistrationEntry[] = [
  { id_registration: 1, id_event: 3, txt_surname: 'ŻAK', txt_first_name: 'Adam', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V1' },
  { id_registration: 2, id_event: 3, txt_surname: 'KOWALSKI', txt_first_name: 'Piotr', enum_gender: 'M', arr_weapons: ['FOIL'], enum_age_category: 'V2' },
  { id_registration: 3, id_event: 3, txt_surname: 'ĆWIKLIŃSKI', txt_first_name: 'Marek', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V0' },
  { id_registration: 4, id_event: 3, txt_surname: 'KOWALSKI', txt_first_name: 'Anna', enum_gender: 'F', arr_weapons: ['EPEE'], enum_age_category: 'V3' },
  { id_registration: 5, id_event: 3, txt_surname: 'ŁUKASIEWICZ', txt_first_name: 'Ewa', enum_gender: 'F', arr_weapons: ['SABRE'], enum_age_category: 'V2' },
  { id_registration: 6, id_event: 3, txt_surname: 'CZAJKA', txt_first_name: 'Jan', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V1' },
]

function renderedNames(container: HTMLElement): (string | undefined)[] {
  return Array.from(container.querySelectorAll('td.el-name')).map((td) => td.textContent?.trim())
}

describe('EntryList — surname ordering', () => {
  it('renders rows by surname A–Z under Polish collation, not in registration order', async () => {
    mockFetchEntryList.mockResolvedValue(UNSORTED)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('CZAJKA Jan')
    // Ć sorts after CZ and before K; Ł between K and M; Ż last. Every one of
    // those rungs is wrong under a naive sort.
    expect(renderedNames(container)).toEqual([
      'CZAJKA Jan',
      'ĆWIKLIŃSKI Marek',
      'KOWALSKI Anna',
      'KOWALSKI Piotr',
      'ŁUKASIEWICZ Ewa',
      'ŻAK Adam',
    ])
  })

  it('breaks a shared surname on the first name', async () => {
    mockFetchEntryList.mockResolvedValue(UNSORTED)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('CZAJKA Jan')
    const names = renderedNames(container)
    // Anna registered second (id 4), Piotr first (id 2) — the display order is
    // the alphabet's, not the registrations'.
    expect(names.indexOf('KOWALSKI Anna')).toBeLessThan(names.indexOf('KOWALSKI Piotr'))
  })

  it('sorts case-insensitively so a lower-case surname does not sink to the bottom', async () => {
    // The self-registration form takes free text, so mixed case will arrive
    // even though the seeded roster is upper-case.
    mockFetchEntryList.mockResolvedValue([
      { id_registration: 1, id_event: 3, txt_surname: 'ZALEWSKI', txt_first_name: 'Jan', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V1' },
      { id_registration: 2, id_event: 3, txt_surname: 'baran', txt_first_name: 'Ewa', enum_gender: 'F', arr_weapons: ['FOIL'], enum_age_category: 'V2' },
    ])
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('baran Ewa')
    expect(renderedNames(container)).toEqual(['baran Ewa', 'ZALEWSKI Jan'])
  })

  // Constraint from the design discussion: the sort must not entangle the
  // filtering that was already there. Array.prototype.filter preserves input
  // order, so a filtered roster stays alphabetical for free.
  it('keeps the alphabetical order after a filter narrows the roster', async () => {
    mockFetchEntryList.mockResolvedValue(UNSORTED)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('CZAJKA Jan')
    const weaponSelect = container.querySelector('select[name="weaponFilter"]') as HTMLSelectElement
    await fireEvent.change(weaponSelect, { target: { value: 'EPEE' } })
    await waitFor(() =>
      expect(renderedNames(container)).toEqual([
        'CZAJKA Jan',
        'ĆWIKLIŃSKI Marek',
        'KOWALSKI Anna',
        'ŻAK Adam',
      ]),
    )
  })
})
