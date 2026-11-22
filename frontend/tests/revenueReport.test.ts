// FR-176 — the numbers behind the event revenue forecast (REVFC.13–16). One pure
// module feeds both the page and the spreadsheet, so they cannot disagree.
// Every person is invented. (The page's tests are RevenueReportPage.test.ts: a
// second file differing from this one only in case cannot exist on macOS, I37.)

import { describe, it, expect } from 'vitest'
import { buildRevenueModel, formatMoney, reportUrl, WEAPONS } from '../src/lib/revenueReport'
import type { RevenueReportRaw } from '../src/lib/types'

const KEY = '11111111-2222-4333-8444-555555555555'

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

describe('REVFC.13 — the tier table', () => {
  it('has three rows always, with entries, fee and total per tier', () => {
    const m = buildRevenueModel(raw())
    expect(m.tiers.map((t) => t.weapons)).toEqual([1, 2, 3])
    expect(m.tiers.map((t) => t.entries)).toEqual([2, 1, 1])
    expect(m.tiers.map((t) => t.fee)).toEqual([70, 110, 150])
    expect(m.tiers.map((t) => t.total)).toEqual([140, 110, 150])
  })
  it('totals: entries, starts and revenue', () => {
    const m = buildRevenueModel(raw())
    expect(m.totals.entries).toBe(4)
    expect(m.totals.starts).toBe(7)
    expect(m.totals.revenue).toBe(400)
  })
  it('keeps a tier with no entries as a row of zeros with its fee', () => {
    const m = buildRevenueModel(raw({ entries: [] }))
    expect(m.tiers).toHaveLength(3)
    expect(m.tiers.map((t) => [t.entries, t.fee, t.total])).toEqual([[0, 70, 0], [0, 110, 0], [0, 150, 0]])
    expect(m.totals).toMatchObject({ entries: 0, starts: 0, revenue: 0 })
  })
  it('reads the currency and the time of the report', () => {
    const m = buildRevenueModel(raw())
    expect(m.currency).toBe('EUR')
    expect(m.generatedAt).toBe('2026-11-22T13:05:00Z')
  })
})

describe('REVFC.14 — weapon × gender, in equal shares', () => {
  it('counts starts and shares the fee of a multi-weapon entry equally', () => {
    const m = buildRevenueModel(raw())
    expect(m.byWeapon.map((w) => w.weapon)).toEqual(WEAPONS)
    const epee = m.byWeapon[0]
    // épée: Anna F 70, Jan M 110/2, Ola F 150/3
    expect(epee.F).toEqual({ starts: 2, revenue: 70 + 50 })
    expect(epee.M).toEqual({ starts: 1, revenue: 55 })
    expect(epee.total).toBe(175)
    const sabre = m.byWeapon[2]
    expect(sabre.F).toEqual({ starts: 1, revenue: 50 })
    expect(sabre.M).toEqual({ starts: 1, revenue: 70 })
  })
  it('adds up exactly: a fee of 100 over three weapons, no rounding', () => {
    const m = buildRevenueModel(raw({
      fees: { '1': 100, '2': 100, '3': 100, fallback_2: false, fallback_3: false },
      entries: [{ id_registration: 1, txt_surname: 'A', txt_first_name: 'B', enum_gender: 'F', enum_age_category: 'V1', arr_weapons: ['EPEE', 'FOIL', 'SABRE'], num_fee: 100 }],
    }))
    const cells = m.byWeapon.map((w) => w.F.revenue)
    expect(cells.every((c) => c === 100 / 3)).toBe(true)
    expect(m.byWeapon.reduce((s, w) => s + w.total, 0)).toBeCloseTo(100, 12)
    expect(m.totals.F.revenue).toBeCloseTo(100, 12)
    expect(m.totals.revenue).toBe(100)
    expect(m.totals.F.starts).toBe(3)
    expect(m.totals.M).toEqual({ starts: 0, revenue: 0 })
  })
  it('the gender totals equal the sum of the weapon cells', () => {
    const m = buildRevenueModel(raw())
    expect(m.totals.F.starts).toBe(m.byWeapon.reduce((s, w) => s + w.F.starts, 0))
    expect(m.totals.M.revenue).toBeCloseTo(m.byWeapon.reduce((s, w) => s + w.M.revenue, 0), 12)
    expect(m.totals.F.revenue + m.totals.M.revenue).toBeCloseTo(m.totals.revenue, 12)
  })
})

describe('REVFC.15 — the entries are in the entry list\'s order', () => {
  it('sorts Polish letters as the list does and ignores a title', () => {
    const m = buildRevenueModel(raw({
      entries: [
        { id_registration: 1, txt_surname: 'ŁUKASIK', txt_first_name: 'Ewa', enum_gender: 'F', enum_age_category: 'V1', arr_weapons: ['EPEE'], num_fee: 70 },
        { id_registration: 2, txt_surname: 'Dr. BARAN', txt_first_name: 'Adam', enum_gender: 'M', enum_age_category: 'V1', arr_weapons: ['FOIL'], num_fee: 70 },
        { id_registration: 3, txt_surname: 'LEWANDOWSKI', txt_first_name: 'Zbigniew', enum_gender: 'M', enum_age_category: 'V1', arr_weapons: ['FOIL'], num_fee: 70 },
        { id_registration: 4, txt_surname: 'LEWANDOWSKI', txt_first_name: 'Adam', enum_gender: 'M', enum_age_category: 'V1', arr_weapons: ['FOIL'], num_fee: 70 },
        { id_registration: 5, txt_surname: 'ZAJĄC', txt_first_name: 'Ola', enum_gender: 'F', enum_age_category: 'V1', arr_weapons: ['FOIL'], num_fee: 70 },
      ],
    }))
    expect(m.entries.map((e) => e.name)).toEqual([
      'Dr. BARAN Adam', 'LEWANDOWSKI Adam', 'LEWANDOWSKI Zbigniew', 'ŁUKASIK Ewa', 'ZAJĄC Ola',
    ])
  })
  it('carries gender, category, weapons and fee per entry', () => {
    const m = buildRevenueModel(raw())
    const jan = m.entries.find((e) => e.id === 2)
    expect(jan).toEqual({ id: 2, name: 'KOWALSKI Jan', gender: 'M', category: 'V2', weapons: ['EPEE', 'FOIL'], fee: 110 })
  })
})

describe('REVFC.16 — missing tiers, no fee, money, link', () => {
  it('counts the entries priced by the missing-tier rule', () => {
    const m = buildRevenueModel(raw({
      fees: { '1': 70, '2': 140, '3': 210, fallback_2: true, fallback_3: true },
    }))
    expect(m.fallbackEntries).toEqual({ two: 1, three: 1 })
    expect(m.tiers.map((t) => t.fallback)).toEqual([false, true, true])
  })
  it('counts none when every tier is set', () => {
    expect(buildRevenueModel(raw()).fallbackEntries).toEqual({ two: 0, three: 0 })
  })
  it('an event without a fee gives counts and no money', () => {
    const m = buildRevenueModel(raw({
      fees: { '1': null, '2': null, '3': null, fallback_2: true, fallback_3: true },
      entries: raw().entries.map((e) => ({ ...e, num_fee: null })),
    }))
    expect(m.hasFees).toBe(false)
    expect(m.totals.entries).toBe(4)
    expect(m.totals.starts).toBe(7)
    expect(m.totals.revenue).toBe(0)
    expect(m.tiers.map((t) => t.total)).toEqual([0, 0, 0])
    expect(m.fallbackEntries).toEqual({ two: 0, three: 0 })
  })
  it('hasFees is true with a one-weapon fee', () => {
    expect(buildRevenueModel(raw()).hasFees).toBe(true)
  })
  it('formatMoney shows a whole amount without decimals, and a share that is not whole with its fraction', () => {
    // fees are whole amounts (change plan event-revenue-forecast-no-decimals, Q1 = A)
    expect(formatMoney(7950, 'en')).toBe('7,950')
    expect(formatMoney(70, 'en')).toBe('70')
    expect(formatMoney(0, 'en')).toBe('0')
    expect(formatMoney(70, 'pl')).toBe('70')
    expect(formatMoney(7950, 'pl')).toBe('7950')
    expect(formatMoney(11910, 'pl').replace(/\s/g, ' ')).toBe('11 910')
    // an equal share: 75 over two weapons, 100 over three
    expect(formatMoney(37.5, 'pl')).toBe('37,5')
    expect(formatMoney(100 / 3, 'pl')).toBe('33,33')
    expect(formatMoney(37.5, 'en')).toBe('37.5')
  })
  it('reportUrl names the event, the view and the key', () => {
    expect(reportUrl('https://x.test/register.html', 'PEW5', KEY))
      .toBe(`https://x.test/register.html?event=PEW5&view=revenue&k=${KEY}`)
    expect(reportUrl('https://x.test/register.html', 'A B/C', KEY))
      .toBe(`https://x.test/register.html?event=A%20B%2FC&view=revenue&k=${KEY}`)
  })
})
