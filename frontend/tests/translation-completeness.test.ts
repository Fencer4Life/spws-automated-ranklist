// Translation completeness — FR-154, TR.01–TR.06.
// Plan: doc/plans/kalendarz-beben-strzalki-plan-2026-10-06.html §05.
//
// locale-parity.test.ts only proves the two files hold the same keys with no
// empty values. Text still reaches the screen untranslated three ways, and
// each test here closes one of them:
//   - t() prints the raw key when the key is missing (locale.svelte.ts) —
//     TR.01 for literal keys, TR.02 for keys built at runtime;
//   - a value pasted identically into both files — TR.03;
//   - text that never passes through t() at all, such as the drum's month
//     labels, which came from a hard-coded English list — TR.04–TR.06 render
//     the calendar and read what a reader or a screen reader actually gets.
//
// TR.04 was red for its stated reason before the fix (66 English month labels
// on the live Polish page; here, every row's aria-label). The others hold
// today and were proven by recorded mutation runs (plan §06).

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick } from 'svelte'
import pl from '../src/lib/locales/pl.json'
import en from '../src/lib/locales/en.json'
import type { CalendarEvent, EventStatus } from '../src/lib/types'

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue([]),
  fetchScoringEngines: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchRankingFull: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchScoringConfig: vi.fn().mockResolvedValue(null),
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))

import App from '../src/App.svelte'
import { fetchAllCalendarEvents } from '../src/lib/api'
import { setLocale } from '../src/lib/locale.svelte'

const PL = pl as Record<string, string>
const EN = en as Record<string, string>

const SOURCES = import.meta.glob('../src/**/*.{ts,svelte}', {
  query: '?raw', import: 'default', eager: true,
}) as Record<string, string>

function source(file: string): string {
  const text = SOURCES[`../src/${file}`]
  if (text === undefined) throw new Error(`source not found: ${file}`)
  return text
}

/** The string members of a TypeScript union, read from its declaration. */
function unionOf(file: string, typeName: string): string[] {
  const match = new RegExp(`export type ${typeName} =([^\\n]+)`).exec(source(file))
  if (!match) throw new Error(`type ${typeName} not found in ${file}`)
  return [...match[1]!.matchAll(/'([^']+)'/g)].map((m) => m[1]!)
}

function range(from: number, to: number): string[] {
  return Array.from({ length: to - from + 1 }, (_, i) => String(from + i))
}

describe('TR.01 — every literal key exists in both locales', () => {
  // A key literal that closes its call: t('key') or t('key', vars), and
  // tIn(locale, 'key'). `t('legend_' + type)` is a family, not a key (TR.02).
  const LITERAL = /\bt\(\s*(['"])([^'"`$\n]+?)\1\s*[),]/g
  const LITERAL_IN = /\btIn\(\s*[^,()]+,\s*(['"])([^'"`$\n]+?)\1\s*[),]/g

  const used = new Map<string, string>()
  for (const [file, text] of Object.entries(SOURCES)) {
    for (const re of [LITERAL, LITERAL_IN]) {
      for (const m of text.matchAll(re)) used.set(m[2]!, file)
    }
  }

  it('finds the code base’s key literals (the scan is not vacuous)', () => {
    expect(used.size).toBeGreaterThan(450)
  })

  it('every one of them is in pl.json and en.json', () => {
    const missing = [...used].filter(([k]) => !(k in PL) || !(k in EN)).map(([k, f]) => `${k} (${f})`)
    expect(missing, `keys used in code but missing from a locale: ${missing.join(', ')}`).toEqual([])
  })
})

describe('TR.02 — every key family built at runtime is complete', () => {
  // Each family: the shape its call sites build (`${…}` and `' + x` → `*`),
  // and the domain it is built over, read from the source that owns it.
  const isoByCountry = (() => {
    const text = source('lib/calendarMonths.ts')
    const start = text.indexOf('{', text.indexOf('const ISO_BY_COUNTRY'))
    const body = text.slice(start, text.indexOf('}', start))
    return [...new Set([...body.matchAll(/:\s*'([A-Z]{2})'/g)].map((m) => m[1]!))]
  })()
  const steps = (() => {
    const m = /const STEP_NUMBERS = \[([^\]]+)\]/.exec(source('components/FtlExport.svelte'))
    return m ? m[1]!.split(',').map((s) => s.trim()) : []
  })()
  const plurals = (() => {
    const m = /function pluralKey\(n: number\): ([^{]+)\{/.exec(source('components/SeasonRulesModal.svelte'))
    return m ? [...m[1]!.matchAll(/'([^']+)'/g)].map((x) => x[1]!) : []
  })()

  const FAMILIES: { shape: string; keys: string[]; why: string }[] = [
    { shape: 'month_*', keys: range(1, 12).map((n) => `month_${n}`), why: 'seam, nominative' },
    { shape: 'cal_month_*', keys: range(1, 12).map((n) => `cal_month_${n}`), why: 'tile and card, genitive' },
    { shape: 'cal_month_short_*', keys: range(1, 12).map((n) => `cal_month_short_${n}`), why: 'tile' },
    { shape: 'cal_dow_short_*', keys: range(1, 7).map((n) => `cal_dow_short_${n}`), why: 'card date, Monday-first' },
    // The codes countryCode() can return — the only ones that reach a label.
    { shape: 'country_*', keys: isoByCountry.map((c) => `country_${c}`), why: 'card location' },
    // App's bar title for a view other than the ranklist and the calendar.
    { shape: 'nav_*', keys: unionOf('lib/types.ts', 'AppView').map((v) => `nav_${v}`), why: 'bar title' },
    { shape: 'legend_*', keys: unionOf('lib/types.ts', 'TournamentType').map((v) => `legend_${v.toLowerCase()}`), why: 'type legends' },
    { shape: 'sr_best_*', keys: plurals.map((p) => `sr_best_${p}`), why: 'season rules, Polish plural' },
    { shape: 'sr_band_*', keys: plurals.map((p) => `sr_band_${p}`), why: 'season rules, Polish plural' },
    { shape: 'ftl_step*_h', keys: steps.map((n) => `ftl_step${n}_h`), why: 'FTL how-to' },
    { shape: 'ftl_step*_b', keys: steps.map((n) => `ftl_step${n}_b`), why: 'FTL how-to' },
    { shape: 'ftl_w_*', keys: unionOf('lib/types.ts', 'WeaponType').map((w) => `ftl_w_${w}`), why: 'FTL weapon groups' },
    { shape: 'export_method_*', keys: unionOf('lib/scoring.ts', 'ScoreMethod').map((m) => `export_method_${m}`), why: 'export column' },
    { shape: 'sc_rules_warn_pool_*', keys: unionOf('lib/ranking-rules.ts', 'Pool').map((p) => `sc_rules_warn_pool_${p}`), why: 'admin rules warning' },
  ]

  /** Every key a call site builds at runtime, as its shape. */
  const built = new Map<string, string>()
  for (const [file, text] of Object.entries(SOURCES)) {
    for (const re of [/\bt\(\s*`([^`]*\$\{[^`]*)`/g, /\btIn\(\s*[^,()]+,\s*`([^`]*\$\{[^`]*)`/g]) {
      for (const m of text.matchAll(re)) built.set(m[1]!.replace(/\$\{[^}]*\}/g, '*'), file)
    }
    for (const m of text.matchAll(/\bt\(\s*(['"])([^'"\n]+)\1\s*\+/g)) built.set(`${m[2]}*`, file)
  }

  it('every runtime-built key belongs to a declared family', () => {
    const declared = new Set(FAMILIES.map((f) => f.shape))
    const unknown = [...built].filter(([shape]) => !declared.has(shape)).map(([s, f]) => `${s} (${f})`)
    expect(unknown, `declare these families and their domains here: ${unknown.join(', ')}`).toEqual([])
    expect(built.size).toBeGreaterThanOrEqual(FAMILIES.length)
  })

  for (const family of FAMILIES) {
    it(`${family.shape} is complete for its whole domain (${family.why})`, () => {
      expect(family.keys.length, 'the domain was read from source').toBeGreaterThan(1)
      const missing = family.keys.filter((k) => !(k in PL) || !(k in EN))
      expect(missing, `missing from a locale: ${missing.join(', ')}`).toEqual([])
    })
  }
})

describe('TR.03 — a value identical in PL and EN needs a reason', () => {
  const CODE = 'a code or abbreviation, the same in both languages'
  const SAME_NAME = 'a country name spelled the same in Polish and English'
  const SAME_WORD = 'a word that is the same in Polish and English'
  // Found 2026-10-06 and reported to the user as a decision, not fixed in the
  // calendar change: English left in the Polish admin UI.
  const KNOWN_EN = 'KNOWN: English in the Polish admin UI, reported 2026-10-06, not fixed in this change'

  const ALLOWED: Record<string, string> = {
    ranking: SAME_WORD,
    mode_ppw: CODE,
    mode_ranking: SAME_WORD,
    col_mpw: CODE,
    col_spws: CODE,
    col_evf_plus: CODE,
    domestic_ppw_mpw: CODE,
    international_evf: CODE,
    legend_evf_label: CODE,
    legend_pzsz_label: 'a code with "bonus", the same word in Polish',
    event_iban_placeholder: 'an example IBAN, a format sample',
    event_status_label: SAME_WORD,
    import_title: SAME_WORD,
    import_status_reimport: 'a status code',
    import_reimport_count: 'a count with "reimport", used as is in Polish',
    sc_min_evf_hint: CODE,
    sc_engine_opt_code: KNOWN_EN,
    sc_engine_legacy_tag: KNOWN_EN,
    sc_engine_short_SPWS_EVF_JOINED_V1_2026_2027: 'a proper name: SPWS and a season',
    season_skel_pending: KNOWN_EN,
    season_skel_badge_created: 'a status code',
    event_status_created: 'a status code',
    reg_iban_label: CODE,
    country_AT: SAME_NAME,
    country_LI: SAME_NAME,
    country_EE: SAME_NAME,
    country_RS: SAME_NAME,
    country_SM: SAME_NAME,
    country_AM: SAME_NAME,
    country_GI: SAME_NAME,
    country_PE: SAME_NAME,
    country_HT: SAME_NAME,
    country_GM: SAME_NAME,
    country_BW: SAME_NAME,
    country_MU: SAME_NAME,
    country_RW: SAME_NAME,
    country_GA: SAME_NAME,
    country_SL: SAME_NAME,
    country_NG: SAME_NAME,
    country_ML: SAME_NAME,
    country_LA: SAME_NAME,
    country_PW: SAME_NAME,
    ftl_lang_pl: 'a language’s own name',
    ftl_lang_en: 'a language’s own name',
  }

  const identical = Object.keys(PL).filter((k) => k in EN && PL[k] === EN[k])

  it('no identical pair outside the allowlist', () => {
    const unexplained = identical.filter((k) => !(k in ALLOWED))
    expect(unexplained, `identical in PL and EN with no reason: ${unexplained.join(', ')}`).toEqual([])
  })

  it('no allowlist entry outlives its pair', () => {
    const stale = Object.keys(ALLOWED).filter((k) => !identical.includes(k))
    expect(stale, `translated now; remove from the allowlist: ${stale.join(', ')}`).toEqual([])
  })
})

// ---------------------------------------------------------------------------
// TR.04–TR.06 — what the calendar page actually shows and announces.
// ---------------------------------------------------------------------------

/** Interface words of the other language. Data (cities, codes) is never
 *  checked: only these words, whole, and anything shaped like a raw key. */
const ENGLISH_UI = [
  // Month names, whole and on the seam and in labels.
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December',
  // Short weekdays and months as the card and tiles print them ("Mar" is
  // also Polish, so it is left out).
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  'Jan', 'Feb', 'Apr', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  // Interface words the calendar, its card, its bar and its drawer use.
  'Earlier', 'Later', 'competition', 'competitions', 'Finder', 'Calendar',
  'nearest', 'Nearest', 'Events', 'events', 'Registration', 'Register',
  'Results', 'Copy', 'Copied', 'Planned', 'Completed', 'Cancelled',
  'Epee', 'Foil', 'Sabre', 'Day', 'deadline', 'fee', 'month', 'Previous',
  'Next', 'Home', 'Ranklist', 'Calculator', 'Table', 'Points',
]

const POLISH_UI = [
  'Styczeń', 'Luty', 'Marzec', 'Kwiecień', 'Maj', 'Czerwiec', 'Lipiec',
  'Sierpień', 'Wrzesień', 'Październik', 'Listopad', 'Grudzień',
  'stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca', 'lipca',
  'sierpnia', 'września', 'października', 'listopada', 'grudnia',
  // Short months, without "mar", which English prints too.
  'sty', 'lut', 'kwi', 'cze', 'lip', 'sie', 'wrz', 'paź', 'lis', 'gru',
  'pon', 'wt', 'śr', 'czw', 'pt', 'sob', 'niedz',
  'zawody', 'zawodów', 'Znajdź', 'najbliższe', 'Najbliższe', 'brak',
  'Wcześniejsze', 'Późniejsze', 'Kalendarz', 'Szpada', 'Floret', 'Szabla',
  'Zaplanowane', 'Zakończone', 'Wyniki', 'Rejestracja', 'Skopiowano',
  'Kopiuj', 'Dzień', 'miesiąc', 'Tabela', 'Kalkulator', 'punktów', 'punktacji',
]

/** Strings that are correct in both languages on these surfaces. */
const BOTH = new Set([
  'Menu', // ☰ — the same word in Polish
  'English', 'Polski', // the language switch names each language in its own
])

const RAW_KEY = /^[a-z][a-z0-9]*(_[a-z0-9]+)+$/

/** Every visible text and every accessible name, title and alt under `root`. */
function uiStrings(root: Element, skip: string[] = []): string[] {
  const out: string[] = []
  const skipped = (el: Element | null) => !!el && skip.some((s) => el.closest(s))
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT)
  for (let n: Node | null = walker.currentNode; n; n = walker.nextNode()) {
    if (n.nodeType === Node.TEXT_NODE) {
      const parent = n.parentElement
      if (!parent || skipped(parent) || parent.closest('style, script')) continue
      const text = n.textContent?.trim()
      if (text) out.push(text)
    } else {
      const el = n as Element
      if (skipped(el)) continue
      for (const attr of ['aria-label', 'title', 'alt', 'placeholder']) {
        const v = el.getAttribute(attr)?.trim()
        if (v) out.push(v)
      }
    }
  }
  return out
}

function foreign(strings: string[], words: string[]): string[] {
  const hits: string[] = []
  for (const s of strings) {
    if (BOTH.has(s)) continue
    if (RAW_KEY.test(s)) { hits.push(`raw key "${s}"`); continue }
    for (const w of words) {
      if (new RegExp(`(?<![\\p{L}])${w}(?![\\p{L}])`, 'u').test(s)) {
        hits.push(`"${s}" (${w})`)
        break
      }
    }
  }
  return hits
}

let nextId = 1
function ev(code: string, monthsFromNow: number, extra: Partial<CalendarEvent> = {}): CalendarEvent {
  const d = new Date()
  d.setDate(12)
  d.setMonth(d.getMonth() + monthsFromNow)
  const start = d.toISOString().slice(0, 10)
  return {
    id_event: nextId++,
    txt_code: code,
    txt_name: code,
    id_season: 1,
    txt_season_code: 'SPWS-2026-2027',
    id_organizer: null,
    txt_organizer_name: null,
    txt_location: 'Opole',
    txt_country: 'Polska',
    txt_venue_address: 'Hala Sportowa, ul. Sportowa 1',
    url_invitation: 'https://example.org/invitation.pdf',
    num_entry_fee: 150,
    txt_entry_fee_currency: 'PLN',
    dt_start: start,
    dt_end: start,
    arr_weapons: ['EPEE', 'FOIL', 'SABRE'],
    url_event: null,
    enum_status: (monthsFromNow < 0 ? 'COMPLETED' : 'PLANNED') as EventStatus,
    num_tournaments: 3,
    bool_has_international: false,
    url_registration: monthsFromNow >= 0 ? 'https://example.org/register' : null,
    dt_registration_deadline: null,
    url_event_2: null,
    url_event_3: null,
    url_event_4: null,
    url_event_5: null,
    ...extra,
  }
}

/** Nine consecutive months around today, so the drum has rows on both sides. */
function pool(): CalendarEvent[] {
  return [
    ev('PPW3-2025-2026', -4),
    ev('PEW5ef-2025-2026', -3, { txt_location: 'Budapest', txt_country: 'Węgry' }),
    ev('PPW4-2025-2026', -2),
    ev('MPW-2025-2026', -1),
    ev('PPW1-2026-2027', 0),
    ev('MSW-2026-2027', 1, { txt_location: 'Tbilisi', txt_country: 'Gruzja' }),
    ev('PPW2-2026-2027', 2),
    ev('PEW3fs-2026-2027', 3, { txt_location: 'Madrid', txt_country: 'Hiszpania' }),
    ev('PPW3-2026-2027', 4),
  ]
}

async function settle(): Promise<void> {
  for (let i = 0; i < 5; i++) {
    await new Promise((r) => setTimeout(r, 0))
    await tick()
  }
}

async function sweep(props: Record<string, unknown>, lang: 'pl' | 'en', skip: string[] = []) {
  setLocale(lang)
  const { container } = render(App, { props })
  await settle()
  const closed = uiStrings(container, skip)
  const menu = container.querySelector('.hamburger-btn')
  if (menu) await fireEvent.click(menu)
  await settle()
  return { closed, open: uiStrings(container, skip), container }
}

const SITE = {
  'supabase-prod-url': 'https://prod.supabase.co',
  'supabase-prod-key': 'prod-key',
  view: 'calendar',
  chrome: 'site',
  'href-home': 'https://weteraniszermierki.pl/',
  'href-ranking': '/ranking/',
  'href-calendar': '/znajdz-zawody/',
  'href-calculator': '/kalkulator-punktow/',
  'href-table': '/tabela-punktacji/',
}

const GITHUB = {
  'supabase-cert-url': 'https://cert.supabase.co',
  'supabase-cert-key': 'cert-key',
  'supabase-prod-url': 'https://prod.supabase.co',
  'supabase-prod-key': 'prod-key',
  view: 'calendar',
}

// The github.io TEST ribbon is bilingual by decision (ADR-109, WP.ENV.01).
const RIBBON = ['.env-ribbon']

describe('TR.04–TR.06 — the calendar speaks one language at a time', () => {
  beforeEach(() => {
    vi.mocked(fetchAllCalendarEvents).mockResolvedValue(pool())
  })

  it('renders the drum, the card and the bar (the sweep sees the page)', async () => {
    const { container } = await sweep(SITE, 'pl')
    expect(container.querySelectorAll('.ln').length).toBeGreaterThan(5)
    expect(container.querySelector('.ln.mid .p')).not.toBeNull()
    expect(container.querySelector('header.site-bar')).not.toBeNull()
    expect(container.querySelector('.sidebar.open')).not.toBeNull()
  })

  it('TR.04: the calendar page in Polish has no English UI word and no raw key', async () => {
    const { closed, open } = await sweep(SITE, 'pl')
    const hits = [...new Set([...foreign(closed, ENGLISH_UI), ...foreign(open, ENGLISH_UI)])]
    expect(hits, `English on the Polish page: ${hits.join('; ')}`).toEqual([])
  })

  it('TR.05: the calendar page in English has no Polish UI word and no raw key', async () => {
    const { closed, open } = await sweep(SITE, 'en')
    const hits = [...new Set([...foreign(closed, POLISH_UI), ...foreign(open, POLISH_UI)])]
    expect(hits, `Polish on the English page: ${hits.join('; ')}`).toEqual([])
  })

  it('TR.06: the github.io shell’s calendar view, in Polish and in English', async () => {
    const plPage = await sweep(GITHUB, 'pl', RIBBON)
    const plHits = [...new Set([...foreign(plPage.closed, ENGLISH_UI), ...foreign(plPage.open, ENGLISH_UI)])]
    plPage.container.remove()
    const enPage = await sweep(GITHUB, 'en', RIBBON)
    const enHits = [...new Set([...foreign(enPage.closed, POLISH_UI), ...foreign(enPage.open, POLISH_UI)])]
    expect(plHits, `English on the Polish github.io page: ${plHits.join('; ')}`).toEqual([])
    expect(enHits, `Polish on the English github.io page: ${enHits.join('; ')}`).toEqual([])
  })
})
