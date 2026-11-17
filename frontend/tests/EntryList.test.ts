// Phase 2 (P2.7, FR-123) — EntryList.svelte: on-demand public roster fetch +
// nazwisko/broń/kategoria/płeć filters. No birth year or club (GDPR
// minimisation) — vw_registration_entry_list already excludes them.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'
import { setLocale } from '../src/lib/locale.svelte'

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
