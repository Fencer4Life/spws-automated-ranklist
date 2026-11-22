// FR-176 — writes sample .ods files from INVENTED data for the LibreOffice proof
// (ods_check.sh). Bundled with esbuild and run with node; not part of the app.
//   node make_sample.cjs <outDir>
import { writeFileSync } from 'node:fs'
import { buildRevenueModel } from '../../../../frontend/src/lib/revenueReport'
import { buildRevenueOds } from '../../../../frontend/src/lib/revenueReportOds'
import type { RevenueReportRaw } from '../../../../frontend/src/lib/types'

const out = process.argv[2]
if (!out) throw new Error('usage: make_sample.cjs <outDir>')

const SURNAMES = ['ĆWIK', 'GOŁĄB', 'KOS', 'ŁABĘDŹ', 'NOWAK', 'KOWALSKI', 'WIERZBA', 'ŚWIERK', 'ZAJĄC', 'ŻUREK',
  'BARAN', 'DĄB', 'LIS', 'MAZUR', 'OLSZEWSKI', 'PAWLAK', 'RYBAK', 'SOWA', 'WILK', 'ZIELIŃSKI']
const GIVEN = ['Anna', 'Jan', 'Ola', 'Piotr', 'Ewa', 'Tomasz', 'Jerzy', 'Robert', 'Maria', 'Adam']
const WEAPONS = ['EPEE', 'FOIL', 'SABRE'] as const
const CATS = ['V0', 'V1', 'V2', 'V3', 'V4'] as const

function sample(n: number, fees: RevenueReportRaw['fees']): RevenueReportRaw {
  let seed = 7
  // the high bits: the low bit of this generator only alternates
  const rnd = (k: number) => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return (seed >> 16) % k }
  const entries: RevenueReportRaw['entries'] = []
  for (let i = 0; i < n; i++) {
    const count = 1 + rnd(3)
    const start = rnd(3)
    const weapons = Array.from({ length: count }, (_, k) => WEAPONS[(start + k) % 3])
    const w = weapons.length as 1 | 2 | 3
    const fee = fees[String(w) as '1' | '2' | '3']
    entries.push({
      id_registration: i + 1,
      txt_surname: `${SURNAMES[rnd(SURNAMES.length)]}${i % 7 === 0 ? '-' + SURNAMES[rnd(SURNAMES.length)] : ''}`,
      txt_first_name: GIVEN[rnd(GIVEN.length)],
      enum_gender: rnd(2) ? 'F' : 'M',
      enum_age_category: CATS[rnd(5)],
      arr_weapons: weapons.sort((a, b) => WEAPONS.indexOf(a) - WEAPONS.indexOf(b)),
      num_fee: fee,
    })
  }
  return { ts_generated: '2026-11-22T13:05:00Z', currency: 'EUR', fees, entries }
}

const head = { eventName: 'PEW5 Łomianki', eventCode: 'PEW5', dates: '12–13 grudnia 2026', place: 'Łomianki', asOf: '22 listopada 2026, 14:05' }
const headEn = { ...head, dates: '12–13 December 2026', asOf: '22 November 2026, 14:05' }
const full = { '1': 70, '2': 110, '3': 150, fallback_2: false, fallback_3: false }
const missing = { '1': 70, '2': 140, '3': 210, fallback_2: true, fallback_3: true }
// Łomianki's shape: 75 over two weapons is 37,5 a weapon, 100 over three is 33,33.
const shares = { '1': 50, '2': 75, '3': 100, fallback_2: false, fallback_3: false }

const cases: Record<string, { raw: RevenueReportRaw; lang: 'pl' | 'en' }> = {
  'full-pl': { raw: sample(12, full), lang: 'pl' },
  'full-en': { raw: sample(12, full), lang: 'en' },
  'missing-pl': { raw: sample(12, missing), lang: 'pl' },
  'big-pl': { raw: sample(105, full), lang: 'pl' },
  'big-en': { raw: sample(105, full), lang: 'en' },
  'empty-pl': { raw: sample(0, full), lang: 'pl' },
  'shares-pl': { raw: sample(12, shares), lang: 'pl' },
}
const expected: Record<string, unknown> = {}
const raws: Record<string, unknown> = {}
for (const [name, { raw, lang }] of Object.entries(cases)) {
  const model = buildRevenueModel(raw)
  writeFileSync(`${out}/${name}.ods`, buildRevenueOds(model, lang === 'en' ? headEn : head, lang))
  expected[name] = { lang, model }
  raws[name] = { lang, raw }
}
writeFileSync(`${out}/expected.json`, JSON.stringify(expected))
// The same answers, for print_check.cjs to print the page from Chrome.
writeFileSync(`${out}/raw.json`, JSON.stringify(raws))
