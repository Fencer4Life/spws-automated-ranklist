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
  { id_registration: 1, id_event: 3, txt_surname: 'KOWALSKI', txt_first_name: 'Jan', enum_gender: 'M', arr_weapons: ['EPEE', 'SABRE'] },
  { id_registration: 2, id_event: 3, txt_surname: 'NOWAK', txt_first_name: 'Piotr', enum_gender: 'M', arr_weapons: ['EPEE'] },
  { id_registration: 3, id_event: 3, txt_surname: 'WISNIEWSKA', txt_first_name: 'Anna', enum_gender: 'F', arr_weapons: ['FOIL'] },
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
})
