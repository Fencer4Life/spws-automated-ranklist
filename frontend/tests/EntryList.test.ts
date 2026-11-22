// Phase 2 (P2.7, FR-123) — EntryList.svelte: on-demand public roster fetch +
// nazwisko/broń/kategoria/płeć filters. No birth year or club (GDPR
// minimisation) — vw_registration_entry_list already excludes them.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'
import { setLocale } from '../src/lib/locale.svelte'

vi.mock('../src/lib/api', () => ({
  fetchEntryList: vi.fn(),
  fetchEntryRanks: vi.fn(),
  deleteRegistration: vi.fn(),
  fetchAdminEntryDetails: vi.fn(),
  fetchEventSeasonEndYear: vi.fn(),
  updateRegistrationAsAdmin: vi.fn(),
}))
import {
  fetchEntryList,
  fetchEntryRanks,
  deleteRegistration,
  fetchAdminEntryDetails,
  fetchEventSeasonEndYear,
  updateRegistrationAsAdmin,
} from '../src/lib/api'
import EntryList from '../src/components/EntryList.svelte'
import type { EntryRank, RegistrationEntry } from '../src/lib/types'

const mockFetchEntryList = vi.mocked(fetchEntryList)

const ROWS: RegistrationEntry[] = [
  { id_registration: 1, id_event: 3, txt_surname: 'KOWALSKI', txt_first_name: 'Jan', enum_gender: 'M', arr_weapons: ['EPEE', 'SABRE'], enum_age_category: 'V2' },
  { id_registration: 2, id_event: 3, txt_surname: 'NOWAK', txt_first_name: 'Piotr', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V1' },
  { id_registration: 3, id_event: 3, txt_surname: 'WISNIEWSKA', txt_first_name: 'Anna', enum_gender: 'F', arr_weapons: ['FOIL'], enum_age_category: 'V2' },
]

beforeEach(() => {
  vi.clearAllMocks()
  // FR-170: the signed-in list also reads each entry's details and the
  // event's season; by default there are none to show.
  vi.mocked(fetchAdminEntryDetails).mockResolvedValue([])
  vi.mocked(fetchEventSeasonEndYear).mockResolvedValue(2027)
  // FR-175: by default the event's box is not ticked, so there are no ranks
  // and every list renders exactly as before.
  vi.mocked(fetchEntryRanks).mockResolvedValue([])
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

// ---------------------------------------------------------------------------
// FR-165 — the tiles show the selection; the search folds diacritics.
// Plan: doc/plans/entry-list-tiles-follow-filters-tdd-plan-2026-11-17.html §04.
// Design signed 2026-11-17: doc/plans/entry-list-selection-count-2026-11-17.html.
//
// Invented entries. Totals: 8 registered; épée 5, foil 3, sabre 2.
// ---------------------------------------------------------------------------
const SEL: RegistrationEntry[] = [
  { id_registration: 1, id_event: 3, txt_surname: 'ŻAK', txt_first_name: 'Adam', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V2' },
  { id_registration: 2, id_event: 3, txt_surname: 'ŁOŚ', txt_first_name: 'Ewa', enum_gender: 'F', arr_weapons: ['FOIL'], enum_age_category: 'V2' },
  { id_registration: 3, id_event: 3, txt_surname: 'KOWAL', txt_first_name: 'Jan', enum_gender: 'M', arr_weapons: ['EPEE', 'SABRE'], enum_age_category: 'V2' },
  { id_registration: 4, id_event: 3, txt_surname: 'KOWAL', txt_first_name: 'Anna', enum_gender: 'F', arr_weapons: ['EPEE'], enum_age_category: 'V1' },
  { id_registration: 5, id_event: 3, txt_surname: 'ĆWIK', txt_first_name: 'Marek', enum_gender: 'M', arr_weapons: ['SABRE'], enum_age_category: 'V1' },
  { id_registration: 6, id_event: 3, txt_surname: 'NOWAK', txt_first_name: 'Piotr', enum_gender: 'M', arr_weapons: ['EPEE', 'FOIL'], enum_age_category: 'V2' },
  { id_registration: 7, id_event: 3, txt_surname: 'ŚLIWA', txt_first_name: 'Zofia', enum_gender: 'F', arr_weapons: ['FOIL'], enum_age_category: 'V3' },
  { id_registration: 8, id_event: 3, txt_surname: 'lis', txt_first_name: 'Paweł', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V0' },
]

async function renderSel(rows: RegistrationEntry[] = SEL) {
  mockFetchEntryList.mockResolvedValue(rows)
  const view = render(EntryList, { props: { eventId: 3 } })
  const c = view.container
  if (rows.length) await waitFor(() => expect(c.querySelector('td.el-name')).not.toBeNull())
  else await waitFor(() => expect(mockFetchEntryList).toHaveBeenCalled())
  const search = c.querySelector('input[name="search"]') as HTMLInputElement
  const weapon = c.querySelector('select[name="weaponFilter"]') as HTMLSelectElement
  const category = c.querySelector('select[name="categoryFilter"]') as HTMLSelectElement
  const gender = c.querySelector('select[name="genderFilter"]') as HTMLSelectElement
  const type = (value: string) => fireEvent.input(search, { target: { value } })
  const pick = (el: HTMLSelectElement, value: string) => fireEvent.change(el, { target: { value } })
  /** The four tiles' numbers, whitespace collapsed: ['4 z 8', '3 z 5', ...]. */
  const tiles = () =>
    Array.from(c.querySelectorAll('.el-metrics .el-metric .el-v')).map((v) =>
      (v.textContent ?? '').replace(/\s+/g, ' ').trim(),
    )
  return { ...view, c, search, weapon, category, gender, type, pick, tiles }
}

const PLAIN = ['8', '5', '3', '2']

describe('EntryList — the tiles show the selection (FR-165)', () => {
  afterEach(() => setLocale('pl'))

  // ELSEL.01 — guard: holds before the change; proven by a mutation run.
  it('shows plain totals and none of the selection marks when nothing narrows', async () => {
    const v = await renderSel()
    expect(v.tiles()).toEqual(PLAIN)
    expect(v.c.querySelector('.el-of')).toBeNull()
    expect(v.c.querySelector('.el-metrics.el-narrowed')).toBeNull()
    expect(v.c.querySelector('.el-dim')).toBeNull()
    expect(v.c.querySelector('.el-active')).toBeNull()
    expect(v.c.querySelector('button.el-search-clear')).toBeNull()
    expect(v.c.querySelector('button.el-clear-all')).toBeNull()
  })

  // ELSEL.02
  it('shows selection z total on every tile under a category filter', async () => {
    const v = await renderSel()
    await v.pick(v.category, 'V2')
    await waitFor(() => expect(v.tiles()).toEqual(['4 z 8', '3 z 5', '2 z 3', '1 z 2']))
  })

  // ELSEL.03
  it('narrows the tiles by the search alone', async () => {
    const v = await renderSel()
    await v.type('kow')
    await waitFor(() => expect(v.tiles()).toEqual(['2 z 8', '2 z 5', '0 z 3', '1 z 2']))
  })

  // ELSEL.04
  it('combines the search with all three filters', async () => {
    const v = await renderSel()
    await v.type('kow')
    await v.pick(v.weapon, 'EPEE')
    await v.pick(v.category, 'V2')
    await v.pick(v.gender, 'M')
    await waitFor(() => expect(v.tiles()).toEqual(['1 z 8', '1 z 5', '0 z 3', '1 z 2']))
    expect(renderedNames(v.c)).toEqual(['KOWAL Jan'])
  })

  // ELSEL.05
  it('keeps the first tile equal to the number of listed rows', async () => {
    const v = await renderSel()
    const combos: [string, string, string, string][] = [
      ['', 'FOIL', '', ''],
      ['', '', 'V1', ''],
      ['', '', '', 'F'],
      ['a', 'EPEE', '', 'M'],
      ['ow', '', 'V2', ''],
    ]
    for (const [q, w, cat, g] of combos) {
      await v.type(q)
      await v.pick(v.weapon, w)
      await v.pick(v.category, cat)
      await v.pick(v.gender, g)
      await waitFor(() => expect(v.tiles()[0]).toBe(`${renderedNames(v.c).length} z 8`))
    }
  })

  // ELSEL.06
  it('shows 0 z total on every tile when nothing matches, with the empty message', async () => {
    const v = await renderSel()
    await v.type('qqq')
    await waitFor(() => expect(v.tiles()).toEqual(['0 z 8', '0 z 5', '0 z 3', '0 z 2']))
    expect(v.c.textContent).toMatch(/Brak wyników/)
  })

  // ELSEL.07 — guard: holds before the change; proven by a mutation run.
  it('does not treat a search of spaces as narrowing', async () => {
    const v = await renderSel()
    await v.type('   ')
    await waitFor(() => expect(renderedNames(v.c)).toHaveLength(8))
    expect(v.tiles()).toEqual(PLAIN)
    expect(v.c.querySelector('.el-metrics.el-narrowed')).toBeNull()
  })

  // ELSEL.08
  it('announces the tiles politely to a screen reader', async () => {
    const v = await renderSel()
    expect(v.c.querySelector('.el-metrics')?.getAttribute('aria-live')).toBe('polite')
  })

  // ELSEL.09
  it('reads "of" in English and keeps the filter across the language switch', async () => {
    const v = await renderSel()
    await v.pick(v.category, 'V2')
    await waitFor(() => expect(v.tiles()[0]).toBe('4 z 8'))
    await fireEvent.click(v.c.querySelector('.lang-btn[aria-label="English"]') as HTMLButtonElement)
    await waitFor(() => expect(v.tiles()).toEqual(['4 of 8', '3 of 5', '2 of 3', '1 of 2']))
    expect(v.category.value).toBe('V2')
  })

  // ELSEL.17
  it('counts an event with no entries as 0, and 0 z 0 under a filter', async () => {
    const v = await renderSel([])
    await waitFor(() => expect(v.tiles()).toEqual(['0', '0', '0', '0']))
    await v.pick(v.category, 'V2')
    await waitFor(() => expect(v.tiles()).toEqual(['0 z 0', '0 z 0', '0 z 0', '0 z 0']))
    expect(v.c.textContent).toMatch(/Brak wyników/)
  })
})

describe('EntryList — frame and highlight while narrowed (FR-165, S5, S1)', () => {
  // ELSEL.10
  it('frames the tiles only while the list is narrowed', async () => {
    const v = await renderSel()
    const metrics = v.c.querySelector('.el-metrics') as HTMLElement
    expect(metrics.classList.contains('el-narrowed')).toBe(false)
    await v.pick(v.category, 'V2')
    await waitFor(() => expect(metrics.classList.contains('el-narrowed')).toBe(true))
    await v.pick(v.category, '')
    await waitFor(() => expect(metrics.classList.contains('el-narrowed')).toBe(false))
  })

  // ELSEL.11
  it('highlights only the controls that narrow, the search box included', async () => {
    const v = await renderSel()
    const active = () =>
      [v.search, v.weapon, v.category, v.gender].filter((el) => el.classList.contains('el-active'))
    expect(active()).toEqual([])
    await v.type('kow')
    await waitFor(() => expect(active()).toEqual([v.search]))
    await v.type('')
    await v.pick(v.category, 'V1')
    await waitFor(() => expect(active()).toEqual([v.category]))
    await v.pick(v.weapon, 'FOIL')
    await v.pick(v.gender, 'F')
    await waitFor(() => expect(active()).toEqual([v.weapon, v.category, v.gender]))
  })
})

describe('EntryList — clearing the search and the filters (FR-165, S2, S3)', () => {
  afterEach(() => setLocale('pl'))
  const clearSearch = (c: HTMLElement) => c.querySelector('button.el-search-clear') as HTMLButtonElement | null

  // ELSEL.12
  it('shows a × only with search text, and it empties the search alone', async () => {
    const v = await renderSel()
    expect(clearSearch(v.c)).toBeNull()
    await v.pick(v.category, 'V2')
    await waitFor(() => expect(v.tiles()[0]).toBe('4 z 8'))
    expect(clearSearch(v.c)).toBeNull()
    await v.type('kow')
    await waitFor(() => expect(clearSearch(v.c)).not.toBeNull())
    await fireEvent.click(clearSearch(v.c) as HTMLButtonElement)
    await waitFor(() => expect(v.search.value).toBe(''))
    expect(v.category.value).toBe('V2')
    expect(v.tiles()).toEqual(['4 z 8', '3 z 5', '2 z 3', '1 z 2'])
    expect(clearSearch(v.c)).toBeNull()
  })

  // ELSEL.14 (the ×)
  it('makes the × a button named in the page language', async () => {
    const v = await renderSel()
    await v.type('kow')
    await waitFor(() => expect(clearSearch(v.c)).not.toBeNull())
    expect(clearSearch(v.c)?.type).toBe('button')
    expect(clearSearch(v.c)?.getAttribute('aria-label')).toBe('Wyczyść wyszukiwanie')
    await fireEvent.click(v.c.querySelector('.lang-btn[aria-label="English"]') as HTMLButtonElement)
    await waitFor(() => expect(clearSearch(v.c)?.getAttribute('aria-label')).toBe('Clear search'))
  })

  const clearAll = (c: HTMLElement) => c.querySelector('button.el-clear-all') as HTMLButtonElement | null

  // ELSEL.13
  it('shows the clear link only while narrowed, and it resets the search and all three filters', async () => {
    const v = await renderSel()
    expect(clearAll(v.c)).toBeNull()
    // Each of the four inputs alone brings the link.
    for (const apply of [
      () => v.type('kow'),
      () => v.pick(v.weapon, 'FOIL'),
      () => v.pick(v.category, 'V1'),
      () => v.pick(v.gender, 'F'),
    ]) {
      await apply()
      await waitFor(() => expect(clearAll(v.c)).not.toBeNull())
      await fireEvent.click(clearAll(v.c) as HTMLButtonElement)
      await waitFor(() => expect(clearAll(v.c)).toBeNull())
    }
    // All four at once, cleared in one tap.
    await v.type('a')
    await v.pick(v.weapon, 'EPEE')
    await v.pick(v.category, 'V2')
    await v.pick(v.gender, 'M')
    await waitFor(() => expect(clearAll(v.c)).not.toBeNull())
    await fireEvent.click(clearAll(v.c) as HTMLButtonElement)
    await waitFor(() => expect(v.tiles()).toEqual(PLAIN))
    expect([v.search.value, v.weapon.value, v.category.value, v.gender.value]).toEqual(['', '', '', ''])
    expect(renderedNames(v.c)).toHaveLength(8)
    expect(clearAll(v.c)).toBeNull()
  })

  // ELSEL.14 (the link)
  it('makes the clear link a button named in the page language', async () => {
    const v = await renderSel()
    await v.pick(v.category, 'V2')
    await waitFor(() => expect(clearAll(v.c)).not.toBeNull())
    expect(clearAll(v.c)?.type).toBe('button')
    expect(clearAll(v.c)?.textContent?.trim()).toBe('Wyczyść filtry')
    await fireEvent.click(v.c.querySelector('.lang-btn[aria-label="English"]') as HTMLButtonElement)
    await waitFor(() => expect(clearAll(v.c)?.textContent?.trim()).toBe('Clear filters'))
  })
})

describe('EntryList — a chosen weapon dims the other weapon tiles (FR-165, S4)', () => {
  // ELSEL.15
  it('dims only the two weapon tiles other than the chosen one', async () => {
    const v = await renderSel()
    const dimmed = () =>
      Array.from(v.c.querySelectorAll('.el-metrics .el-metric')).map((m) => m.classList.contains('el-dim'))
    expect(dimmed()).toEqual([false, false, false, false])
    await v.pick(v.weapon, 'EPEE')
    await waitFor(() => expect(dimmed()).toEqual([false, false, true, true]))
    await v.pick(v.weapon, 'SABRE')
    await waitFor(() => expect(dimmed()).toEqual([false, true, true, false]))
    await v.pick(v.weapon, '')
    await v.pick(v.category, 'V2')
    await waitFor(() => expect(v.tiles()[0]).toBe('4 z 8'))
    expect(dimmed()).toEqual([false, false, false, false])
  })
})

describe('EntryList — the search folds diacritics (FR-165, issue 1)', () => {
  // ELSEL.16
  it('finds a name whatever the visitor does with the Polish letters', async () => {
    const v = await renderSel()
    await v.type('zak')
    await waitFor(() => expect(renderedNames(v.c)).toEqual(['ŻAK Adam']))
    await v.type('los')
    await waitFor(() => expect(renderedNames(v.c)).toEqual(['ŁOŚ Ewa']))
    await v.type('ŻAK')
    await waitFor(() => expect(renderedNames(v.c)).toEqual(['ŻAK Adam']))
    await v.type('pawel')
    await waitFor(() => expect(renderedNames(v.c)).toEqual(['lis Paweł']))
  })
})

// ---------------------------------------------------------------------------
// FR-166 — an administrator removes an entry (ELREM.01–11). The setting is
// passed only by the admin application's calendar; see RegistrationModal and
// CalendarView tests for ELREM.12 and EntryListElement for ELREM.13.
// ---------------------------------------------------------------------------

const mockDelete = vi.mocked(deleteRegistration)

const PL_OPEN_F = 'Tej operacji nie można cofnąć. Zawodniczka może zgłosić się ponownie przed końcem terminu zapisów.'
const PL_OPEN_M = 'Tej operacji nie można cofnąć. Zawodnik może zgłosić się ponownie przed końcem terminu zapisów.'
const PL_CLOSED = 'Tej operacji nie można cofnąć. Termin zapisów już minął.'

async function renderRem(props: Record<string, unknown> = {}) {
  mockFetchEntryList.mockResolvedValue(SEL)
  const view = render(EntryList, {
    props: { eventId: 3, canRemove: true, eventName: 'PEW5 Łomianki', registrationOpen: true, ...props },
  })
  const c = view.container
  await waitFor(() => expect(c.querySelector('td.el-name')).not.toBeNull())
  const search = c.querySelector('input[name="search"]') as HTMLInputElement
  const type = (value: string) => fireEvent.input(search, { target: { value } })
  const tiles = () =>
    Array.from(c.querySelectorAll('.el-metrics .el-metric .el-v')).map((v) =>
      (v.textContent ?? '').replace(/\s+/g, ' ').trim(),
    )
  /** The row of `name`'s own „Usuń” button. */
  const removeOf = (name: string) => {
    const row = Array.from(c.querySelectorAll('tbody tr')).find(
      (tr) => tr.querySelector('td.el-name')?.textContent?.trim() === name,
    )
    return row?.querySelector('button.el-remove') as HTMLButtonElement
  }
  const dialog = () => c.querySelector('[role="alertdialog"]') as HTMLElement | null
  const text = (el: Element | null) => (el?.textContent ?? '').replace(/\s+/g, ' ').trim()
  const confirmBtn = () => c.querySelector('button.el-remove-confirm') as HTMLButtonElement
  const cancelBtn = () => c.querySelector('button.el-remove-cancel') as HTMLButtonElement
  return { ...view, c, type, tiles, removeOf, dialog, text, confirmBtn, cancelBtn }
}

describe('EntryList — an administrator removes an entry (FR-166)', () => {
  afterEach(() => setLocale('pl'))

  // ELREM.01 — guard: holds before the change; proven by a mutation run.
  it('shows no remove control without the administrator setting', async () => {
    const v = await renderSel()
    expect(v.c.querySelector('button.el-remove')).toBeNull()
    expect(v.c.querySelectorAll('thead th')).toHaveLength(3)
    expect(v.c.querySelector('[role="alertdialog"]')).toBeNull()
  })

  // ELREM.02
  it('gives every listed row one „Usuń” button with the setting', async () => {
    const v = await renderRem()
    const rows = v.c.querySelectorAll('tbody tr')
    expect(rows).toHaveLength(8)
    rows.forEach((tr) => expect(tr.querySelectorAll('button.el-remove')).toHaveLength(1))
    expect(v.removeOf('ŻAK Adam').textContent?.trim()).toBe('Usuń')
    await v.type('kowal')
    await waitFor(() => expect(v.c.querySelectorAll('button.el-remove')).toHaveLength(2))
  })

  // ELREM.03
  it('asks for confirmation naming the fencer, weapons, category and event', async () => {
    const v = await renderRem()
    await fireEvent.click(v.removeOf('KOWAL Jan'))
    const d = v.dialog()
    expect(d).not.toBeNull()
    expect(v.text(d)).toContain('Usunąć zgłoszenie?')
    expect(v.text(d)).toContain('KOWAL Jan · szpada, szabla · V2')
    expect(v.text(d)).toContain('PEW5 Łomianki')
    expect(v.confirmBtn().textContent?.trim()).toBe('Usuń zgłoszenie')
    expect(v.cancelBtn().textContent?.trim()).toBe('Anuluj')
    expect(mockDelete).not.toHaveBeenCalled()
  })

  // ELREM.04
  it('closes on „Anuluj” and on Escape without deleting', async () => {
    const v = await renderRem()
    await fireEvent.click(v.removeOf('ŻAK Adam'))
    await fireEvent.click(v.cancelBtn())
    expect(v.dialog()).toBeNull()
    await fireEvent.click(v.removeOf('ŻAK Adam'))
    expect(v.dialog()).not.toBeNull()
    // The dialog takes focus when it opens, so a real Escape lands on it (the
    // calendar's modal stops key events from reaching the window).
    expect(v.dialog()!.contains(document.activeElement)).toBe(true)
    await fireEvent.keyDown(document.activeElement as Element, { key: 'Escape' })
    expect(v.dialog()).toBeNull()
    expect(mockDelete).not.toHaveBeenCalled()
    expect(v.c.querySelectorAll('tbody tr')).toHaveLength(8)
  })

  // ELREM.05
  it('deletes that row once on confirming, drops it and names the fencer', async () => {
    mockDelete.mockResolvedValue(undefined)
    const v = await renderRem()
    await fireEvent.click(v.removeOf('ŻAK Adam'))
    await fireEvent.click(v.confirmBtn())
    await waitFor(() => expect(v.dialog()).toBeNull())
    expect(mockDelete).toHaveBeenCalledTimes(1)
    expect(mockDelete).toHaveBeenCalledWith(1)
    expect(v.removeOf('ŻAK Adam')).toBeUndefined()
    expect(v.c.querySelectorAll('tbody tr')).toHaveLength(7)
    expect(v.text(v.c.querySelector('.el-remove-done'))).toBe('✓ Usunięto zgłoszenie: ŻAK Adam')
    // The closed confirmation hands focus to the done line, which brings it
    // into view after a removal far down the list (found in the pixel sheet).
    await waitFor(() => expect(document.activeElement).toBe(v.c.querySelector('.el-remove-done')))
  })

  // ELREM.06
  it('counts the tiles down, and both figures while narrowed', async () => {
    mockDelete.mockResolvedValue(undefined)
    const v = await renderRem()
    expect(v.tiles()).toEqual(['8', '5', '3', '2'])
    await v.type('kowal')
    await waitFor(() => expect(v.tiles()).toEqual(['2 z 8', '2 z 5', '0 z 3', '1 z 2']))
    await fireEvent.click(v.removeOf('KOWAL Jan'))
    await fireEvent.click(v.confirmBtn())
    await waitFor(() => expect(v.tiles()).toEqual(['1 z 7', '1 z 4', '0 z 3', '0 z 1']))
    await v.type('')
    await waitFor(() => expect(v.tiles()).toEqual(['7', '4', '3', '1']))
  })

  // ELREM.07
  it('keeps the row and the tiles when the delete fails, and says so', async () => {
    mockDelete.mockRejectedValue(new Error('refused'))
    const v = await renderRem()
    await fireEvent.click(v.removeOf('ŻAK Adam'))
    await fireEvent.click(v.confirmBtn())
    await waitFor(() => expect(v.c.querySelector('.el-remove-failed')).not.toBeNull())
    expect(v.text(v.c.querySelector('.el-remove-failed'))).toBe('Nie udało się usunąć zgłoszenia. Spróbuj ponownie.')
    expect(v.removeOf('ŻAK Adam')).toBeDefined()
    expect(v.tiles()).toEqual(['8', '5', '3', '2'])
    expect(v.c.querySelector('.el-remove-done')).toBeNull()
  })

  // ELREM.08
  it('disables the confirm button while the delete is in flight', async () => {
    let finish!: () => void
    mockDelete.mockReturnValue(new Promise<void>((r) => (finish = r)))
    const v = await renderRem()
    await fireEvent.click(v.removeOf('ŻAK Adam'))
    await fireEvent.click(v.confirmBtn())
    expect(v.confirmBtn().disabled).toBe(true)
    await fireEvent.click(v.confirmBtn())
    expect(mockDelete).toHaveBeenCalledTimes(1)
    finish()
    await waitFor(() => expect(v.dialog()).toBeNull())
    expect(mockDelete).toHaveBeenCalledTimes(1)
  })

  // ELREM.09
  it('names „Zawodniczka” for a woman and „Zawodnik” for a man', async () => {
    const v = await renderRem()
    await fireEvent.click(v.removeOf('KOWAL Anna'))
    expect(v.text(v.dialog())).toContain(PL_OPEN_F)
    await fireEvent.click(v.cancelBtn())
    await fireEvent.click(v.removeOf('ŻAK Adam'))
    expect(v.text(v.dialog())).toContain(PL_OPEN_M)
  })

  // ELREM.10
  it('says the deadline has passed when registration is closed', async () => {
    const v = await renderRem({ registrationOpen: false })
    await fireEvent.click(v.removeOf('KOWAL Anna'))
    expect(v.text(v.dialog())).toContain(PL_CLOSED)
    expect(v.text(v.dialog())).not.toContain('zgłosić się ponownie')
  })

  // ELREM.11
  it('speaks English after the language switch', async () => {
    setLocale('en')
    mockDelete.mockRejectedValueOnce(new Error('refused')).mockResolvedValueOnce(undefined)
    const v = await renderRem()
    expect(v.removeOf('KOWAL Anna').textContent?.trim()).toBe('Remove')
    await fireEvent.click(v.removeOf('KOWAL Anna'))
    expect(v.text(v.dialog())).toContain('Remove this entry?')
    expect(v.text(v.dialog())).toContain('KOWAL Anna · épée · V1')
    expect(v.text(v.dialog())).toContain('This cannot be undone. The fencer can register again before the registration deadline.')
    expect(v.confirmBtn().textContent?.trim()).toBe('Remove entry')
    expect(v.cancelBtn().textContent?.trim()).toBe('Cancel')
    await fireEvent.click(v.confirmBtn())
    await waitFor(() =>
      expect(v.text(v.c.querySelector('.el-remove-failed'))).toBe('The entry could not be removed. Try again.'),
    )
    await fireEvent.click(v.confirmBtn())
    await waitFor(() => expect(v.text(v.c.querySelector('.el-remove-done'))).toBe('✓ Entry removed: KOWAL Anna'))
  })

  it('speaks English when registration is closed', async () => {
    setLocale('en')
    const v = await renderRem({ registrationOpen: false })
    await fireEvent.click(v.removeOf('KOWAL Anna'))
    expect(v.text(v.dialog())).toContain('This cannot be undone. The registration deadline has passed.')
  })
})

// RFNAME.09 (FR-167) — a title is not part of the surname for ordering or
// searching. Before release 1 a titled surname sorted under D.
describe('EntryList — RFNAME.09 a title is ignored for order and search', () => {
  const TITLED: RegistrationEntry[] = [
    { id_registration: 11, id_event: 3, txt_surname: 'WOLF', txt_first_name: 'Eva', enum_gender: 'F', arr_weapons: ['EPEE'], enum_age_category: 'V1' },
    { id_registration: 12, id_event: 3, txt_surname: 'Dr. VERESS', txt_first_name: 'Ilona Katalin', enum_gender: 'F', arr_weapons: ['EPEE'], enum_age_category: 'V1' },
    { id_registration: 13, id_event: 3, txt_surname: 'DUDA', txt_first_name: 'Ewa', enum_gender: 'F', arr_weapons: ['EPEE'], enum_age_category: 'V1' },
  ]

  it('orders by the surname without its title', async () => {
    mockFetchEntryList.mockResolvedValue(TITLED)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('Dr. VERESS Ilona Katalin')
    const names = Array.from(container.querySelectorAll('td.el-name')).map((td) => td.textContent)
    expect(names).toEqual(['DUDA Ewa', 'Dr. VERESS Ilona Katalin', 'WOLF Eva'])
  })

  it('searches by the surname without its title', async () => {
    mockFetchEntryList.mockResolvedValue(TITLED)
    const { container, findByText } = render(EntryList, { props: { eventId: 3 } })
    await findByText('DUDA Ewa')
    const search = container.querySelector('input[name="search"]') as HTMLInputElement
    await fireEvent.input(search, { target: { value: 'vere' } })
    let names = Array.from(container.querySelectorAll('td.el-name')).map((td) => td.textContent)
    expect(names).toEqual(['Dr. VERESS Ilona Katalin'])
    await fireEvent.input(search, { target: { value: 'dr' } })
    names = Array.from(container.querySelectorAll('td.el-name')).map((td) => td.textContent)
    expect(names).toEqual([])
  })
})

describe('EntryList — FR-169 the country (RFCTRY.06–17)', () => {
  const C: RegistrationEntry[] = [
    { id_registration: 11, id_event: 3, txt_surname: 'KOWALSKA', txt_first_name: 'Anna', enum_gender: 'F', arr_weapons: ['FOIL'], enum_age_category: 'V1', txt_country: 'POL' },
    { id_registration: 12, id_event: 3, txt_surname: 'MÜLLER', txt_first_name: 'Hans', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V2', txt_country: 'GER' },
    { id_registration: 13, id_event: 3, txt_surname: 'NEUTRAL', txt_first_name: 'Ivan', enum_gender: 'M', arr_weapons: ['EPEE', 'SABRE'], enum_age_category: 'V3', txt_country: 'AIN' },
    { id_registration: 14, id_event: 3, txt_surname: 'NOWAK', txt_first_name: 'Piotr', enum_gender: 'M', arr_weapons: ['SABRE'], enum_age_category: 'V2', txt_country: null },
    { id_registration: 15, id_event: 3, txt_surname: 'SCHMIDT', txt_first_name: 'Eva', enum_gender: 'F', arr_weapons: ['EPEE'], enum_age_category: 'V1', txt_country: 'GER' },
    { id_registration: 16, id_event: 3, txt_surname: 'SMITH', txt_first_name: 'John', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V0', txt_country: 'GBR' },
  ]

  async function open(rows: RegistrationEntry[] = C) {
    mockFetchEntryList.mockResolvedValue(rows)
    const r = render(EntryList, { props: { eventId: 3 } })
    await r.findByText(`${rows[0].txt_surname} ${rows[0].txt_first_name}`)
    return r
  }
  const rowOf = (c: HTMLElement, name: string) => [...c.querySelectorAll('tbody tr')].find((tr) => tr.textContent?.includes(name)) as HTMLTableRowElement
  const names = (c: HTMLElement) => [...c.querySelectorAll('td.el-name')].map((td) => td.textContent?.trim())
  const country = (c: HTMLElement) => c.querySelector('select[name="countryFilter"]') as HTMLSelectElement | null

  afterEach(() => setLocale('pl'))

  it('RFCTRY.06 each line ends with the flag alone, labelled with the country name', async () => {
    const { container } = await open()
    const cells = [...rowOf(container, 'MÜLLER').querySelectorAll('td')]
    const last = cells[cells.length - 1]
    expect(last.classList.contains('el-flag')).toBe(true)
    const flag = last.querySelector('.flag') as HTMLElement
    expect(flag.getAttribute('aria-label')).toBe('Niemcy')
    expect(flag.getAttribute('title')).toBe('Niemcy')
    expect(last.textContent?.trim()).toBe('')
    // No code on any line; the codes are only the „Kraj” filter's choices (RFCTRY.12).
    expect(container.querySelector('tbody')?.textContent).not.toContain('GER')
  })

  it('RFCTRY.06 the label follows the page language', async () => {
    setLocale('en')
    const { container } = await open()
    expect(rowOf(container, 'MÜLLER').querySelector('.flag')?.getAttribute('aria-label')).toBe('Germany')
  })

  it('RFCTRY.07 an entry without a country shows nothing there', async () => {
    const { container } = await open()
    const cell = rowOf(container, 'NOWAK').querySelector('td.el-flag') as HTMLElement
    expect(cell.children.length).toBe(0)
    expect(cell.textContent?.trim()).toBe('')
  })

  it('RFCTRY.08 a list where no entry has a country keeps no room for a flag', async () => {
    const { container } = await open(ROWS)
    expect(container.querySelector('td.el-flag')).toBeNull()
    expect(container.querySelector('th.el-flag')).toBeNull()
    expect(container.querySelectorAll('thead th').length).toBe(3)
  })

  it('RFCTRY.09 the flag stands after the name, the category and the weapons; the name keeps its shortening class', async () => {
    const { container } = await open()
    const cells = [...rowOf(container, 'SMITH').querySelectorAll('td')].map((td) => td.className.split(' ')[0])
    expect(cells[0]).toBe('el-name')
    expect(cells[cells.length - 1]).toBe('el-flag')
  })

  it('RFCTRY.10 a code without a drawn flag shows its letters in the flag place, labelled with its name', async () => {
    const { container } = await open()
    const cell = rowOf(container, 'NEUTRAL').querySelector('td.el-flag') as HTMLElement
    const code = cell.querySelector('.el-flagcode') as HTMLElement
    expect(code.textContent).toBe('AIN')
    expect(code.getAttribute('aria-label')).toBe('Indywidualni Sportowcy Neutralni')
    expect(cell.querySelector('.flag')).toBeNull()
  })

  it('RFCTRY.11 „Kraj” is offered only when an entry has a country', async () => {
    const a = await open()
    expect(country(a.container)).not.toBeNull()
    a.unmount()
    const b = await open(ROWS)
    expect(country(b.container)).toBeNull()
  })

  it('RFCTRY.12 its choices are the codes present, in code order, codes alone', async () => {
    const { container } = await open()
    expect([...country(container)!.options].map((o) => o.textContent?.trim())).toEqual(['--', 'AIN', 'GBR', 'GER', 'POL'])
  })

  it('RFCTRY.13 a code lists only its entries; entries without a country leave once one is chosen', async () => {
    const { container } = await open()
    expect(names(container)).toContain('NOWAK Piotr')
    await fireEvent.change(country(container)!, { target: { value: 'GER' } })
    expect(names(container)).toEqual(['MÜLLER Hans', 'SCHMIDT Eva'])
  })

  it('RFCTRY.14 it works with the search and every other filter', async () => {
    const { container } = await open()
    await fireEvent.change(country(container)!, { target: { value: 'GER' } })
    await fireEvent.change(container.querySelector('select[name="genderFilter"]') as HTMLSelectElement, { target: { value: 'F' } })
    expect(names(container)).toEqual(['SCHMIDT Eva'])
    await fireEvent.change(container.querySelector('select[name="genderFilter"]') as HTMLSelectElement, { target: { value: '' } })
    await fireEvent.change(container.querySelector('select[name="weaponFilter"]') as HTMLSelectElement, { target: { value: 'EPEE' } })
    await fireEvent.change(container.querySelector('select[name="categoryFilter"]') as HTMLSelectElement, { target: { value: 'V2' } })
    expect(names(container)).toEqual(['MÜLLER Hans'])
    await fireEvent.change(container.querySelector('select[name="categoryFilter"]') as HTMLSelectElement, { target: { value: '' } })
    await fireEvent.input(container.querySelector('input[name="search"]') as HTMLInputElement, { target: { value: 'schm' } })
    expect(names(container)).toEqual(['SCHMIDT Eva'])
  })

  it('RFCTRY.15 it follows FR-165: tiles, frame, highlight and „Wyczyść filtry”', async () => {
    const { container } = await open()
    const sel = country(container)!
    await fireEvent.change(sel, { target: { value: 'GER' } })
    expect(container.querySelector('.el-metrics')?.classList.contains('el-narrowed')).toBe(true)
    expect(container.querySelector('.el-metric .el-v')?.textContent?.replace(/\s+/g, ' ').trim()).toBe('2 z 6')
    expect(sel.classList.contains('el-active')).toBe(true)
    await fireEvent.click(container.querySelector('.el-clear-all') as HTMLButtonElement)
    expect(sel.value).toBe('')
    expect(names(container).length).toBe(6)
  })

  it('RFCTRY.16 with „Kraj” the filters stand as four', async () => {
    const { container } = await open()
    const group = container.querySelector('.el-fgroup') as HTMLElement
    expect(group.classList.contains('el-four')).toBe(true)
    expect(group.querySelectorAll('select').length).toBe(4)
  })

  it('RFCTRY.17 without „Kraj” the three filters stand as before', async () => {
    const { container } = await open(ROWS)
    const group = container.querySelector('.el-fgroup') as HTMLElement
    expect(group.classList.contains('el-four')).toBe(false)
    expect(group.querySelectorAll('select').length).toBe(3)
  })
})

// ---------------------------------------------------------------------------
// FR-170 — a signed-in administrator edits an entry (RFADM.01, 05, 08, 14).
// The dialog itself is pinned in EntryEdit.test.ts.
// ---------------------------------------------------------------------------
const mockDetails = vi.mocked(fetchAdminEntryDetails)
const mockUpdate = vi.mocked(updateRegistrationAsAdmin)

// ŻAK Adam a newcomer; NOWAK Piotr linked, the roster says another year;
// KOWAL Jan linked, the same year.
const DETAILS = [
  { id_registration: 1, int_birth_year: 1975, txt_club: null, txt_country: null, id_fencer: null, txt_name_source: 'TYPED', roster_birth_year: null },
  { id_registration: 6, int_birth_year: 1980, txt_club: 'AZS', txt_country: null, id_fencer: 12, txt_name_source: 'TYPED', roster_birth_year: 1984 },
  { id_registration: 3, int_birth_year: 1972, txt_club: null, txt_country: null, id_fencer: 13, txt_name_source: 'TYPED', roster_birth_year: 1972 },
]

async function renderEdit(props: Record<string, unknown> = {}) {
  mockDetails.mockResolvedValue(DETAILS)
  const v = await renderRem(props)
  await waitFor(() => expect(mockDetails).toHaveBeenCalledWith(3))
  const editOf = (name: string) => {
    const row = Array.from(v.c.querySelectorAll('tbody tr')).find(
      (tr) => tr.querySelector('td.el-name')?.textContent?.trim() === name,
    )
    return row?.querySelector('button.el-edit') as HTMLButtonElement
  }
  const markOf = (name: string) => {
    const row = Array.from(v.c.querySelectorAll('tbody tr')).find(
      (tr) => tr.querySelector('td.el-name')?.textContent?.trim() === name,
    )
    return row?.querySelector('.el-yeardiff') ?? null
  }
  const editDialog = () => v.c.querySelector('[role="dialog"]') as HTMLElement | null
  return { ...v, editOf, markOf, editDialog }
}

describe('EntryList — an administrator edits an entry (FR-170)', () => {
  afterEach(() => setLocale('pl'))

  // RFADM.01
  it('gives every row „Edytuj” beside „Usuń” only while an administrator is signed in', async () => {
    const v = await renderEdit()
    const rows = v.c.querySelectorAll('tbody tr')
    expect(rows).toHaveLength(8)
    rows.forEach((tr) => {
      // classList[0]: Svelte adds its own scoping class after the component's.
      const acts = Array.from(tr.querySelectorAll('td.el-act button')).map((b) => b.classList[0])
      expect(acts).toEqual(['el-edit', 'el-remove'])
    })
    const edit = v.editOf('ŻAK Adam')
    expect(edit.textContent?.trim()).toBe('Edytuj')
    expect(edit.getAttribute('aria-label')).toBe('Edytuj zgłoszenie: ŻAK Adam')
  })

  it('a visitor\'s list has no „Edytuj” and reads no entry details', async () => {
    const v = await renderSel()
    expect(v.c.querySelector('button.el-edit')).toBeNull()
    expect(v.c.querySelector('.el-yeardiff')).toBeNull()
    expect(mockDetails).not.toHaveBeenCalled()
  })

  // RFADM.05
  it('opens the dialog for that entry, and a confirmed save reloads the list and names the fencer', async () => {
    mockUpdate.mockResolvedValue(undefined)
    const v = await renderEdit()
    await fireEvent.click(v.editOf('ŻAK Adam'))
    expect(v.editDialog()).not.toBeNull()
    expect((v.c.querySelector('[role="dialog"] input[name="surname"]') as HTMLInputElement).value).toBe('ŻAK')
    // The database answers with the stored form; the list shows what it holds.
    mockFetchEntryList.mockResolvedValue(SEL.map((r) => (r.id_registration === 1 ? { ...r, txt_surname: 'ŻAKOWSKI' } : r)))
    await fireEvent.click(v.c.querySelector('button.ee-save') as HTMLButtonElement)
    await waitFor(() => expect(v.editDialog()).toBeNull())
    expect(mockUpdate).toHaveBeenCalledTimes(1)
    expect(mockUpdate.mock.calls[0][0]).toBe(1)
    await waitFor(() => expect(v.text(v.c.querySelector('.el-edit-done'))).toBe('✓ Zapisano zmiany: ŻAKOWSKI Adam'))
    expect(mockFetchEntryList).toHaveBeenCalledTimes(2)
    expect(v.editOf('ŻAKOWSKI Adam')).toBeDefined()
    await waitFor(() => expect(document.activeElement).toBe(v.c.querySelector('.el-edit-done')))
  })

  it('a refused save keeps the dialog and the list as they were', async () => {
    mockUpdate.mockRejectedValue(new Error('refused'))
    const v = await renderEdit()
    await fireEvent.click(v.editOf('ŻAK Adam'))
    await fireEvent.click(v.c.querySelector('button.ee-save') as HTMLButtonElement)
    await waitFor(() => expect(v.c.querySelector('.ee-error')).not.toBeNull())
    expect(v.editDialog()).not.toBeNull()
    expect(mockFetchEntryList).toHaveBeenCalledTimes(1)
    expect(v.c.querySelector('.el-edit-done')).toBeNull()
  })

  it('„Anuluj” closes the dialog and changes nothing', async () => {
    const v = await renderEdit()
    await fireEvent.click(v.editOf('NOWAK Piotr'))
    await fireEvent.click(v.c.querySelector('button.ee-cancel') as HTMLButtonElement)
    expect(v.editDialog()).toBeNull()
    expect(mockUpdate).not.toHaveBeenCalled()
    expect(mockFetchEntryList).toHaveBeenCalledTimes(1)
  })

  // RFADM.08
  it('signing out closes an open dialog', async () => {
    const v = await renderEdit()
    await fireEvent.click(v.editOf('ŻAK Adam'))
    expect(v.editDialog()).not.toBeNull()
    await v.rerender({ canRemove: false })
    await waitFor(() => expect(v.editDialog()).toBeNull())
    expect(v.c.querySelector('button.el-edit')).toBeNull()
  })

  // RFADM.14
  it('marks an entry whose declared year differs from the roster\'s, and only that one', async () => {
    const v = await renderEdit()
    await waitFor(() => expect(v.markOf('NOWAK Piotr')).not.toBeNull())
    const mark = v.markOf('NOWAK Piotr')!
    expect(mark.textContent?.trim()).toBe('≠')
    expect(mark.getAttribute('aria-label')).toBe('Rok urodzenia różni się od bazy zawodników')
    expect(v.markOf('KOWAL Jan')).toBeNull()
    expect(v.markOf('ŻAK Adam')).toBeNull()
    expect(v.c.querySelectorAll('.el-yeardiff')).toHaveLength(1)
  })

  it('speaks English', async () => {
    setLocale('en')
    mockUpdate.mockResolvedValue(undefined)
    const v = await renderEdit()
    expect(v.editOf('ŻAK Adam').textContent?.trim()).toBe('Edit')
    expect(v.editOf('ŻAK Adam').getAttribute('aria-label')).toBe('Edit entry: ŻAK Adam')
    await waitFor(() => expect(v.markOf('NOWAK Piotr')?.getAttribute('aria-label')).toBe('The birth year differs from the fencer roster'))
    await fireEvent.click(v.editOf('ŻAK Adam'))
    await fireEvent.click(v.c.querySelector('button.ee-save') as HTMLButtonElement)
    await waitFor(() => expect(v.text(v.c.querySelector('.el-edit-done'))).toBe('✓ Changes saved: ŻAK Adam'))
  })
})

// I25 A (release 4 sheet §04, approved 22 Nov 2026) — a phone row draws „…”
// for a name that does not fit, and a signed-in row puts its actions on a
// line of their own under the name. jsdom lays nothing out, so these read the
// phone rules from the component's own stylesheet; the 375 px captures measure
// the result in a real browser.
function phoneRule(selector: RegExp): CSSStyleDeclaration | null {
  for (const sheet of Array.from(document.styleSheets)) {
    for (const rule of Array.from(sheet.cssRules)) {
      if (!(rule instanceof CSSMediaRule) || !rule.conditionText.includes('max-width: 480px')) continue
      for (const inner of Array.from(rule.cssRules)) {
        if (inner instanceof CSSStyleRule && selector.test(inner.selectorText)) return inner.style
      }
    }
  }
  return null
}

describe('EntryList — I25 a phone row with a long name', () => {
  it('the name cell is a block on a phone, so the browser draws „…”', async () => {
    await renderRem({ canRemove: false })
    const s = phoneRule(/^\.el-name\.svelte-[\w-]+$/)
    expect(s?.display).toBe('block')
    expect(s?.textOverflow).toBe('ellipsis')
  })

  it('a signed-in row wraps on a phone, its actions on a line of their own', async () => {
    const v = await renderRem()
    const rows = Array.from(v.c.querySelectorAll('tbody tr'))
    expect(rows.length).toBeGreaterThan(0)
    expect(rows.every((tr) => tr.classList.contains('el-adminrow'))).toBe(true)
    expect(phoneRule(/^tr\.el-adminrow\.svelte-[\w-]+$/)?.flexWrap).toBe('wrap')
    const act = phoneRule(/^\.el-adminrow\.svelte-[\w-]+ \.el-act(\.svelte-[\w-]+|:where\(\.svelte-[\w-]+\))$/)
    expect(act?.flexBasis).toBe('100%')
    // The name starts from no width and takes what the chips leave, so a long
    // name never pushes the category, weapon and flag off its line.
    expect(phoneRule(/^\.el-adminrow\.svelte-[\w-]+ \.el-name(\.svelte-[\w-]+|:where\(\.svelte-[\w-]+\))$/)?.flexBasis).toBe('0px')
  })

  it('a visitor\'s row stays one line', async () => {
    const v = await renderRem({ canRemove: false })
    expect(v.c.querySelector('tbody tr.el-adminrow')).toBeNull()
  })
})

// ---------------------------------------------------------------------------
// FR-175 — the ranking place, once weapon, category and gender are chosen
// (ELRANK.11–20). Plan doc/plans/seeding-by-organiser-ranking-2026-11-22.html,
// release 2, step 4. Invented entries (SEL). Épée V2 men: ŻAK Adam (1),
// KOWAL Jan (3), NOWAK Piotr (6); alphabetically KOWAL, NOWAK, ŻAK.
// ---------------------------------------------------------------------------
const mockRanks = vi.mocked(fetchEntryRanks)
const READ = '2026-11-23T05:41:00Z'

function rank(id: number, weapon: EntryRank['enum_weapon'], category: EntryRank['enum_age_category'],
  place: number | null, seed: number | null, ranking: 'EVF' | 'SPWS' = 'EVF'): EntryRank {
  return {
    id_registration: id, enum_weapon: weapon, enum_age_category: category, int_rank: place,
    int_seed_order: seed, txt_ranking: ranking, ts_ranking_read: ranking === 'EVF' ? READ : null,
  }
}

// ŻAK and NOWAK share 3rd place; the seed order puts ŻAK first. KOWAL Jan is
// unranked in épée and 7th in sabre. Women's épée V1: KOWAL Anna 12th.
const RANKS: EntryRank[] = [
  rank(1, 'EPEE', 'V2', 3, 1),
  rank(6, 'EPEE', 'V2', 3, 2),
  rank(3, 'EPEE', 'V2', null, null),
  rank(3, 'SABRE', 'V2', 7, 1),
  rank(4, 'EPEE', 'V1', 12, 1),
  rank(6, 'FOIL', 'V2', null, null),
]

async function renderRanked(ranks: EntryRank[] = RANKS, rows: RegistrationEntry[] = SEL) {
  mockRanks.mockResolvedValue(ranks)
  const v = await renderSel(rows)
  await waitFor(() => expect(mockRanks).toHaveBeenCalledWith(3))
  const three = async (weapon = 'EPEE', category = 'V2', gender = 'M') => {
    await v.pick(v.weapon, weapon)
    await v.pick(v.category, category)
    await v.pick(v.gender, gender)
  }
  const rankCells = () => Array.from(v.c.querySelectorAll('tbody td.el-rank')).map((td) => td.textContent?.trim())
  const header = () => Array.from(v.c.querySelectorAll('thead th')).map((th) => th.textContent?.trim())
  const rankLegend = () => v.c.querySelector('.el-rank-legend')?.textContent?.trim() ?? null
  return { ...v, three, rankCells, header, rankLegend }
}

describe('EntryList — the ranking place (FR-175)', () => {
  afterEach(() => setLocale('pl'))

  // ELRANK.11
  it('ELRANK.11: with no ranks the list is as before whatever the filters', async () => {
    const v = await renderRanked([])
    await v.three()
    expect(v.c.querySelector('.el-rank')).toBeNull()
    expect(renderedNames(v.c)).toEqual(['KOWAL Jan', 'NOWAK Piotr', 'ŻAK Adam'])
    expect(v.rankLegend()).toBeNull()
  })

  // ELRANK.12
  it('ELRANK.12: one or two of the three filters chosen: no „#”, alphabetical', async () => {
    const v = await renderRanked()
    await v.pick(v.weapon, 'EPEE')
    await v.pick(v.category, 'V2')
    expect(v.c.querySelector('.el-rank')).toBeNull()
    await v.pick(v.category, '')
    await v.pick(v.gender, 'M')
    expect(v.c.querySelector('.el-rank')).toBeNull()
    expect(renderedNames(v.c)).toEqual(['KOWAL Jan', 'lis Paweł', 'NOWAK Piotr', 'ŻAK Adam'])
  })

  // ELRANK.13
  it('ELRANK.13: all three chosen: „#” is the first column and each row starts with its place', async () => {
    const v = await renderRanked()
    await v.three()
    await waitFor(() => expect(v.header()[0]).toBe('#'))
    expect(v.rankCells()).toEqual(['3', '3', '–'])
    v.c.querySelectorAll('tbody tr').forEach((tr) => expect(tr.querySelector('td')?.classList.contains('el-rank')).toBe(true))
  })

  // ELRANK.14
  it('ELRANK.14: the rows are in seed order, a shared place as seeded, the unranked after them alphabetically', async () => {
    const v = await renderRanked([rank(6, 'EPEE', 'V2', 3, 2), rank(1, 'EPEE', 'V2', 3, 1)])
    await v.three()
    await waitFor(() => expect(v.header()[0]).toBe('#'))
    expect(renderedNames(v.c)).toEqual(['ŻAK Adam', 'NOWAK Piotr', 'KOWAL Jan'])
    // Only ŻAK ranked: the other two keep the alphabet after him.
    const w = await renderRanked([rank(1, 'EPEE', 'V2', 9, 1)])
    await w.three()
    await waitFor(() => expect(w.header()[0]).toBe('#'))
    expect(renderedNames(w.c)).toEqual(['ŻAK Adam', 'KOWAL Jan', 'NOWAK Piotr'])
    expect(w.rankCells()).toEqual(['9', '–', '–'])
  })

  // ELRANK.15
  it('ELRANK.15: an entry in two weapons shows the place of the chosen weapon', async () => {
    const v = await renderRanked()
    await v.three('SABRE', 'V2', 'M')
    await waitFor(() => expect(v.header()[0]).toBe('#'))
    expect(renderedNames(v.c)).toEqual(['KOWAL Jan'])
    expect(v.rankCells()).toEqual(['7'])
    await v.pick(v.weapon, 'EPEE')
    expect(renderedNames(v.c)).toEqual(['ŻAK Adam', 'NOWAK Piotr', 'KOWAL Jan'])
    expect(v.rankCells()).toEqual(['3', '3', '–'])
  })

  // ELRANK.16
  it('ELRANK.16: a rank row of another category is not used', async () => {
    // NOWAK's place is on the V1 list, but the list shows him under V2.
    const v = await renderRanked([rank(1, 'EPEE', 'V2', 4, 1), rank(6, 'EPEE', 'V1', 2, 1)])
    await v.three()
    await waitFor(() => expect(v.header()[0]).toBe('#'))
    expect(renderedNames(v.c)).toEqual(['ŻAK Adam', 'KOWAL Jan', 'NOWAK Piotr'])
    expect(v.rankCells()).toEqual(['4', '–', '–'])
  })

  // ELRANK.17
  it('ELRANK.17: three filters chosen and no rank row for any listed entry: no „#”', async () => {
    const v = await renderRanked()
    await v.three('EPEE', 'V0', 'M')
    expect(renderedNames(v.c)).toEqual(['lis Paweł'])
    expect(v.c.querySelector('.el-rank')).toBeNull()
    expect(v.rankLegend()).toBeNull()
  })

  // ELRANK.18
  it('ELRANK.18: the line under the list names the ranking, in Polish and English', async () => {
    const v = await renderRanked()
    expect(v.rankLegend()).toBeNull()
    await v.three()
    await waitFor(() => expect(v.rankLegend()).toBe('# – miejsce w rankingu EVF (stan na 23 listopada 2026). Według niego ustala się rozstawienie do grup.'))
    setLocale('en')
    await waitFor(() => expect(v.rankLegend()).toBe('# – place on the EVF ranking (as of 23 November 2026). Pools are seeded in this order.'))
  })

  it('ELRANK.18: EVF without a read date, and our ranking', async () => {
    const v = await renderRanked([{ ...rank(1, 'EPEE', 'V2', 1, 1), ts_ranking_read: null }])
    await v.three()
    await waitFor(() => expect(v.rankLegend()).toBe('# – miejsce w rankingu EVF. Według niego ustala się rozstawienie do grup.'))
    const w = await renderRanked([rank(1, 'EPEE', 'V2', 1, 1, 'SPWS')])
    await w.three()
    await waitFor(() => expect(w.rankLegend()).toBe('# – miejsce w rankingu SPWS. Według niego ustala się rozstawienie do grup.'))
    setLocale('en')
    await waitFor(() => expect(w.rankLegend()).toBe('# – place on the SPWS ranking. Pools are seeded in this order.'))
  })

  // ELRANK.19
  it('ELRANK.19: clearing a filter or „Wyczyść filtry” returns the alphabet; the search keeps „#”; the tiles count as before', async () => {
    const plain = await renderRanked([])
    await plain.three()
    const tilesWithout = plain.tiles()
    plain.unmount()

    const v = await renderRanked()
    await v.three()
    await waitFor(() => expect(v.header()[0]).toBe('#'))
    expect(v.tiles()).toEqual(tilesWithout)
    await v.type('a')
    expect(renderedNames(v.c)).toEqual(['ŻAK Adam', 'NOWAK Piotr', 'KOWAL Jan'])
    expect(v.header()[0]).toBe('#')
    await v.type('')
    await v.pick(v.gender, '')
    expect(v.c.querySelector('.el-rank')).toBeNull()
    expect(renderedNames(v.c)).toEqual(['KOWAL Jan', 'NOWAK Piotr', 'ŻAK Adam'])
    await v.pick(v.gender, 'M')
    await waitFor(() => expect(v.header()[0]).toBe('#'))
    await fireEvent.click(v.c.querySelector('button.el-clear-all') as HTMLButtonElement)
    expect(v.c.querySelector('.el-rank')).toBeNull()
    expect(renderedNames(v.c)[0]).toBe('ĆWIK Marek')
  })

  it('ELRANK.19: the country filter keeps „#” and the order', async () => {
    const withCountry = SEL.map((r) => ({ ...r, txt_country: r.id_registration === 3 ? 'GER' : 'POL' }))
    const v = await renderRanked(RANKS, withCountry)
    await v.three()
    await waitFor(() => expect(v.header()[0]).toBe('#'))
    await fireEvent.change(v.c.querySelector('select[name="countryFilter"]') as HTMLSelectElement, { target: { value: 'POL' } })
    expect(renderedNames(v.c)).toEqual(['ŻAK Adam', 'NOWAK Piotr'])
    expect(v.rankCells()).toEqual(['3', '3'])
  })

  // ELRANK.20
  it('ELRANK.20: the administrator\'s rows carry the same cell, and an edit reads the ranks again', async () => {
    mockRanks.mockResolvedValue(RANKS)
    mockUpdate.mockResolvedValue(undefined)
    const v = await renderEdit()
    await waitFor(() => expect(mockRanks).toHaveBeenCalledTimes(1))
    const pick = (name: string, value: string) =>
      fireEvent.change(v.c.querySelector(`select[name="${name}"]`) as HTMLSelectElement, { target: { value } })
    await pick('weaponFilter', 'EPEE')
    await pick('categoryFilter', 'V2')
    await pick('genderFilter', 'M')
    await waitFor(() => expect(v.c.querySelectorAll('tbody td.el-rank')).toHaveLength(3))
    expect(Array.from(v.c.querySelectorAll('thead th')).map((th) => th.textContent?.trim())[0]).toBe('#')
    await fireEvent.click(v.editOf('ŻAK Adam'))
    await fireEvent.click(v.c.querySelector('button.ee-save') as HTMLButtonElement)
    await waitFor(() => expect(v.editDialog()).toBeNull())
    await waitFor(() => expect(mockRanks).toHaveBeenCalledTimes(2))
  })
})
