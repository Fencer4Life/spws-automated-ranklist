// FR-176 — the revenue forecast as a designed, printable .ods.
//
// An .ods is a zip of XML parts. This file writes exactly five (mimetype first
// and stored, the manifest, meta, styles and content) with fflate; SheetJS was
// rejected because it writes values only, and the organiser must be able to
// change a fee and watch every total follow. So every total is a live formula
// that also carries its computed value (a viewer that does not recalculate
// shows the same numbers).
//
// Two sheets, one design (plan section 04, as changed 2026-11-22): the forecast
// on one A4 page and the entries on their own tab. Money is written unrounded.

import { zipSync, strToU8 as encode } from 'fflate'
import type { RevenueModel } from './revenueReport'
import { WEAPONS } from './revenueReport'
import pl from './locales/pl.json'
import en from './locales/en.json'

export interface OdsHead {
  eventName: string
  eventCode: string
  dates: string
  place: string
  /** Already formatted for the language, e.g. „22 listopada 2026, 14:05”. */
  asOf: string
}

type Lang = 'pl' | 'en'

const MIME = 'application/vnd.oasis.opendocument.spreadsheet'

// --- palette and type (the report page uses the same) -----------------------
const ACCENT = '#12467E'
const SOFT = '#DBE7F5'
const TOTAL_FILL = '#DCE2EC'
const STRIPE = '#F3F6FA'
const HAIR = '0.5pt solid #C9D1DC'
const RULE = '1pt solid #12467E'
const INK = '#0F1319'
const SECONDARY = '#414B59'
const NOTES = '#6B7482'

// --- words: the same rev_* keys the report page reads, so page and file agree.
type Dict = Record<string, string>
const DICTS: Record<Lang, Dict> = { pl: pl as Dict, en: en as Dict }

function words(lang: Lang) {
  const d = DICTS[lang]
  const w = (key: string, vars: Record<string, string | number> = {}) =>
    d[key].replace(/\{(\w+)\}/g, (_, v: string) => String(vars[v]))
  return {
    title: w('rev_title'),
    figures: [w('rev_fig_entries'), w('rev_fig_starts')] as const,
    revenue: (cur: string) => w('rev_fig_revenue', { cur }),
    asOf: (when: string) => w('rev_as_of', { when }),
    stanNa: (when: string) => w('rev_stan_na', { when }),
    byTiers: w('rev_by_tiers'),
    tierHead: [w('rev_th_entry'), w('rev_th_people'), w('rev_th_fee'), w('rev_total')],
    tierName: [w('rev_tier_1'), w('rev_tier_2'), w('rev_tier_3')],
    total: w('rev_total'),
    byWeapon: w('rev_by_weapon'),
    weaponHead: [w('rev_th_weapon'), w('rev_th_f_starts'), w('rev_th_f_revenue'), w('rev_th_m_starts'), w('rev_th_m_revenue'), w('rev_total')],
    weapons: WEAPONS.map((x) => w(`rev_w_${x}`)),
    noteShare: w('rev_note_share'),
    noteMissing: (n: number, count: number) => w('rev_note_missing', { n, count }),
    noteNoFee: w('rev_note_no_fee'),
    sheets: [w('rev_sheet_forecast'), w('rev_sheet_entries')] as const,
    entriesHead: [w('rev_th_no'), w('rev_th_name'), w('rev_th_gender'), w('rev_th_cat'),
      ...WEAPONS.map((x) => w(`rev_w_${x}`)), w('rev_th_weapons'), w('rev_th_fee')],
    gender: { F: w('rev_g_F'), M: w('rev_g_M') },
    page: w('rev_page'),
    of: w('rev_page_of'),
  }
}

// fflate tells a file from a folder by `instanceof Uint8Array`. Under jsdom the
// encoder's output belongs to another realm and fails that test, so the bytes
// are copied into this realm's Uint8Array (a no-op copy in a browser).
const strToU8 = (s: string): Uint8Array => new Uint8Array(encode(s))

// --- XML helpers ------------------------------------------------------------
function xml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}

const NS =
  'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" ' +
  'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" ' +
  'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" ' +
  'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" ' +
  'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" ' +
  'xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" ' +
  'xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" ' +
  'xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2"'

const FONT_FACES =
  '<office:font-face-decls>' +
  `<style:font-face style:name="Georgia" svg:font-family="Georgia, 'Liberation Serif', serif"/>` +
  `<style:font-face style:name="Arial" svg:font-family="Arial, 'Liberation Sans', sans-serif"/>` +
  '</office:font-face-decls>'

// --- the style registry ------------------------------------------------------
interface CellSpec {
  font?: 'Georgia' | 'Arial'
  size?: number
  bold?: boolean
  italic?: boolean
  color?: string
  fill?: string
  align?: 'start' | 'end' | 'center'
  valign?: 'middle'
  wrap?: boolean
  upper?: boolean
  num?: 'money' | 'int' | 'tick'
  border?: string
  top?: string
  bottom?: string
}

class Styles {
  private cells = new Map<string, string>()
  private rows = new Map<number, string>()
  private cols = new Map<number, string>()

  cell(spec: CellSpec): string {
    const key = JSON.stringify(spec)
    let name = this.cells.get(key)
    if (!name) {
      name = `ce${this.cells.size + 1}`
      this.cells.set(key, name)
    }
    return name
  }

  row(mm: number): string {
    let name = this.rows.get(mm)
    if (!name) {
      name = `ro${this.rows.size + 1}`
      this.rows.set(mm, name)
    }
    return name
  }

  col(mm: number): string {
    let name = this.cols.get(mm)
    if (!name) {
      name = `co${this.cols.size + 1}`
      this.cols.set(mm, name)
    }
    return name
  }

  toXml(): string {
    let out = ''
    for (const [mm, name] of this.cols) {
      out += `<style:style style:name="${name}" style:family="table-column"><style:table-column-properties style:column-width="${mm}mm" fo:break-before="auto"/></style:style>`
    }
    for (const [mm, name] of this.rows) {
      out += `<style:style style:name="${name}" style:family="table-row"><style:table-row-properties style:row-height="${mm}mm" style:use-optimal-row-height="false"/></style:style>`
    }
    for (const [key, name] of this.cells) {
      const s = JSON.parse(key) as CellSpec
      const data = s.num ? ` style:data-style-name="N-${s.num}"` : ''
      let cellProps = ''
      if (s.fill) cellProps += ` fo:background-color="${s.fill}"`
      if (s.border) cellProps += ` fo:border="${s.border}"`
      if (s.top) cellProps += ` fo:border-top="${s.top}"`
      if (s.bottom) cellProps += ` fo:border-bottom="${s.bottom}"`
      cellProps += ` style:vertical-align="${s.valign ?? 'middle'}"`
      if (s.wrap) cellProps += ' fo:wrap-option="wrap"'
      else cellProps += ' fo:wrap-option="no-wrap"'
      // Money always shrinks to fit: the column widths are fixed to fill A4 (I35).
      if (s.num === 'money') cellProps += ' style:shrink-to-fit="true"'
      let textProps = ` style:font-name="${s.font ?? 'Arial'}" fo:font-size="${s.size ?? 10}pt" fo:color="${s.color ?? INK}"`
      if (s.bold) textProps += ' fo:font-weight="bold"'
      if (s.italic) textProps += ' fo:font-style="italic"'
      if (s.upper) textProps += ' fo:text-transform="uppercase"'
      const para = s.align ? `<style:paragraph-properties fo:text-align="${s.align}"/>` : ''
      out +=
        `<style:style style:name="${name}" style:family="table-cell"${data}>` +
        `<style:table-cell-properties${cellProps}/>${para}<style:text-properties${textProps}/></style:style>`
    }
    return out
  }
}

interface Cell {
  text?: string
  num?: number
  formula?: string
  style: string
  span?: number
}

function cell(c: Cell): string {
  const span = c.span && c.span > 1 ? ` table:number-columns-spanned="${c.span}" table:number-rows-spanned="1"` : ''
  let attrs = ` table:style-name="${c.style}"${span}`
  if (c.formula) attrs += ` table:formula="${xml(c.formula)}"`
  let body = ''
  if (c.num !== undefined) {
    attrs += ` office:value-type="float" office:value="${c.num}"`
  } else if (c.text !== undefined && c.text !== '') {
    attrs += ' office:value-type="string"'
    body = `<text:p>${xml(c.text)}</text:p>`
  }
  const covered = c.span && c.span > 1
    ? `<table:covered-table-cell table:style-name="${c.style}"/>`.repeat(c.span - 1)
    : ''
  return (body ? `<table:table-cell${attrs}>${body}</table:table-cell>` : `<table:table-cell${attrs}/>`) + covered
}

function row(styles: Styles, mm: number, cells: string[]): string {
  return `<table:table-row table:style-name="${styles.row(mm)}">${cells.join('')}</table:table-row>`
}

function columns(styles: Styles, widths: number[]): string {
  return widths.map((w) => `<table:table-column table:style-name="${styles.col(w)}"/>`).join('')
}

// --- the sheets --------------------------------------------------------------
interface Ctx {
  model: RevenueModel
  head: OdsHead
  lang: Lang
  t: ReturnType<typeof words>
  styles: Styles
  names: readonly [string, string]
  /** The last entry row on the entries sheet (at least 2). */
  n: number
}

const q = (name: string) => `$'${name}'`

function forecastSheet(x: Ctx): string {
  const { model: m, t, styles: S } = x
  const entries = x.names[1]
  const H = `[${q(entries)}.$H$2:.$H$${x.n}]`
  const rng = (col: string) => `[${q(entries)}.$${col}$2:.$${col}$${x.n}]`
  const guard = `(${H}+(${H}=0))`
  const out: string[] = []

  const label: CellSpec = { color: SECONDARY, size: 8, bold: true, upper: true, fill: SOFT, align: 'center', top: HAIR }
  const body: CellSpec = { bottom: HAIR }
  const bodyNum = (num: 'money' | 'int'): CellSpec => ({ ...body, align: 'end', num })
  const head: CellSpec = { fill: ACCENT, color: '#FFFFFF', bold: true, wrap: true }
  const headR: CellSpec = { ...head, align: 'end' }
  const total: CellSpec = { fill: TOTAL_FILL, bold: true, top: RULE }
  const totalNum = (num: 'money' | 'int'): CellSpec => ({ ...total, align: 'end', num })
  const section: CellSpec = { size: 11, bold: true, color: ACCENT, bottom: RULE }
  const note: CellSpec = { size: 8, color: NOTES, wrap: true, valign: 'middle' }

  // 1–5 the head
  out.push(row(S, 11, [cell({ text: t.title, style: S.cell({ font: 'Georgia', size: 20, bold: true, color: ACCENT }), span: 6 })]))
  out.push(row(S, 7, [cell({ text: x.head.eventName, style: S.cell({ size: 13, bold: true }), span: 6 })]))
  out.push(row(S, 5.5, [cell({ text: [x.head.dates, x.head.place].filter(Boolean).join(' · '), style: S.cell({ color: SECONDARY }), span: 6 })]))
  out.push(row(S, 6, [cell({ text: t.asOf(x.head.asOf), style: S.cell({ size: 9, italic: true, color: NOTES, bottom: HAIR }), span: 6 })]))
  out.push(row(S, 4, []))

  // 6–7 the three figures
  const lab = S.cell(label)
  out.push(row(S, 5.5, [
    cell({ text: t.figures[0], style: lab, span: 2 }),
    cell({ text: t.figures[1], style: lab, span: 2 }),
    cell({ text: t.revenue(m.currency), style: lab, span: 2 }),
  ]))
  const fig = (num: 'int' | 'money'): CellSpec => ({ size: 16, bold: true, fill: SOFT, align: 'center', bottom: HAIR, num })
  const tierRevenue = m.tiers.reduce((s, tier) => s + tier.total, 0)
  out.push(row(S, 10, [
    cell({ formula: 'of:=[.B14]', num: m.totals.entries, style: S.cell(fig('int')), span: 2 }),
    cell({ formula: 'of:=[.B21]+[.D21]', num: m.totals.starts, style: S.cell(fig('int')), span: 2 }),
    cell({ formula: 'of:=[.D14]', num: tierRevenue, style: S.cell(fig('money')), span: 2 }),
  ]))
  out.push(row(S, 6, []))

  // 9–14 by number of weapons
  out.push(row(S, 7, [cell({ text: t.byTiers, style: S.cell(section), span: 6 })]))
  out.push(row(S, 6.5, [
    cell({ text: t.tierHead[0], style: S.cell(head) }),
    cell({ text: t.tierHead[1], style: S.cell(headR) }),
    cell({ text: t.tierHead[2], style: S.cell(headR) }),
    cell({ text: t.tierHead[3], style: S.cell(headR) }),
  ]))
  m.tiers.forEach((tier, i) => {
    const r = 11 + i
    const feeCell: Cell =
      i > 0 && tier.fallback
        ? { formula: `of:=${i + 1}*[.C11]`, num: tier.fee ?? 0, style: S.cell(bodyNum('money')) }
        : tier.fee == null
          ? { style: S.cell(bodyNum('money')) }
          : { num: tier.fee, style: S.cell(bodyNum('money')) }
    out.push(row(S, 6, [
      cell({ text: t.tierName[i], style: S.cell(body) }),
      cell({ formula: `of:=COUNTIF(${H};${i + 1})`, num: tier.entries, style: S.cell(bodyNum('int')) }),
      cell(feeCell),
      cell({ formula: `of:=[.B${r}]*[.C${r}]`, num: tier.total, style: S.cell(bodyNum('money')) }),
    ]))
  })
  out.push(row(S, 6.5, [
    cell({ text: t.total, style: S.cell(total) }),
    cell({ formula: 'of:=SUM([.B11:.B13])', num: m.totals.entries, style: S.cell(totalNum('int')) }),
    cell({ style: S.cell(total) }),
    cell({ formula: 'of:=SUM([.D11:.D13])', num: tierRevenue, style: S.cell(totalNum('money')) }),
  ]))
  out.push(row(S, 6, []))

  // 16–21 by weapon and gender
  out.push(row(S, 7, [cell({ text: t.byWeapon, style: S.cell(section), span: 6 })]))
  out.push(row(S, 9, t.weaponHead.map((h, i) => cell({ text: h, style: S.cell(i === 0 ? head : headR) }))))
  const starts = (g: string, col: string) =>
    `of:=SUMPRODUCT((${rng('C')}="${g}")*(${rng(col)}=1))`
  const revenue = (g: string, col: string) =>
    `of:=SUMPRODUCT((${rng('C')}="${g}")*(${rng(col)}=1)*${rng('I')}/${guard})`
  const women = t.gender.F
  const men = t.gender.M
  m.byWeapon.forEach((w, i) => {
    const col = 'EFG'[i]
    const r = 18 + i
    out.push(row(S, 6, [
      cell({ text: t.weapons[i], style: S.cell(body) }),
      cell({ formula: starts(women, col), num: w.F.starts, style: S.cell(bodyNum('int')) }),
      cell({ formula: revenue(women, col), num: w.F.revenue, style: S.cell(bodyNum('money')) }),
      cell({ formula: starts(men, col), num: w.M.starts, style: S.cell(bodyNum('int')) }),
      cell({ formula: revenue(men, col), num: w.M.revenue, style: S.cell(bodyNum('money')) }),
      cell({ formula: `of:=[.C${r}]+[.E${r}]`, num: w.total, style: S.cell(bodyNum('money')) }),
    ]))
  })
  const tot = m.totals
  out.push(row(S, 6.5, [
    cell({ text: t.total, style: S.cell(total) }),
    cell({ formula: 'of:=SUM([.B18:.B20])', num: tot.F.starts, style: S.cell(totalNum('int')) }),
    cell({ formula: 'of:=SUM([.C18:.C20])', num: tot.F.revenue, style: S.cell(totalNum('money')) }),
    cell({ formula: 'of:=SUM([.D18:.D20])', num: tot.M.starts, style: S.cell(totalNum('int')) }),
    cell({ formula: 'of:=SUM([.E18:.E20])', num: tot.M.revenue, style: S.cell(totalNum('money')) }),
    cell({ formula: 'of:=SUM([.F18:.F20])', num: tot.F.revenue + tot.M.revenue, style: S.cell(totalNum('money')) }),
  ]))

  // 22– the notes
  const noteRow = (text: string) => row(S, 6, [cell({ text, style: S.cell(note), span: 6 })])
  out.push(noteRow(t.noteShare))
  if (!m.hasFees) {
    out.push(noteRow(t.noteNoFee))
  } else {
    if (m.fallbackEntries.two > 0) out.push(noteRow(t.noteMissing(2, m.fallbackEntries.two)))
    if (m.fallbackEntries.three > 0) out.push(noteRow(t.noteMissing(3, m.fallbackEntries.three)))
  }

  return (
    `<table:table table:name="${xml(x.names[0])}" table:style-name="ta1">` +
    columns(S, [44, 24, 32, 24, 32, 24]) +
    out.join('') +
    '</table:table>'
  )
}

function entriesSheet(x: Ctx): string {
  const { model: m, t, styles: S } = x
  const forecast = x.names[0]
  const head: CellSpec = { fill: ACCENT, color: '#FFFFFF', bold: true, wrap: true, align: 'center' }
  const headL: CellSpec = { ...head, align: 'start' }
  const headR: CellSpec = { ...head, align: 'end' }
  const heads = [head, headL, head, head, head, head, head, head, headR]
  const out: string[] = []

  const header = row(S, 7, t.entriesHead.map((h, i) => cell({ text: h, style: S.cell(heads[i]) })))
  const chooser = (r: number) =>
    `of:=CHOOSE([.H${r}];[${q(forecast)}.$C$11];[${q(forecast)}.$C$12];[${q(forecast)}.$C$13])`

  const list = m.entries.length ? m.entries : null
  const bodyRows = list ?? [null]
  bodyRows.forEach((e, i) => {
    const r = i + 2
    const stripe = i % 2 === 1 ? STRIPE : undefined
    const base: CellSpec = { bottom: HAIR, ...(stripe ? { fill: stripe } : {}) }
    const centre: CellSpec = { ...base, align: 'center' }
    const tick = (w: (typeof WEAPONS)[number]) =>
      e && e.weapons.includes(w)
        ? cell({ num: 1, style: S.cell({ ...centre, num: 'tick' }) })
        : cell({ style: S.cell(centre) })
    out.push(row(S, 6, [
      cell(e ? { num: i + 1, style: S.cell({ ...centre, num: 'int' }) } : { style: S.cell(centre) }),
      cell(e ? { text: e.name, style: S.cell(base) } : { style: S.cell(base) }),
      cell(e ? { text: t.gender[e.gender], style: S.cell(centre) } : { style: S.cell(centre) }),
      cell(e && e.category ? { text: e.category, style: S.cell(centre) } : { style: S.cell(centre) }),
      tick('EPEE'),
      tick('FOIL'),
      tick('SABRE'),
      e
        ? cell({ formula: `of:=COUNT([.E${r}:.G${r}])`, num: e.weapons.length, style: S.cell({ ...centre, num: 'int' }) })
        : cell({ style: S.cell(centre) }),
      e
        ? cell({ formula: chooser(r), num: e.fee ?? 0, style: S.cell({ ...base, align: 'end', num: 'money' }) })
        : cell({ style: S.cell({ ...base, align: 'end', num: 'money' }) }),
    ]))
  })

  const total: CellSpec = { fill: TOTAL_FILL, bold: true, top: RULE }
  const totalN = (num: 'int' | 'money', align: 'center' | 'end'): CellSpec => ({ ...total, align, num })
  const sumStarts = m.entries.reduce((s, e) => s + e.weapons.length, 0)
  const sumFees = m.entries.reduce((s, e) => s + (e.fee ?? 0), 0)
  const blank = cell({ style: S.cell(total) })
  out.push(row(S, 6.5, [
    blank,
    cell({ text: t.total, style: S.cell(total) }),
    blank, blank, blank, blank, blank,
    cell({ formula: `of:=SUM([.H2:.H${x.n}])`, num: sumStarts, style: S.cell(totalN('int', 'center')) }),
    cell({ formula: `of:=SUM([.I2:.I${x.n}])`, num: sumFees, style: S.cell(totalN('money', 'end')) }),
  ]))

  return (
    // The print range is the table itself, so a note typed far to the right
    // does not add pages.
    `<table:table table:name="${xml(x.names[1])}" table:style-name="ta1" table:print-ranges="'${xml(x.names[1])}'.A1:'${xml(x.names[1])}'.I${x.n + 1}">` +
    columns(S, [10, 62, 12, 12, 16, 16, 16, 14, 22]) +
    `<table:table-header-rows>${header}</table:table-header-rows>` +
    out.join('') +
    '</table:table>'
  )
}

// --- the parts ----------------------------------------------------------------
function contentXml(x: Ctx): string {
  const sheets = forecastSheet(x) + entriesSheet(x)
  const money = ` ${xml(x.model.currency)}`
  const numberStyles =
    `<number:number-style style:name="N-money"><number:number number:decimal-places="2" number:min-decimal-places="2" number:min-integer-digits="1" number:grouping="true"/><number:text>${money}</number:text></number:number-style>` +
    '<number:number-style style:name="N-int"><number:number number:decimal-places="0" number:min-integer-digits="1"/></number:number-style>' +
    '<number:number-style style:name="N-tick"><number:text>✓</number:text></number:number-style>'
  return (
    '<?xml version="1.0" encoding="UTF-8"?>' +
    `<office:document-content ${NS} office:version="1.2">` +
    FONT_FACES +
    '<office:automatic-styles>' +
    numberStyles +
    x.styles.toXml() +
    '<style:style style:name="ta1" style:family="table" style:master-page-name="Report"><style:table-properties table:display="true" style:writing-mode="lr-tb"/></style:style>' +
    '</office:automatic-styles>' +
    `<office:body><office:spreadsheet>${sheets}</office:spreadsheet></office:body>` +
    '</office:document-content>'
  )
}

function stylesXml(x: Ctx): string {
  const { t, head } = x
  const span = (s: string) => `<text:span text:style-name="Tft">${s}</text:span>`
  return (
    '<?xml version="1.0" encoding="UTF-8"?>' +
    `<office:document-styles ${NS} office:version="1.2">` +
    FONT_FACES +
    '<office:styles><style:default-style style:family="table-cell"><style:text-properties style:font-name="Arial" fo:font-size="10pt"/></style:default-style></office:styles>' +
    '<office:automatic-styles>' +
    `<style:style style:name="Tft" style:family="text"><style:text-properties style:font-name="Arial" fo:font-size="8pt" fo:color="${NOTES}"/></style:style>` +
    '<style:page-layout style:name="Mpm1">' +
    '<style:page-layout-properties fo:page-width="210mm" fo:page-height="297mm" style:print-orientation="portrait" fo:margin-top="15mm" fo:margin-bottom="15mm" fo:margin-left="15mm" fo:margin-right="15mm" style:table-centering="horizontal" style:writing-mode="lr-tb"/>' +
    '<style:header-style/>' +
    '<style:footer-style><style:header-footer-properties fo:min-height="5mm" fo:margin-top="2mm"/></style:footer-style>' +
    '</style:page-layout>' +
    '</office:automatic-styles>' +
    '<office:master-styles>' +
    '<style:master-page style:name="Report" style:page-layout-name="Mpm1">' +
    '<style:header style:display="false"/>' +
    '<style:footer>' +
    `<style:region-left><text:p>${span(xml(head.eventName))}</text:p></style:region-left>` +
    `<style:region-center><text:p>${span(xml(`${t.title} · ${t.stanNa(head.asOf)}`))}</text:p></style:region-center>` +
    `<style:region-right><text:p>${span(`${xml(t.page)} <text:page-number>1</text:page-number> ${xml(t.of)} <text:page-count>1</text:page-count>`)}</text:p></style:region-right>` +
    '</style:footer>' +
    '</style:master-page>' +
    '</office:master-styles>' +
    '</office:document-styles>'
  )
}

function metaXml(x: Ctx): string {
  return (
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" office:version="1.2">' +
    '<office:meta>' +
    `<dc:title>${xml(`${x.t.title} · ${x.head.eventName}`)}</dc:title>` +
    '<meta:generator>SPWS Ranklist</meta:generator>' +
    `<meta:creation-date>${xml(x.model.generatedAt)}</meta:creation-date>` +
    '</office:meta></office:document-meta>'
  )
}

const MANIFEST =
  '<?xml version="1.0" encoding="UTF-8"?>' +
  '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">' +
  `<manifest:file-entry manifest:full-path="/" manifest:version="1.2" manifest:media-type="${MIME}"/>` +
  '<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>' +
  '<manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>' +
  '<manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/>' +
  '</manifest:manifest>'

export function buildRevenueOds(model: RevenueModel, head: OdsHead, lang: Lang): Uint8Array {
  const t = words(lang)
  const ctx: Ctx = {
    model,
    head,
    lang,
    t,
    styles: new Styles(),
    names: t.sheets,
    n: Math.max(2, 1 + model.entries.length),
  }
  const content = contentXml(ctx)
  // zipSync keeps insertion order; the first entry must be stored uncompressed
  // for programs to recognise the file by its mimetype.
  return zipSync({
    mimetype: [strToU8(MIME), { level: 0 }],
    'META-INF/manifest.xml': strToU8(MANIFEST),
    'meta.xml': strToU8(metaXml(ctx)),
    'styles.xml': strToU8(stylesXml(ctx)),
    'content.xml': strToU8(content),
  })
}

/** 'prognoza-przychodu-<CODE>-<yyyy-mm-dd>.ods' / 'revenue-forecast-…' — the date as Warsaw sees it. */
export function odsFileName(eventCode: string, generatedAt: string, lang: Lang): string {
  const day = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Warsaw' }).format(new Date(generatedAt))
  return `${lang === 'en' ? 'revenue-forecast' : 'prognoza-przychodu'}-${eventCode}-${day}.ods`
}
