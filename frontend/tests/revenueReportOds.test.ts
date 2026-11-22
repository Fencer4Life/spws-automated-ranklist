// FR-176 — the revenue forecast as a designed, printable .ods (REVFC.21–25, 31).
// The file is a zip of XML parts; these tests unzip it and read the XML, so
// structure, values, formulas, styles and page setup are all checked as the
// spreadsheet program will see them. The formulas' RESULTS are proven separately
// by LibreOffice (doc/plans/event-revenue-forecast-sheet/tools/ods_check.sh).
// Every person is invented.

import { describe, it, expect } from 'vitest'
import { unzipSync, strFromU8 } from 'fflate'
import { buildRevenueOds, odsFileName, type OdsHead } from '../src/lib/revenueReportOds'
import { buildRevenueModel, type RevenueModel } from '../src/lib/revenueReport'
import type { RevenueReportRaw } from '../src/lib/types'

const MIME = 'application/vnd.oasis.opendocument.spreadsheet'

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

const HEAD: OdsHead = {
  eventName: 'PEW5 Łomianki',
  eventCode: 'PEW5',
  dates: '12–13 grudnia 2026',
  place: 'Łomianki',
  asOf: '22 listopada 2026, 14:05',
}

function build(model: RevenueModel = buildRevenueModel(raw()), head: OdsHead = HEAD, lang: 'pl' | 'en' = 'pl') {
  return buildRevenueOds(model, head, lang)
}

function parts(bytes: Uint8Array) {
  const z = unzipSync(bytes)
  return Object.fromEntries(Object.entries(z).map(([k, v]) => [k, strFromU8(v)]))
}

function xml(text: string): Document {
  const doc = new DOMParser().parseFromString(text, 'application/xml')
  expect(doc.getElementsByTagName('parsererror').length).toBe(0)
  return doc
}

const attr = (el: Element | null | undefined, name: string) => el?.getAttribute(name) ?? null

function sheets(doc: Document): Element[] {
  return Array.from(doc.getElementsByTagName('table:table'))
}

function rowsOf(table: Element): Element[] {
  return Array.from(table.getElementsByTagName('table:table-row'))
}

function cellsOf(row: Element): Element[] {
  return Array.from(row.children).filter((c) => c.tagName === 'table:table-cell' || c.tagName === 'table:covered-table-cell')
}

function colIndex(letters: string): number {
  return letters.split('').reduce((n, ch) => n * 26 + ch.charCodeAt(0) - 64, 0) - 1
}

function cellAt(table: Element, ref: string): Element {
  const m = /^([A-Z]+)(\d+)$/.exec(ref)!
  return cellsOf(rowsOf(table)[Number(m[2]) - 1])[colIndex(m[1])]
}

const textOf = (el: Element) => el.textContent ?? ''
const num = (el: Element) => Number(el.getAttribute('office:value'))
const formula = (el: Element) => el.getAttribute('table:formula')

function styleEl(doc: Document, name: string | null): Element {
  const found = Array.from(doc.getElementsByTagName('style:style')).find((s) => s.getAttribute('style:name') === name)
  expect(found, `style ${name}`).toBeTruthy()
  return found!
}

function props(doc: Document, styleName: string | null, tag: string): Element | null {
  return styleEl(doc, styleName).getElementsByTagName(tag)[0] ?? null
}

function mm(v: string | null): number {
  return Number((v ?? '').replace('mm', ''))
}

function columnWidthsMm(doc: Document, table: Element): number[] {
  return Array.from(table.getElementsByTagName('table:table-column')).map((c) =>
    mm(attr(props(doc, c.getAttribute('table:style-name'), 'style:table-column-properties'), 'style:column-width')))
}

function loadContent(model?: RevenueModel, head?: OdsHead, lang: 'pl' | 'en' = 'pl') {
  const p = parts(build(model, head, lang))
  return { p, content: xml(p['content.xml']), styles: xml(p['styles.xml']) }
}

describe('REVFC.21 — the file is a spreadsheet zip', () => {
  it('has mimetype first, stored, with the spreadsheet type', () => {
    const b = build()
    const dv = new DataView(b.buffer, b.byteOffset, b.byteLength)
    expect(dv.getUint32(0, true)).toBe(0x04034b50)
    expect(dv.getUint16(8, true)).toBe(0) // compression method: stored
    const nameLen = dv.getUint16(26, true)
    const extraLen = dv.getUint16(28, true)
    const name = strFromU8(b.subarray(30, 30 + nameLen))
    expect(name).toBe('mimetype')
    const body = strFromU8(b.subarray(30 + nameLen + extraLen, 30 + nameLen + extraLen + MIME.length))
    expect(body).toBe(MIME)
  })
  it('holds exactly the five parts', () => {
    expect(Object.keys(unzipSync(build())).sort()).toEqual(
      ['META-INF/manifest.xml', 'content.xml', 'meta.xml', 'mimetype', 'styles.xml'])
    expect(parts(build()).mimetype).toBe(MIME)
  })
  it('the manifest lists the document and its three parts', () => {
    const doc = xml(parts(build())['META-INF/manifest.xml'])
    const entries = Array.from(doc.getElementsByTagName('manifest:file-entry'))
    const byPath = Object.fromEntries(entries.map((e) => [e.getAttribute('manifest:full-path'), e.getAttribute('manifest:media-type')]))
    expect(byPath['/']).toBe(MIME)
    expect(attr(entries.find((e) => e.getAttribute('manifest:full-path') === '/'), 'manifest:version')).toBe('1.2')
    expect(byPath['content.xml']).toBe('text/xml')
    expect(byPath['styles.xml']).toBe('text/xml')
    expect(byPath['meta.xml']).toBe('text/xml')
  })
  it('meta.xml names the title, the generator and the creation date', () => {
    const meta = parts(build())['meta.xml']
    const doc = xml(meta)
    expect(doc.getElementsByTagName('dc:title')[0].textContent).toContain('PEW5 Łomianki')
    expect(doc.getElementsByTagName('meta:generator')[0].textContent).toBe('SPWS Ranklist')
    expect(doc.getElementsByTagName('meta:creation-date')[0].textContent).toBe('2026-11-22T13:05:00Z')
  })
  it('names the file by event, date and language', () => {
    expect(odsFileName('PEW5', '2026-11-22T13:05:00Z', 'pl')).toBe('prognoza-przychodu-PEW5-2026-11-22.ods')
    expect(odsFileName('PEW5', '2026-11-22T13:05:00Z', 'en')).toBe('revenue-forecast-PEW5-2026-11-22.ods')
  })
})

describe('REVFC.22 — three sheets whose values are the model\'s', () => {
  it('names the sheets by language, in order', () => {
    expect(sheets(loadContent().content).map((s) => attr(s, 'table:name'))).toEqual(['Prognoza', 'Zgłoszenia', 'Lista'])
    expect(sheets(loadContent(undefined, undefined, 'en').content).map((s) => attr(s, 'table:name')))
      .toEqual(['Forecast', 'Entries', 'Roster'])
  })
  it('the forecast head states the title, event, dates and the as-of line', () => {
    const [f] = sheets(loadContent().content)
    expect(textOf(cellAt(f, 'A1'))).toBe('Prognoza przychodu')
    expect(textOf(cellAt(f, 'A2'))).toBe('PEW5 Łomianki')
    expect(textOf(cellAt(f, 'A3'))).toBe('12–13 grudnia 2026 · Łomianki')
    expect(textOf(cellAt(f, 'A4'))).toBe('Stan na 22 listopada 2026, 14:05 · na podstawie zgłoszeń, nie wpłat')
    const [fe] = sheets(loadContent(undefined, undefined, 'en').content)
    expect(textOf(cellAt(fe, 'A1'))).toBe('Revenue forecast')
    expect(textOf(cellAt(fe, 'A4'))).toBe('As of 22 listopada 2026, 14:05 · based on entries, not payments')
  })
  it('the figures, tier table and weapon table hold the model\'s values', () => {
    const m = buildRevenueModel(raw())
    const [f] = sheets(loadContent(m).content)
    expect(textOf(cellAt(f, 'A6'))).toBe('Zgłoszonych')
    expect(textOf(cellAt(f, 'E6'))).toBe('Przychód (EUR)')
    expect(num(cellAt(f, 'A7'))).toBe(m.totals.entries)
    expect(num(cellAt(f, 'C7'))).toBe(m.totals.starts)
    expect(num(cellAt(f, 'E7'))).toBe(m.totals.revenue)
    expect(['A11', 'A12', 'A13'].map((r) => textOf(cellAt(f, r)))).toEqual(['1 broń', '2 bronie', '3 bronie'])
    expect(['B11', 'B12', 'B13'].map((r) => num(cellAt(f, r)))).toEqual(m.tiers.map((t) => t.entries))
    expect(['C11', 'C12', 'C13'].map((r) => num(cellAt(f, r)))).toEqual([70, 110, 150])
    expect(['D11', 'D12', 'D13', 'D14'].map((r) => num(cellAt(f, r)))).toEqual([140, 110, 150, 400])
    expect(num(cellAt(f, 'B14'))).toBe(4)
    expect(['Szpada', 'Floret', 'Szabla'].map((_, i) => textOf(cellAt(f, `A${18 + i}`)))).toEqual(['Szpada', 'Floret', 'Szabla'])
    m.byWeapon.forEach((w, i) => {
      expect(num(cellAt(f, `B${18 + i}`))).toBe(w.F.starts)
      expect(num(cellAt(f, `C${18 + i}`))).toBeCloseTo(w.F.revenue, 9)
      expect(num(cellAt(f, `D${18 + i}`))).toBe(w.M.starts)
      expect(num(cellAt(f, `E${18 + i}`))).toBeCloseTo(w.M.revenue, 9)
      expect(num(cellAt(f, `F${18 + i}`))).toBeCloseTo(w.total, 9)
    })
    expect(num(cellAt(f, 'F21'))).toBeCloseTo(400, 9)
    expect(num(cellAt(f, 'B21'))).toBe(m.totals.F.starts)
    expect(num(cellAt(f, 'D21'))).toBe(m.totals.M.starts)
  })
  it('the entries sheet has one row per entry, in order, then the total', () => {
    const m = buildRevenueModel(raw())
    const [, e] = sheets(loadContent(m).content)
    expect(['Lp.', 'Nazwisko i imię', 'Płeć', 'Kat.', 'Szpada', 'Floret', 'Szabla', 'Broni', 'Opłata'].map((_, i) => textOf(cellsOf(rowsOf(e)[0])[i])))
      .toEqual(['Lp.', 'Nazwisko i imię', 'Płeć', 'Kat.', 'Szpada', 'Floret', 'Szabla', 'Broni', 'Opłata'])
    expect(rowsOf(e)).toHaveLength(1 + 4 + 1)
    expect([2, 3, 4, 5].map((r) => textOf(cellAt(e, `B${r}`)))).toEqual(['KOWALSKI Jan', 'NOWAK Anna', 'WIERZBA Ola', 'ZIELIŃSKI Piotr'])
    expect([2, 3, 4, 5].map((r) => textOf(cellAt(e, `C${r}`)))).toEqual(['M', 'K', 'K', 'M'])
    expect([2, 3, 4, 5].map((r) => textOf(cellAt(e, `D${r}`)))).toEqual(['V2', 'V1', 'V0', 'V1'])
    // Jan fences épée and foil: 1, 1, empty; two weapons; 110
    expect([num(cellAt(e, 'E2')), num(cellAt(e, 'F2')), cellAt(e, 'G2').getAttribute('office:value')]).toEqual([1, 1, null])
    expect([num(cellAt(e, 'H2')), num(cellAt(e, 'I2'))]).toEqual([2, 110])
    expect([2, 3, 4, 5].map((r) => num(cellAt(e, `I${r}`)))).toEqual([110, 70, 150, 70])
    expect(textOf(cellAt(e, 'B6'))).toBe('Razem')
    expect([num(cellAt(e, 'H6')), num(cellAt(e, 'I6'))]).toEqual([7, 400])
  })
  it('English: gender is F/M and the headers are English', () => {
    const [, e] = sheets(loadContent(undefined, undefined, 'en').content)
    expect(textOf(cellAt(e, 'B1'))).toBe('Surname and name')
    expect(textOf(cellAt(e, 'C3'))).toBe('F')
    expect(textOf(cellAt(e, 'B6'))).toBe('Total')
  })
})

describe('REVFC.23 — the formulas stand in their cells', () => {
  const N = 5 // four entries: rows 2..5
  const H = `[$'Zgłoszenia'.$H$2:.$H$${N}]`
  const entriesRange = (col: string) => `[$'Zgłoszenia'.$${col}$2:.$${col}$${N}]`
  it('the forecast', () => {
    const [f] = sheets(loadContent().content)
    expect(formula(cellAt(f, 'A7'))).toBe('of:=[.B14]')
    expect(formula(cellAt(f, 'C7'))).toBe('of:=[.B21]+[.D21]')
    expect(formula(cellAt(f, 'E7'))).toBe('of:=[.D14]')
    expect(formula(cellAt(f, 'B11'))).toBe(`of:=COUNTIF(${H};1)`)
    expect(formula(cellAt(f, 'B12'))).toBe(`of:=COUNTIF(${H};2)`)
    expect(formula(cellAt(f, 'B13'))).toBe(`of:=COUNTIF(${H};3)`)
    expect(formula(cellAt(f, 'C11'))).toBeNull()
    expect(formula(cellAt(f, 'C12'))).toBeNull()
    expect(formula(cellAt(f, 'D11'))).toBe('of:=[.B11]*[.C11]')
    expect(formula(cellAt(f, 'B14'))).toBe('of:=SUM([.B11:.B13])')
    expect(formula(cellAt(f, 'D14'))).toBe('of:=SUM([.D11:.D13])')
  })
  it('weapon × gender: starts and equal shares, with the empty-sheet guard', () => {
    const [f] = sheets(loadContent().content)
    const guard = `(${H}+(${H}=0))`
    expect(formula(cellAt(f, 'B18'))).toBe(`of:=SUMPRODUCT((${entriesRange('C')}="K")*(${entriesRange('E')}=1))`)
    expect(formula(cellAt(f, 'C18'))).toBe(
      `of:=SUMPRODUCT((${entriesRange('C')}="K")*(${entriesRange('E')}=1)*${entriesRange('I')}/${guard})`)
    expect(formula(cellAt(f, 'D18'))).toBe(`of:=SUMPRODUCT((${entriesRange('C')}="M")*(${entriesRange('E')}=1))`)
    expect(formula(cellAt(f, 'E19'))).toBe(
      `of:=SUMPRODUCT((${entriesRange('C')}="M")*(${entriesRange('F')}=1)*${entriesRange('I')}/${guard})`)
    expect(formula(cellAt(f, 'B20'))).toBe(`of:=SUMPRODUCT((${entriesRange('C')}="K")*(${entriesRange('G')}=1))`)
    expect(formula(cellAt(f, 'F18'))).toBe('of:=[.C18]+[.E18]')
    for (const c of ['B', 'C', 'D', 'E', 'F']) expect(formula(cellAt(f, `${c}21`))).toBe(`of:=SUM([.${c}18:.${c}20])`)
  })
  it('the English sheet quotes its own names, and counts "F" women', () => {
    const [f] = sheets(loadContent(undefined, undefined, 'en').content)
    expect(formula(cellAt(f, 'B11'))).toBe(`of:=COUNTIF([$'Entries'.$H$2:.$H$${N}];1)`)
    expect(formula(cellAt(f, 'B18'))).toContain('="F")')
  })
  it('the entries sheet follows the forecast fees', () => {
    const [, e] = sheets(loadContent().content)
    expect(formula(cellAt(e, 'H2'))).toBe('of:=COUNT([.E2:.G2])')
    expect(formula(cellAt(e, 'I2'))).toBe("of:=CHOOSE([.H2];[$'Prognoza'.$C$11];[$'Prognoza'.$C$12];[$'Prognoza'.$C$13])")
    expect(formula(cellAt(e, 'I5'))).toBe("of:=CHOOSE([.H5];[$'Prognoza'.$C$11];[$'Prognoza'.$C$12];[$'Prognoza'.$C$13])")
    expect(formula(cellAt(e, 'H6'))).toBe('of:=SUM([.H2:.H5])')
    expect(formula(cellAt(e, 'I6'))).toBe('of:=SUM([.I2:.I5])')
  })
})

describe('REVFC.24 — design and print', () => {
  it('the columns add up to 180 mm on all three sheets', () => {
    const { content } = loadContent()
    const [f, e, r] = sheets(content)
    expect(columnWidthsMm(content, f)).toEqual([44, 24, 32, 24, 32, 24])
    expect(columnWidthsMm(content, e)).toEqual([10, 62, 12, 12, 16, 16, 16, 14, 22])
    expect(columnWidthsMm(content, r)).toEqual([14, 70, 18, 18, 18, 24, 18])
    for (const t of [f, e, r]) expect(columnWidthsMm(content, t).reduce((a, b) => a + b, 0)).toBe(180)
  })
  it('the header, the total and the figures carry their fills and borders', () => {
    const { content } = loadContent()
    const [f] = sheets(content)
    const head = cellAt(f, 'A10').getAttribute('table:style-name')
    expect(attr(props(content, head, 'style:table-cell-properties'), 'fo:background-color')).toBe('#12467E')
    expect(attr(props(content, head, 'style:text-properties'), 'fo:color')).toBe('#FFFFFF')
    expect(attr(props(content, head, 'style:text-properties'), 'fo:font-weight')).toBe('bold')
    const total = cellAt(f, 'B14').getAttribute('table:style-name')
    expect(attr(props(content, total, 'style:table-cell-properties'), 'fo:background-color')).toBe('#DCE2EC')
    expect(attr(props(content, total, 'style:table-cell-properties'), 'fo:border-top')).toBe('1pt solid #12467E')
    const figure = cellAt(f, 'A7').getAttribute('table:style-name')
    expect(attr(props(content, figure, 'style:table-cell-properties'), 'fo:background-color')).toBe('#DBE7F5')
    const title = cellAt(f, 'A1').getAttribute('table:style-name')
    expect(attr(props(content, title, 'style:text-properties'), 'fo:color')).toBe('#12467E')
    expect(attr(props(content, title, 'style:text-properties'), 'fo:font-size')).toBe('20pt')
    expect(attr(props(content, title, 'style:text-properties'), 'style:font-name')).toBe('Georgia')
  })
  it('money has two decimals, grouping and the currency code', () => {
    const { content } = loadContent()
    const [f] = sheets(content)
    const money = styleEl(content, cellAt(f, 'C11').getAttribute('table:style-name')).getAttribute('style:data-style-name')
    const ns = Array.from(content.getElementsByTagName('number:number-style')).find((n) => n.getAttribute('style:name') === money)!
    const n = ns.getElementsByTagName('number:number')[0]
    expect(n.getAttribute('number:min-decimal-places')).toBe('2')
    expect(n.getAttribute('number:grouping')).toBe('true')
    expect(ns.getElementsByTagName('number:text')[0].textContent).toBe(' EUR')
  })
  it('every money cell shrinks to fit its fixed column, so a large total never shows ### (I35)', () => {
    const { content } = loadContent()
    const [f, e, r] = sheets(content)
    for (const [sheet, ref] of [[f, 'E7'], [f, 'D14'], [f, 'F21'], [e, 'I2'], [e, 'I6'], [r, 'F3'], [r, 'F7']] as const) {
      expect(attr(props(content, cellAt(sheet, ref).getAttribute('table:style-name'), 'style:table-cell-properties'), 'style:shrink-to-fit')).toBe('true')
    }
  })
  it('the entries are striped on every second row', () => {
    const { content } = loadContent()
    const [, e] = sheets(content)
    const fill = (r: number) => attr(props(content, cellAt(e, `B${r}`).getAttribute('table:style-name'), 'style:table-cell-properties'), 'fo:background-color')
    expect([fill(2), fill(3), fill(4), fill(5)]).toEqual([null, '#F3F6FA', null, '#F3F6FA'])
  })
  it('A4 portrait, 15 mm margins, centred, the footer with page number and count', () => {
    const { styles, content } = loadContent()
    const layout = styles.getElementsByTagName('style:page-layout-properties')[0]
    expect(layout.getAttribute('fo:page-width')).toBe('210mm')
    expect(layout.getAttribute('fo:page-height')).toBe('297mm')
    expect(layout.getAttribute('style:print-orientation')).toBe('portrait')
    for (const side of ['top', 'bottom', 'left', 'right']) expect(layout.getAttribute(`fo:margin-${side}`)).toBe('15mm')
    expect(layout.getAttribute('style:table-centering')).toBe('horizontal')
    const master = styles.getElementsByTagName('style:master-page')[0]
    expect(master.getAttribute('style:name')).toBe('Report')
    expect(master.getElementsByTagName('style:header')[0].getAttribute('style:display')).toBe('false')
    const footer = master.getElementsByTagName('style:footer')[0]
    expect(footer.getElementsByTagName('text:page-number')).toHaveLength(1)
    expect(footer.getElementsByTagName('text:page-count')).toHaveLength(1)
    expect(footer.textContent).toContain('PEW5 Łomianki')
    expect(footer.textContent).toContain('Strona')
    for (const t of sheets(content)) {
      expect(attr(styleEl(content, t.getAttribute('table:style-name')), 'style:master-page-name')).toBe('Report')
    }
  })
  it('the header rows repeat on the entries and roster sheets', () => {
    const [, e, r] = sheets(loadContent().content)
    expect(e.getElementsByTagName('table:table-header-rows')).toHaveLength(1)
    expect(e.getElementsByTagName('table:table-header-rows')[0].getElementsByTagName('table:table-row')).toHaveLength(1)
    expect(r.getElementsByTagName('table:table-header-rows')[0].getElementsByTagName('table:table-row')).toHaveLength(2)
  })
})

describe('REVFC.25 — escaping, a missing tier, nothing at all', () => {
  it('escapes & < > and quotes in names', () => {
    const m = buildRevenueModel(raw({
      entries: [{ id_registration: 1, txt_surname: `O'BRIEN & <SONS> "Q"`, txt_first_name: 'Al', enum_gender: 'M', enum_age_category: 'V1', arr_weapons: ['EPEE'], num_fee: 70 }],
    }))
    const head = { ...HEAD, eventName: `A & B <C> "D" 'E'` }
    const p = parts(build(m, head))
    expect(p['content.xml']).toContain('&amp;')
    expect(p['content.xml']).not.toContain('<SONS>')
    const [f, e, r] = sheets(xml(p['content.xml']))
    expect(textOf(cellAt(f, 'A2'))).toBe(`A & B <C> "D" 'E'`)
    expect(textOf(cellAt(e, 'B2'))).toBe(`O'BRIEN & <SONS> "Q" Al`)
    expect(textOf(cellAt(r, 'B3'))).toBe(`O'BRIEN & <SONS> "Q" Al`)
    expect(textOf(cellAt(r, 'A1'))).toContain(`A & B <C> "D" 'E'`)
    expect(xml(p['styles.xml']).getElementsByTagName('style:footer')[0].textContent).toContain(`A & B <C> "D" 'E'`)
    expect(xml(p['meta.xml']).getElementsByTagName('dc:title')[0].textContent).toContain(`A & B <C> "D" 'E'`)
  })
  it('a missing tier writes its formula and its note, with the count', () => {
    const m = buildRevenueModel(raw({
      fees: { '1': 70, '2': 140, '3': 210, fallback_2: true, fallback_3: true },
      entries: raw().entries.map((e) => ({ ...e, num_fee: e.arr_weapons.length * 70 })),
    }))
    const [f] = sheets(loadContent(m).content)
    expect(formula(cellAt(f, 'C12'))).toBe('of:=2*[.C11]')
    expect(formula(cellAt(f, 'C13'))).toBe('of:=3*[.C11]')
    expect(num(cellAt(f, 'C12'))).toBe(140)
    expect(textOf(cellAt(f, 'A22'))).toBe('Opłata zgłoszenia w kilku broniach jest dzielona po równo między te bronie.')
    expect(textOf(cellAt(f, 'A23'))).toBe('Brak ceny za 2 bronie w ustawieniach wydarzenia: przyjęto 2 × opłata za 1 broń (zgłoszeń: 1).')
    expect(textOf(cellAt(f, 'A24'))).toBe('Brak ceny za 3 bronie w ustawieniach wydarzenia: przyjęto 3 × opłata za 1 broń (zgłoszeń: 1).')
  })
  it('English notes', () => {
    const m = buildRevenueModel(raw({ fees: { '1': 70, '2': 140, '3': 150, fallback_2: true, fallback_3: false } }))
    const [f] = sheets(loadContent(m, undefined, 'en').content)
    expect(textOf(cellAt(f, 'A22'))).toBe('The fee of an entry in several weapons is split equally between them.')
    expect(textOf(cellAt(f, 'A23'))).toBe('No price for 2 weapons in the event settings: taken as 2 × the 1-weapon fee (entries: 1).')
  })
  it('no fee at all: one line, empty fee cells, valid file', () => {
    const m = buildRevenueModel(raw({
      fees: { '1': null, '2': null, '3': null, fallback_2: true, fallback_3: true },
      entries: raw().entries.map((e) => ({ ...e, num_fee: null })),
    }))
    const [f] = sheets(loadContent(m).content)
    expect(cellAt(f, 'C11').getAttribute('office:value')).toBeNull()
    expect(num(cellAt(f, 'D14'))).toBe(0)
    expect(textOf(cellAt(f, 'A23'))).toBe('Wydarzenie nie ma ustawionej opłaty: prognoza pokazuje tylko liczby.')
    expect(rowsOf(f)).toHaveLength(23)
  })
  it('no entries still gives a valid file: header and total, zeros', () => {
    const m = buildRevenueModel(raw({ entries: [] }))
    const { content } = loadContent(m)
    const [f, e, r] = sheets(content)
    expect(rowsOf(e)).toHaveLength(1 + 1 + 1) // header, one empty row, total
    expect(formula(cellAt(f, 'B11'))).toBe(`of:=COUNTIF([$'Zgłoszenia'.$H$2:.$H$2];1)`)
    expect(num(cellAt(f, 'A7'))).toBe(0)
    expect(num(cellAt(f, 'E7'))).toBe(0)
    expect(textOf(cellAt(e, 'B3'))).toBe('Razem')
    expect(rowsOf(r).length).toBeGreaterThanOrEqual(4)
  })
})

describe('REVFC.31 — the roster sheet', () => {
  const m = () => buildRevenueModel(raw())
  const last = 3 + 4 - 1 // entries from row 3: rows 3..6
  it('has seven columns in order, with their headers', () => {
    const [, , r] = sheets(loadContent(m()).content)
    const head = rowsOf(r)[1]
    // „Wpłata potw.”, as the plan's A4 mock: „potwierdzona” does not fit 18 mm and broke mid-word (I34)
    expect(cellsOf(head).map(textOf)).toEqual(['✓', 'NAZWISKO Imię', '1 broń', '2 bronie', '3 bronie', 'Opłata', 'Wpłata potw.'])
    expect(attr(props(loadContent(m()).content, cellsOf(head)[6].getAttribute('table:style-name'), 'style:text-properties'), 'fo:font-size')).toBe('9pt')
    const [, , re] = sheets(loadContent(m(), undefined, 'en').content)
    expect(cellsOf(rowsOf(re)[1]).map(textOf)).toEqual(['✓', 'SURNAME Name', '1 weapon', '2 weapons', '3 weapons', 'Fee', 'Payment confirmed'])
  })
  it('the first head row names the list, the event, the dates and the as-of time', () => {
    const [, , r] = sheets(loadContent(m()).content)
    const a1 = cellAt(r, 'A1')
    expect(a1.getAttribute('table:number-columns-spanned')).toBe('7')
    expect(textOf(a1)).toBe('Lista zgłoszonych · PEW5 Łomianki · 12–13 grudnia 2026 · stan na 22 listopada 2026, 14:05')
  })
  it('one row per entry in the entries sheet\'s order, the tick in the weapon count\'s column', () => {
    const [, e, r] = sheets(loadContent(m()).content)
    const names = [3, 4, 5, 6].map((row) => textOf(cellAt(r, `B${row}`)))
    expect(names).toEqual([2, 3, 4, 5].map((row) => textOf(cellAt(e, `B${row}`))))
    // KOWALSKI 2 weapons, NOWAK 1, WIERZBA 3, ZIELIŃSKI 1
    const ticks = (row: number) => ['C', 'D', 'E'].map((c) => cellAt(r, `${c}${row}`).getAttribute('office:value'))
    expect(ticks(3)).toEqual([null, '1', null])
    expect(ticks(4)).toEqual(['1', null, null])
    expect(ticks(5)).toEqual([null, null, '1'])
    expect(ticks(6)).toEqual(['1', null, null])
  })
  it('the tick is shown by a number style that holds only that text', () => {
    const { content } = loadContent(m())
    const [, , r] = sheets(content)
    const data = styleEl(content, cellAt(r, 'D3').getAttribute('table:style-name')).getAttribute('style:data-style-name')
    const ns = Array.from(content.getElementsByTagName('number:number-style')).find((n) => n.getAttribute('style:name') === data)!
    expect(ns.textContent).toBe('✓')
    expect(ns.getElementsByTagName('number:number')).toHaveLength(0)
  })
  it('the fee refers to the entries sheet; A and G are empty boxes', () => {
    const [, , r] = sheets(loadContent(m()).content)
    expect(formula(cellAt(r, 'F3'))).toBe("of:=[$'Zgłoszenia'.I2]")
    expect(formula(cellAt(r, 'F6'))).toBe("of:=[$'Zgłoszenia'.I5]")
    expect(num(cellAt(r, 'F3'))).toBe(110)
    for (const row of [3, 4, 5, 6]) {
      for (const c of ['A', 'G']) {
        const cell = cellAt(r, `${c}${row}`)
        expect(cell.getAttribute('office:value-type')).toBeNull()
        expect(textOf(cell)).toBe('')
      }
    }
  })
  it('the total row and the confirmed-payments line carry their formulas', () => {
    const [, , r] = sheets(loadContent(m()).content)
    const t = last + 1
    expect(textOf(cellAt(r, `B${t}`))).toBe('Razem')
    expect(formula(cellAt(r, `C${t}`))).toBe(`of:=SUM([.C3:.C${last}])`)
    expect(formula(cellAt(r, `D${t}`))).toBe(`of:=SUM([.D3:.D${last}])`)
    expect(formula(cellAt(r, `E${t}`))).toBe(`of:=SUM([.E3:.E${last}])`)
    expect(formula(cellAt(r, `F${t}`))).toBe(`of:=SUM([.F3:.F${last}])`)
    expect([num(cellAt(r, `C${t}`)), num(cellAt(r, `D${t}`)), num(cellAt(r, `E${t}`)), num(cellAt(r, `F${t}`))]).toEqual([2, 1, 1, 400])
    const p = t + 1
    expect(textOf(cellAt(r, `A${p}`))).toBe('Wpłaty potwierdzone:')
    expect(formula(cellAt(r, `C${p}`))).toBe(`of:=COUNTA([.G3:.G${last}])`)
    expect(formula(cellAt(r, `F${p}`))).toBe(`of:=SUMIF([.G3:.G${last}];"<>";[.F3:.F${last}])`)
    expect([num(cellAt(r, `C${p}`)), num(cellAt(r, `F${p}`))]).toEqual([0, 0])
  })
  it('rows are 7 mm, the two head rows 9 and 10 mm and they repeat', () => {
    const { content } = loadContent(m())
    const [, , r] = sheets(content)
    const h = (row: Element) => mm(attr(props(content, row.getAttribute('table:style-name'), 'style:table-row-properties'), 'style:row-height'))
    const rows = rowsOf(r)
    expect([h(rows[0]), h(rows[1])]).toEqual([9, 10])
    expect([2, 3, 4, 5].map((i) => h(rows[i]))).toEqual([7, 7, 7, 7])
    expect(r.getElementsByTagName('table:table-header-rows')[0].getElementsByTagName('table:table-row')).toHaveLength(2)
  })
  it('the print range is A1:G of the last row, and the name cell shrinks to fit', () => {
    const { content } = loadContent(m())
    const [, , r] = sheets(content)
    const t = last + 2 // the confirmed line is the last row
    expect(r.getAttribute('table:print-ranges')).toBe(`'Lista'.A1:'Lista'.G${t}`)
    const name = props(content, cellAt(r, 'B3').getAttribute('table:style-name'), 'style:table-cell-properties')
    expect(name?.getAttribute('style:shrink-to-fit')).toBe('true')
    expect(name?.getAttribute('fo:wrap-option')).not.toBe('wrap')
  })
  it('every body cell is boxed with hairlines and the roster is not striped', () => {
    const { content } = loadContent(m())
    const [, , r] = sheets(content)
    for (const c of ['A', 'B', 'C', 'F', 'G']) {
      const p = props(content, cellAt(r, `${c}4`).getAttribute('table:style-name'), 'style:table-cell-properties')
      expect(p?.getAttribute('fo:border')).toBe('0.5pt solid #C9D1DC')
      expect(p?.getAttribute('fo:background-color')).toBeNull()
    }
  })
  it('with no entries the sheet keeps its head, one empty row and the total', () => {
    const [, , r] = sheets(loadContent(buildRevenueModel(raw({ entries: [] }))).content)
    expect(formula(cellAt(r, 'C4'))).toBe('of:=SUM([.C3:.C3])')
    expect(textOf(cellAt(r, 'B4'))).toBe('Razem')
  })
})
