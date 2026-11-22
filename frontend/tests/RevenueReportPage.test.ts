// FR-176 — the event revenue forecast page (REVFC.17–20, 32). The organiser opens
// register.html?event=…&view=revenue&k=<key>; the page reads the event and the
// report, and offers the designed .ods. Every person and the key are invented.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent, waitFor, screen } from '@testing-library/svelte'

vi.mock('../src/lib/api', () => ({
  fetchEventForRegistration: vi.fn(),
  fetchRevenueReport: vi.fn(),
}))
vi.mock('../src/lib/revenueReportOds', async (importOriginal) => {
  const real = await importOriginal<typeof import('../src/lib/revenueReportOds')>()
  return { ...real, buildRevenueOds: vi.fn(real.buildRevenueOds) }
})

import { fetchEventForRegistration, fetchRevenueReport } from '../src/lib/api'
import { buildRevenueOds } from '../src/lib/revenueReportOds'
import { setLocale } from '../src/lib/locale.svelte'
import RevenueReport from '../src/components/RevenueReport.svelte'
import type { RevenueReportRaw } from '../src/lib/types'

const KEY = '11111111-2222-4333-8444-555555555555'
const mockEvent = vi.mocked(fetchEventForRegistration)
const mockReport = vi.mocked(fetchRevenueReport)
const mockOds = vi.mocked(buildRevenueOds)

function raw(over: Partial<RevenueReportRaw> = {}): RevenueReportRaw {
  return {
    ts_generated: '2026-11-22T13:05:00Z',
    currency: 'EUR',
    fees: { '1': 70, '2': 110, '3': 150, fallback_2: false, fallback_3: false },
    entries: [
      { id_registration: 1, txt_surname: 'NOWAK', txt_first_name: 'Anna', enum_gender: 'F', enum_age_category: 'V1', arr_weapons: ['EPEE'], num_fee: 70 },
      { id_registration: 2, txt_surname: 'KOWALSKI', txt_first_name: 'Jan', enum_gender: 'M', enum_age_category: 'V2', arr_weapons: ['EPEE', 'FOIL'], num_fee: 110 },
      { id_registration: 3, txt_surname: 'WIERZBA', txt_first_name: 'Ola', enum_gender: 'F', enum_age_category: 'V0', arr_weapons: ['EPEE', 'FOIL', 'SABRE'], num_fee: 150 },
      { id_registration: 4, txt_surname: 'ZIELIŃSKI', txt_first_name: 'Piotr', enum_gender: 'M', enum_age_category: 'V1', arr_weapons: ['SABRE'], num_fee: 70 },
    ],
    ...over,
  }
}

const EVENT = {
  id_event: 3,
  txt_code: 'PEW5',
  txt_name: 'PEW5 Łomianki',
  dt_start: '2026-12-12',
  dt_end: '2026-12-13',
  txt_location: 'Łomianki',
}

const testid = (id: string) => screen.getByTestId(id)
const cellsOf = (row: Element) => Array.from(row.querySelectorAll('th, td')).map((c) => c.textContent?.trim())

beforeEach(() => {
  vi.clearAllMocks()
  setLocale('pl')
  mockEvent.mockResolvedValue(EVENT as never)
  mockReport.mockResolvedValue(raw())
})

describe('REVFC.17 — the report', () => {
  it('shows the head, the three figures, both tables and the entries', async () => {
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    expect(await screen.findByText('Prognoza przychodu')).toBeTruthy()
    expect(mockReport).toHaveBeenCalledWith(3, KEY)
    expect(screen.getByText('PEW5 Łomianki')).toBeTruthy()
    expect(screen.getByText('12–13 grudnia 2026 · Łomianki')).toBeTruthy()
    expect(testid('rev-as-of').textContent).toBe('Stan na 22 listopada 2026, 14:05 · na podstawie zgłoszeń, nie wpłat')
    expect(testid('rev-fig-entries').textContent).toBe('4')
    expect(testid('rev-fig-starts').textContent).toBe('7')
    expect(testid('rev-fig-revenue').textContent).toBe('400,00 EUR')
    const tiers = testid('rev-tiers').querySelectorAll('tbody tr')
    expect(cellsOf(tiers[0])).toEqual(['1 broń', '2', '70,00 EUR', '140,00 EUR'])
    expect(cellsOf(tiers[2])).toEqual(['3 bronie', '1', '150,00 EUR', '150,00 EUR'])
    expect(cellsOf(testid('rev-tiers').querySelector('tfoot tr')!)).toEqual(['Razem', '4', '', '400,00 EUR'])
    const weapons = testid('rev-weapons').querySelectorAll('tbody tr')
    expect(cellsOf(weapons[0])).toEqual(['Szpada', '2', '120,00 EUR', '1', '55,00 EUR', '175,00 EUR'])
    expect(cellsOf(testid('rev-weapons').querySelector('tfoot tr')!)).toEqual(['Razem', '4', '220,00 EUR', '3', '180,00 EUR', '400,00 EUR'])
    const entries = testid('rev-entries').querySelectorAll('tbody.rr-rows tr')
    expect(entries).toHaveLength(4)
    expect(cellsOf(entries[0])).toEqual(['1', 'KOWALSKI Jan', 'M', 'V2', '✓', '✓', '', '2', '110,00 EUR'])
    expect(cellsOf(entries[1])[2]).toBe('K')
  })

  it('in English', async () => {
    setLocale('en')
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    expect(await screen.findByText('Revenue forecast')).toBeTruthy()
    // ICU writes an English range with thin spaces around the dash
    expect(screen.getByText(/^12\s–\s13 December 2026 · Łomianki$/)).toBeTruthy()
    expect(testid('rev-fig-revenue').textContent).toBe('400.00 EUR')
    expect(cellsOf(testid('rev-tiers').querySelectorAll('tbody tr')[1])).toEqual(['2 weapons', '1', '110.00 EUR', '110.00 EUR'])
    expect(cellsOf(testid('rev-entries').querySelectorAll('tbody.rr-rows tr')[1])[2]).toBe('F')
  })
})

describe('REVFC.18 — link not active, not found, no entries', () => {
  it('no key: „link not active”, no number, no report read', async () => {
    render(RevenueReport, { eventCode: 'PEW5', token: '' })
    expect(await screen.findByText('Ten link nie jest aktywny. Poproś administratora o nowy.')).toBeTruthy()
    expect(mockReport).not.toHaveBeenCalled()
    expect(screen.queryByTestId('rev-fig-entries')).toBeNull()
  })
  it('a NULL answer: „link not active”', async () => {
    mockReport.mockResolvedValue(null)
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    expect(await screen.findByText('Ten link nie jest aktywny. Poproś administratora o nowy.')).toBeTruthy()
    expect(screen.queryByTestId('rev-fig-entries')).toBeNull()
  })
  it('an unknown event: „not found”', async () => {
    mockEvent.mockResolvedValue(null)
    render(RevenueReport, { eventCode: 'NOPE', token: KEY })
    expect(await screen.findByText('Nie znaleziono wydarzenia.')).toBeTruthy()
    expect(mockReport).not.toHaveBeenCalled()
  })
  it('a live key and no entries: zeros and „Brak zgłoszeń.”', async () => {
    mockReport.mockResolvedValue(raw({ entries: [] }))
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    expect(await screen.findByText('Brak zgłoszeń.')).toBeTruthy()
    expect(testid('rev-fig-entries').textContent).toBe('0')
    expect(testid('rev-fig-revenue').textContent).toBe('0,00 EUR')
  })
})

describe('REVFC.19 — the notes', () => {
  it('the equal-share line always, and no missing-tier line when every tier is set', async () => {
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    expect(await screen.findByText('Opłata zgłoszenia w kilku broniach jest dzielona po równo między te bronie.')).toBeTruthy()
    expect(screen.queryByText(/Brak ceny/)).toBeNull()
  })
  it('the missing-tier line with its count only when used', async () => {
    mockReport.mockResolvedValue(raw({ fees: { '1': 70, '2': 140, '3': 150, fallback_2: true, fallback_3: false } }))
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    expect(await screen.findByText('Brak ceny za 2 bronie w ustawieniach wydarzenia: przyjęto 2 × opłata za 1 broń (zgłoszeń: 1).')).toBeTruthy()
    expect(screen.queryByText(/Brak ceny za 3/)).toBeNull()
  })
  it('no fee: the no-fee line instead of money', async () => {
    mockReport.mockResolvedValue(raw({
      fees: { '1': null, '2': null, '3': null, fallback_2: true, fallback_3: true },
      entries: raw().entries.map((e) => ({ ...e, num_fee: null })),
    }))
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    expect(await screen.findByText('Wydarzenie nie ma ustawionej opłaty: prognoza pokazuje tylko liczby.')).toBeTruthy()
    expect(testid('rev-fig-entries').textContent).toBe('4')
    expect(testid('rev-fig-revenue').textContent).toBe('—')
    expect(document.body.textContent).not.toMatch(/EUR\s*$|\d,\d\d EUR/)
  })
})

describe('REVFC.20 — the download', () => {
  it('re-reads the report and builds the file from that model, named by event, date and language', async () => {
    const created: Blob[] = []
    const names: string[] = []
    Object.assign(URL, {
      createObjectURL: vi.fn((b: Blob) => { created.push(b); return 'blob:x' }),
      revokeObjectURL: vi.fn(),
    })
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
      names.push(this.download)
    })
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    const button = await screen.findByRole('button', { name: 'Pobierz .ods' })
    const fresh = raw()
    fresh.entries.push({ id_registration: 5, txt_surname: 'BARAN', txt_first_name: 'Ewa', enum_gender: 'F', enum_age_category: 'V1', arr_weapons: ['FOIL'], num_fee: 70 })
    fresh.ts_generated = '2026-11-23T08:00:00Z'
    mockReport.mockResolvedValue(fresh)
    await fireEvent.click(button)
    await waitFor(() => expect(names).toHaveLength(1))
    expect(mockReport).toHaveBeenCalledTimes(2)
    expect(mockOds).toHaveBeenCalledTimes(1)
    const [model, head, lang] = mockOds.mock.calls[0]
    expect(model.totals.entries).toBe(5)
    expect(head).toMatchObject({ eventName: 'PEW5 Łomianki', eventCode: 'PEW5', dates: '12–13 grudnia 2026', place: 'Łomianki', asOf: '23 listopada 2026, 09:00' })
    expect(lang).toBe('pl')
    expect(names[0]).toBe('prognoza-przychodu-PEW5-2026-11-23.ods')
    expect(created[0].type).toBe('application/vnd.oasis.opendocument.spreadsheet')
    // the screen shows the minute of the file
    expect(testid('rev-fig-entries').textContent).toBe('5')
    click.mockRestore()
  })
})

// The page prints basically as the .ods does (change plan rev 2, signed
// 2026-11-22, Q1 = A): A4 with 15 mm margins, the summary alone on page 1, the
// entries from a new page with the file's column widths, total row and footer.
// What a browser really prints is proven by tools/print_check (Chrome to PDF).
describe('REVFC.32 — the page prints like the file', () => {
  const printStyle = () => document.head.querySelector('style[data-spws-revenue-print]')
  const widths = (id: string) => Array.from(testid(id).querySelectorAll('col')).map((c) => (c as HTMLElement).style.getPropertyValue('--mm'))

  it('the entries table ends with the file\'s total row', async () => {
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    await screen.findByText('Prognoza przychodu')
    const total = testid('rev-entries').querySelectorAll('tbody.rr-total tr')
    expect(total).toHaveLength(1)
    expect(cellsOf(total[0])).toEqual(['', 'Razem', '', '', '', '', '', '7', '400,00 EUR'])
    // not a tfoot: a browser repeats a tfoot on every printed page
    expect(testid('rev-entries').querySelector('tfoot')).toBeNull()
  })

  it('the entries start a new printed page; the tables carry the file\'s column widths', async () => {
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    await screen.findByText('Prognoza przychodu')
    expect(testid('rev-entries').closest('section')!.classList.contains('rr-new-page')).toBe(true)
    expect(testid('rev-tiers').closest('section')!.classList.contains('rr-new-page')).toBe(false)
    expect(widths('rev-tiers')).toEqual(['44', '24', '32', '24'])
    expect(widths('rev-weapons')).toEqual(['44', '24', '32', '24', '32', '24'])
    expect(widths('rev-entries')).toEqual(['10', '62', '12', '12', '16', '16', '16', '14', '22'])
  })

  it('installs the paper and the file\'s footer for the document while the report shows', async () => {
    const view = render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    await screen.findByText('Prognoza przychodu')
    const css = printStyle()?.textContent ?? ''
    expect(css).toContain('size: A4 portrait')
    expect(css).toContain('margin: 15mm')
    expect(css).toContain('@bottom-left { content: "PEW5 Łomianki"')
    expect(css).toContain('@bottom-center { content: "Prognoza przychodu · stan na 22 listopada 2026, 14:05"')
    expect(css).toContain('@bottom-right { content: "Strona " counter(page) " z " counter(pages)')
    view.unmount()
    expect(printStyle()).toBeNull()
  })

  it('the footer follows the language, and an event name cannot break out of its text', async () => {
    setLocale('en')
    mockEvent.mockResolvedValue({ ...EVENT, txt_name: 'A "B" \\C' } as never)
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    await screen.findByText('Revenue forecast')
    const css = printStyle()?.textContent ?? ''
    expect(css).toContain('@bottom-left { content: "A \\"B\\" \\\\C"')
    expect(css).toContain('@bottom-right { content: "Page " counter(page) " of " counter(pages)')
    expect(css).toMatch(/@bottom-center \{ content: "Revenue forecast · as of 22 November 2026, 14:05"/)
  })

  it('every money cell knows its column\'s width and its text\'s length, so print can shrink it to fit (I42)', async () => {
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    await screen.findByText('Prognoza przychodu')
    const fit = (el: Element) => [(el as HTMLElement).style.getPropertyValue('--mm'), (el as HTMLElement).style.getPropertyValue('--chars')]
    const total = testid('rev-entries').querySelector('tbody.rr-total tr')!.querySelectorAll('td')
    expect(fit(total[8])).toEqual(['22', '10']) // „400,00 EUR”
    const tierTotal = testid('rev-tiers').querySelector('tfoot tr')!.querySelectorAll('td')
    expect(fit(tierTotal[3])).toEqual(['24', '10'])
    const tierFee = testid('rev-tiers').querySelector('tbody tr')!.querySelectorAll('td')
    expect(fit(tierFee[2])).toEqual(['32', '9']) // „70,00 EUR”
    const weaponRow = testid('rev-weapons').querySelector('tbody tr')!.querySelectorAll('td')
    expect([fit(weaponRow[2]), fit(weaponRow[4]), fit(weaponRow[5])]).toEqual([['32', '10'], ['32', '9'], ['24', '10']])
    const entry = testid('rev-entries').querySelector('tbody.rr-rows tr')!.querySelectorAll('td')
    expect(fit(entry[8])).toEqual(['22', '10'])
    expect(testid('rev-entries').querySelectorAll('td.fit')).toHaveLength(5)
  })

  it('a link that is not active installs nothing', async () => {
    mockReport.mockResolvedValue(null)
    render(RevenueReport, { eventCode: 'PEW5', token: KEY })
    await screen.findByText('Ten link nie jest aktywny. Poproś administratora o nowy.')
    expect(printStyle()).toBeNull()
  })
})
