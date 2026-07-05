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
