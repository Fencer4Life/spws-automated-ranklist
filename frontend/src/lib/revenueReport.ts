// FR-176 — the numbers behind the event revenue forecast.
//
// One pure module, no Svelte and no network: the report page and the .ods file
// both read its result, so they cannot disagree. The input is what
// fn_event_revenue_report answered (declared fees, never payments); money is
// kept unrounded and rounded only when it is shown (R3: the fee of an entry in
// several weapons is split equally between them, so the cells add up exactly).

import type { AgeCategory, GenderType, RevenueReportRaw, WeaponType } from './types'
import { surnameWithoutTitle } from './registrationName'

export const WEAPONS: WeaponType[] = ['EPEE', 'FOIL', 'SABRE']

type Cell = { starts: number; revenue: number }

export interface RevenueModel {
  generatedAt: string
  currency: string
  /** An event with no one-weapon fee shows counts and no money. */
  hasFees: boolean
  /** Always three rows: one, two, three weapons. */
  tiers: { weapons: 1 | 2 | 3; entries: number; fee: number | null; total: number; fallback: boolean }[]
  /** Always three rows, in WEAPONS order. */
  byWeapon: { weapon: WeaponType; F: Cell; M: Cell; total: number }[]
  totals: { entries: number; starts: number; revenue: number; F: Cell; M: Cell }
  entries: { id: number; name: string; gender: GenderType; category: AgeCategory | null; weapons: WeaponType[]; fee: number | null }[]
  /** Entries priced by the missing-tier rule (R2). */
  fallbackEntries: { two: number; three: number }
}

const TIERS = [1, 2, 3] as const

// The entry list's own order: Polish letters, a title ignored (EntryList.svelte).
const byName = new Intl.Collator('pl', { sensitivity: 'base' })

export function buildRevenueModel(raw: RevenueReportRaw): RevenueModel {
  const hasFees = raw.fees['1'] != null
  const fallbackFlag: Record<number, boolean> = { 1: false, 2: raw.fees.fallback_2, 3: raw.fees.fallback_3 }

  const sorted = [...raw.entries].sort((a, b) =>
    byName.compare(surnameWithoutTitle(a.txt_surname), surnameWithoutTitle(b.txt_surname))
    || byName.compare(a.txt_first_name, b.txt_first_name))

  const tiers = TIERS.map((weapons) => {
    const entries = raw.entries.filter((e) => e.arr_weapons.length === weapons).length
    const fee = raw.fees[String(weapons) as '1' | '2' | '3']
    return {
      weapons,
      entries,
      fee,
      total: fee == null ? 0 : entries * fee,
      fallback: fallbackFlag[weapons] && fee != null,
    }
  })

  const byWeapon = WEAPONS.map((weapon) => ({
    weapon,
    F: { starts: 0, revenue: 0 } as Cell,
    M: { starts: 0, revenue: 0 } as Cell,
    total: 0,
  }))
  for (const e of raw.entries) {
    const share = (e.num_fee ?? 0) / e.arr_weapons.length
    for (const w of e.arr_weapons) {
      const row = byWeapon[WEAPONS.indexOf(w)]
      const cell = row[e.enum_gender]
      cell.starts += 1
      cell.revenue += share
      row.total += share
    }
  }

  const sumGender = (g: GenderType): Cell => ({
    starts: byWeapon.reduce((s, w) => s + w[g].starts, 0),
    revenue: byWeapon.reduce((s, w) => s + w[g].revenue, 0),
  })
  const totals = {
    entries: raw.entries.length,
    starts: raw.entries.reduce((s, e) => s + e.arr_weapons.length, 0),
    revenue: raw.entries.reduce((s, e) => s + (e.num_fee ?? 0), 0),
    F: sumGender('F'),
    M: sumGender('M'),
  }

  return {
    generatedAt: raw.ts_generated,
    currency: raw.currency,
    hasFees,
    tiers,
    byWeapon,
    totals,
    entries: sorted.map((e) => ({
      id: e.id_registration,
      name: `${e.txt_surname} ${e.txt_first_name}`,
      gender: e.enum_gender,
      category: e.enum_age_category,
      weapons: e.arr_weapons,
      fee: e.num_fee,
    })),
    fallbackEntries: {
      two: hasFees && raw.fees.fallback_2 ? tiers[1].entries : 0,
      three: hasFees && raw.fees.fallback_3 ? tiers[2].entries : 0,
    },
  }
}

/**
 * Fees are whole amounts, so money shows no decimals. The one value that can
 * be fractional is an equal share (75 over two weapons): it shows its fraction,
 * up to two places, so what is shown still adds up to the total shown.
 */
export function formatMoney(value: number, lang: 'pl' | 'en'): string {
  return new Intl.NumberFormat(lang === 'en' ? 'en-GB' : 'pl-PL', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(value)
}

/** The address an organiser opens: the registration page's revenue view. */
export function reportUrl(registerPage: string, eventCode: string, token: string): string {
  return `${registerPage}?event=${encodeURIComponent(eventCode)}&view=revenue&k=${token}`
}
