// Calendar row barrel — pure derivation layer (ADR-084, Phase 1).
//
// Everything the old month-grouped view derived inline in CalendarView.svelte
// lives here so it can be unit-tested without mounting a component. No Svelte,
// no runes, no DOM. The barrel and the card are presentation only.
//
// Plan: doc/plans/kalendarz-barrel-2026-08-08.html §06.
// Tests: frontend/tests/calendarMonths.test.ts (CQ.1–CQ.69).

import type { CalendarEvent } from './types'

/**
 * Four buckets, ported from `slotTypeClass()` (CalendarView.svelte:241-246)
 * with the fourth renamed `imew` → `int`.
 *
 * `mpw` is kept distinct even though nothing styles it differently yet. The
 * retired strip classified it separately and then painted it identically to
 * `ppw`; discarding the bucket now would turn the past-season anchor decision
 * (ADR-084 open item 2) into a prerequisite instead of a styling choice.
 *
 * `pzs` is the fifth: Polish national senior events (PPS / MPS), run by Polski
 * Związek Szermierczy rather than by SPWS. Veterans enter them alongside people
 * half their age, so they belong on the calendar — but they are neither an SPWS
 * veteran event nor an international one, and share a hue with neither.
 */
export type PanelType = 'ppw' | 'mpw' | 'pew' | 'int' | 'pzs'

export type CalendarScope = 'all' | 'ppw'

export interface MonthRow {
  /** Sortable identity, e.g. `2026-09`. */
  key: string
  year: number
  /** 1-12. The seam localises from this; `label` is the English fallback. */
  month: number
  /** Engraved on the seam above the row, e.g. `September 2026`. */
  label: string
  events: CalendarEvent[]
  /**
   * Every season code present, in chronological order of its first event.
   * A row can legitimately hold two seasons — CERT has `PEW8f-2025-2026`
   * sitting among 2024-25 events. An empty row inherits the running season
   * so the seam does not blank out mid-drum.
   */
  seasonCodes: string[]
  /** True when this row opens a season the previous row was not in. */
  isSeasonBoundary: boolean
  isEmpty: boolean
}

export interface RegistrationState {
  /** `dt_registration_deadline ?? dt_start` — ADR-030. */
  regCutoff: string | null
  showDeadline: boolean
  showRegistrationLink: boolean
  showEntryListLink: boolean
  /** Cutoff less than seven days away — ADR-030's two-tier urgency. */
  urgent: boolean
  /** ADR-079 §7: open RegistrationModal instead of navigating. */
  useSpwsModal: boolean
}

export interface CalendarModel {
  rows: MonthRow[]
  nextUpcoming: CalendarEvent | null
  anchorIndex: number
}

const DAY_MS = 86_400_000

/** Ported verbatim from CalendarView.svelte:231-233. */
const INTL_PREFIXES = /^(PEW|MEW|MSW|PSW|IMEW|IMSW)/

/**
 * Free-text country name → ISO-3166 alpha-2.
 *
 * `txt_country` is written by hand and by scrapers in mixed languages, so both
 * the English and Polish forms are listed. Codes here are not all drawable —
 * `GB` resolves fine but CountryFlag has no Union-flag primitive, so the card
 * shows the place without a chip. Identity and rendering are separate concerns
 * on purpose.
 */
const ISO_BY_COUNTRY: Record<string, string> = {
  // Values observed verbatim in CERT, including the inconsistent ones.
  polska: 'PL',
  poland: 'PL',
  'great britain': 'GB',
  'united kingdom': 'GB',
  'wielka brytania': 'GB',
  gruzja: 'GE',
  georgia: 'GE',
  // Europe — English then Polish where the Polish name differs.
  austria: 'AT',
  belgium: 'BE',
  belgia: 'BE',
  bulgaria: 'BG',
  bułgaria: 'BG',
  switzerland: 'CH',
  szwajcaria: 'CH',
  czechia: 'CZ',
  czechy: 'CZ',
  germany: 'DE',
  niemcy: 'DE',
  denmark: 'DK',
  dania: 'DK',
  estonia: 'EE',
  spain: 'ES',
  hiszpania: 'ES',
  finland: 'FI',
  finlandia: 'FI',
  france: 'FR',
  francja: 'FR',
  greece: 'GR',
  grecja: 'GR',
  croatia: 'HR',
  chorwacja: 'HR',
  hungary: 'HU',
  węgry: 'HU',
  ireland: 'IE',
  irlandia: 'IE',
  iceland: 'IS',
  islandia: 'IS',
  italy: 'IT',
  włochy: 'IT',
  liechtenstein: 'LI',
  lithuania: 'LT',
  litwa: 'LT',
  luxembourg: 'LU',
  luksemburg: 'LU',
  latvia: 'LV',
  łotwa: 'LV',
  monaco: 'MC',
  monako: 'MC',
  netherlands: 'NL',
  holandia: 'NL',
  niderlandy: 'NL',
  norway: 'NO',
  norwegia: 'NO',
  portugal: 'PT',
  portugalia: 'PT',
  romania: 'RO',
  rumunia: 'RO',
  serbia: 'RS',
  russia: 'RU',
  rosja: 'RU',
  sweden: 'SE',
  szwecja: 'SE',
  slovenia: 'SI',
  słowenia: 'SI',
  slovakia: 'SK',
  słowacja: 'SK',
  'san marino': 'SM',
  ukraine: 'UA',
  ukraina: 'UA',
  belarus: 'BY',
  białoruś: 'BY',
  gibraltar: 'GI',
  'faroe islands': 'FO',
  'wyspy owcze': 'FO',
  armenia: 'AM',
  // Elsewhere — EVF and world-championship destinations.
  bahrain: 'BH',
  bahrajn: 'BH',
  qatar: 'QA',
  katar: 'QA',
  canada: 'CA',
  kanada: 'CA',
  japan: 'JP',
  japonia: 'JP',
  thailand: 'TH',
  tajlandia: 'TH',
  indonesia: 'ID',
  indonezja: 'ID',
  peru: 'PE',
  colombia: 'CO',
  kolumbia: 'CO',
  ecuador: 'EC',
  ekwador: 'EC',
  bolivia: 'BO',
  boliwia: 'BO',
  'costa rica': 'CR',
  kostaryka: 'CR',
  haiti: 'HT',
  yemen: 'YE',
  jemen: 'YE',
  libya: 'LY',
  libia: 'LY',
  gambia: 'GM',
  botswana: 'BW',
  mauritius: 'MU',
  rwanda: 'RW',
  gabon: 'GA',
  'sierra leone': 'SL',
  nigeria: 'NG',
  guinea: 'GN',
  gwinea: 'GN',
  mali: 'ML',
  chad: 'TD',
  czad: 'TD',
  bangladesh: 'BD',
  bangladesz: 'BD',
  laos: 'LA',
  palau: 'PW',
}

export function todayIso(): string {
  return new Date().toISOString().slice(0, 10)
}

// ---------------------------------------------------------------------------
// Quarters
// ---------------------------------------------------------------------------

/** Sortable identity for a calendar month, e.g. `2026-09`. */
export function monthKeyOf(isoDate: string): string {
  return isoDate.slice(0, 7)
}

/**
 * English month names. The seam renders a LOCALISED label from `year`/`month`
 * on the row — Polish needs the nominative here ("Wrzesień") and the genitive
 * on the tile beside a day ("26 września"), which only the component can pick.
 * This stays as a stable, language-independent fallback.
 */
const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
] as const

export function monthLabel(year: number, month: number): string {
  return `${MONTH_NAMES[month - 1]} ${year}`
}

/** `SPWS-2025-2026` → `25/26`; anything unparseable → `''`. */
export function seasonShortCode(code: string | null | undefined): string {
  const match = /(\d{4})-(\d{4})/.exec(code ?? '')
  return match ? `${match[1]!.slice(2)}/${match[2]!.slice(2)}` : ''
}

function stepMonth(year: number, month: number): [number, number] {
  return month === 12 ? [year + 1, 1] : [year, month + 1]
}

/**
 * Bucket events into a continuous run of rows.
 *
 * Sorts by `dt_start` itself and never inherits caller order:
 * `fetchPriorSeasonEvents` (api.ts:206) orders by `txt_code`, which puts
 * `PEW10` before `PEW2`, so the multi-season path arrives in an order that is
 * neither chronological nor numeric.
 *
 * Quarters with no events are materialised so the drum does not jump over a
 * quiet stretch of history. Events with no `dt_start` cannot be placed and are
 * dropped.
 */
export function buildMonths(events: CalendarEvent[]): MonthRow[] {
  const dated = events
    .filter((e): e is CalendarEvent & { dt_start: string } => !!e.dt_start)
    .slice()
    .sort((a, b) => a.dt_start.localeCompare(b.dt_start) || a.txt_code.localeCompare(b.txt_code))

  if (dated.length === 0) return []

  const byKey = new Map<string, CalendarEvent[]>()
  for (const event of dated) {
    const key = monthKeyOf(event.dt_start)
    const bucket = byKey.get(key)
    if (bucket) bucket.push(event)
    else byKey.set(key, [event])
  }

  const first = dated[0]!.dt_start
  const last = dated[dated.length - 1]!.dt_start
  let year = Number(first.slice(0, 4))
  let month = Number(first.slice(5, 7))
  const lastKey = monthKeyOf(last)

  const rows: MonthRow[] = []
  let runningSeason: string | null = null

  for (;;) {
    const key = `${year}-${String(month).padStart(2, '0')}`
    const rowEvents = byKey.get(key) ?? []

    let seasonCodes: string[]
    let isSeasonBoundary = false

    if (rowEvents.length > 0) {
      seasonCodes = []
      for (const event of rowEvents) {
        if (event.txt_season_code && !seasonCodes.includes(event.txt_season_code)) {
          seasonCodes.push(event.txt_season_code)
        }
      }
      const opensWith = seasonCodes[0]
      isSeasonBoundary = runningSeason !== null && opensWith !== undefined && opensWith !== runningSeason
      runningSeason = seasonCodes[seasonCodes.length - 1] ?? runningSeason
    } else {
      // Inherit so the seam keeps showing a season across a quiet month.
      seasonCodes = runningSeason ? [runningSeason] : []
    }

    rows.push({
      key,
      year,
      month,
      label: monthLabel(year, month),
      events: rowEvents,
      seasonCodes,
      isSeasonBoundary,
      isEmpty: rowEvents.length === 0,
    })

    if (key === lastKey) break
    ;[year, month] = stepMonth(year, month)
  }

  return rows
}

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

export function panelType(code: string): PanelType {
  if (/^PEW/.test(code)) return 'pew'
  if (/^(IMEW|IMSW|MEW|MSW|PSW)/.test(code)) return 'int'
  if (/^MPW/.test(code)) return 'mpw'
  // Before the ppw fallback, and matched on the full three-letter prefix. PPS
  // shares its first two letters with PPW and MPS with MPW, so this must be
  // both specific enough not to swallow them and early enough to be reached at
  // all — `return 'ppw'` below catches everything that gets this far.
  if (/^(PPS|MPS)/.test(code)) return 'pzs'
  return 'ppw'
}

export function isInternationalEvent(event: CalendarEvent): boolean {
  return event.bool_has_international || INTL_PREFIXES.test(event.txt_code)
}

/**
 * The short code a barrel panel shows — `PEW63e-2026-2027` → `EVF63`.
 *
 * EVF codes are shortened because a panel is 48px wide. The weapon suffix is
 * dropped: it bought nothing once the weapon filter was removed, and the full
 * code is preserved on the card, so nothing is lost.
 */
export function panelLabel(code: string): string {
  const prefix = code.split('-')[0] ?? ''
  if (panelType(code) === 'pew') {
    const digits = /^PEW-?(\d*)/.exec(prefix)
    return `EVF${digits?.[1] ?? ''}`
  }
  return prefix.replace(/[efs]+$/, '')
}

/** Which body owns the event, for the card's second status chip. */
export function registryOf(type: PanelType): 'SPWS' | 'EVF' | 'FIE' | 'PZSz' {
  if (type === 'pew') return 'EVF'
  if (type === 'int') return 'FIE'
  if (type === 'pzs') return 'PZSz'
  return 'SPWS'
}

export type WeaponLetter = 'E' | 'F' | 'S'

/**
 * Weapons an event covers, from the lowercase suffix on its code (ADR-046) —
 * `PEW3ef-2026-2027` → `['E','F']`.
 *
 * `arr_weapons` is not usable for this: the column defaults to all three
 * weapons and 102 of 103 events sit on that default, so it cannot distinguish
 * "genuinely all three" from "nobody set this". The code suffix is authoritative
 * where it exists; an unsuffixed code yields an empty list rather than a guess.
 */
export function weaponLetters(code: string): WeaponLetter[] {
  const prefix = code.split('-')[0] ?? ''
  const match = /[efs]+$/.exec(prefix)
  if (!match) return []
  const seen = new Set(match[0].toUpperCase().split('') as WeaponLetter[])
  return (['E', 'F', 'S'] as WeaponLetter[]).filter((w) => seen.has(w))
}

/**
 * Whether a tiered entry fee can exist on this event at all.
 *
 * A tier can only exist where the tier does: an event covering foil alone has
 * no two-weapon price, so a populated `num_entry_fee_2w` there is a data error
 * rather than something to render (ADR-084 §8). Where the weapon count is
 * unknown — an unsuffixed code — the tier is allowed through, because
 * suppressing real pricing on missing metadata is the worse failure.
 */
export function allowsFeeTier(code: string, tier: 2 | 3): boolean {
  const count = weaponLetters(code).length
  return count === 0 || count >= tier
}

const VENUE_WORDS =
  /sporthalle|salle |complexe|polideportivo|palavesuvio|spectrum|idrottshall|topsporthal|sport ?cent|sports city|castle|pavilh|palais|paladozza|country hall|variety village|olympic palace|arena|ar[eé]na|berufsschule/i

/**
 * Split `txt_location` into the city and the venue it may wrongly contain.
 *
 * The column is specified to hold a city, but the EVF scraper has written venue
 * strings into it — `Sporthalle der Städtischen Berufsschule…`,
 * `Savoy Terrace - Buda Castle`. Classification decides **which line** the
 * string lands on and whether it earns a flag; it never decides whether the
 * string is shown. An earlier heuristic used it as a visibility gate and hid 9
 * events that had a location, so the fallback here is always the raw value.
 *
 * Never invents a city that is not literally in the string.
 */
export function splitLocation(raw: string | null | undefined): {
  city: string
  venue: string
} {
  const value = raw?.trim()
  if (!value) return { city: '', venue: '' }

  // `Venue - City` — only when the tail is a single capitalised word, which is
  // what distinguishes a city from the rest of a venue name.
  const parts = value.split(/\s+-\s+/)
  if (parts.length === 2) {
    const tail = parts[1]!.trim()
    if (/^[A-ZŁŚŻŹĆÓĄĘŃ][^\s]*$/.test(tail)) {
      return { city: tail, venue: parts[0]!.trim() }
    }
  }

  if (VENUE_WORDS.test(value)) return { city: '', venue: value }
  return { city: value, venue: '' }
}

/** ADR-030's deadline, rendered `dd/mm/yyyy`. */
export function formatDeadline(iso: string): string {
  const [y, m, d] = iso.split('-')
  return y && m && d ? `${d}/${m}/${y}` : iso
}

/**
 * Locale key for a tournament count.
 *
 * Polish has three plural forms and the count picks between them —
 * `1 turniej`, `2–4 turnieje`, `0 and 5+ turniejów` — with the trap that 12, 13
 * and 14 take the genitive despite ending in 2–4, while 22, 23 and 24 do not.
 * English collapses `few` and `many` onto one string, so the same three keys
 * serve both languages (ADR-084 §12, amending ADR-005).
 */
export function tournamentsPluralKey(count: number): string {
  const last = count % 10
  const lastTwo = count % 100
  if (count === 1) return 'tournaments_one'
  if (last >= 2 && last <= 4 && !(lastTwo >= 12 && lastTwo <= 14)) return 'tournaments_few'
  return 'tournaments_many'
}

/**
 * The event's result URLs, in slot order with the gaps closed.
 *
 * ADR-040 holds the five slots to be equal-status with no role labels and no
 * primary pointer, and compact-on-save guarantees slot 1 is filled whenever any
 * slot is. Day labels are derived at render time from this list's length; they
 * are never stored.
 */
export function resultUrls(event: CalendarEvent): string[] {
  return [
    event.url_event,
    event.url_event_2,
    event.url_event_3,
    event.url_event_4,
    event.url_event_5,
  ].filter((u): u is string => !!u && u.trim() !== '')
}

/**
 * The string the card's copy button puts on the clipboard: venue, city and
 * country name joined.
 *
 * The card can afford to show the country as a flag because the reader can see
 * it; a string pasted into a maps app or sent to a driver cannot, which is why
 * the country survives here even though its own card row was dropped.
 */
export function composeAddress(parts: {
  venue?: string | null
  city?: string | null
  country?: string | null
}): string {
  return [parts.venue, parts.city, parts.country]
    .map((p) => p?.trim())
    .filter((p): p is string => !!p)
    .join(', ')
}

// ---------------------------------------------------------------------------
// Visibility — ADR-037 / ADR-077, ported unchanged
// ---------------------------------------------------------------------------

/**
 * A cancelled event stays on the public calendar while
 * `today <= dt_end + 7 days` so the notice is actually seen, then disappears.
 * Only ever applies to `CANCELLED` — ADR-037 amendment (2026-08-07).
 */
export function isWithinCancellationNoticeWindow(
  event: CalendarEvent,
  today: string = todayIso(),
): boolean {
  if (event.enum_status !== 'CANCELLED') return true
  if (!event.dt_end) return true
  const hideAfter = new Date(`${event.dt_end}T00:00:00Z`)
  hideAfter.setUTCDate(hideAfter.getUTCDate() + 7)
  return today <= hideAfter.toISOString().slice(0, 10)
}

/**
 * Whether EVF moved this event, and it still matters — the "moved from" pill
 * (ADR-077 amendment).
 *
 * Three conditions, all required:
 *   * `PLANNED` — the only state where a reschedule is still actionable.
 *     Every date change in recorded history on any other status was a data
 *     repair (one-day corrections, DD/MM parse fixes, the 2025-2026 fragment
 *     repair), never a reschedule.
 *   * still ahead — nobody needs telling that a finished event once moved.
 *   * `dt_start` differs from the first date EVF published.
 *
 * Anchored to the FIRST published date, not the previous one, so an event moved
 * twice still reads against the date originally announced. Nothing clears it:
 * it stands until the event passes or leaves `PLANNED`.
 */
export function movedFromDate(
  event: CalendarEvent,
  today: string = todayIso(),
): string | null {
  if (event.enum_status !== 'PLANNED') return null
  const anchor = event.dt_start_first_published
  if (!anchor || !event.dt_start) return null
  if (event.dt_start <= today) return null
  return event.dt_start === anchor ? null : anchor
}

/**
 * `CREATED` events are date-less planning skeletons (ADR-077) and are hidden
 * until dated; cancelled events drop out once their notice window closes.
 */
export function visibleEvents(
  events: CalendarEvent[],
  today: string = todayIso(),
): CalendarEvent[] {
  return events.filter(
    (e) => e.enum_status !== 'CREATED' && isWithinCancellationNoticeWindow(e, today),
  )
}

// ---------------------------------------------------------------------------
// Scope — ADR-017 as amended by ADR-084 §10
// ---------------------------------------------------------------------------

/**
 * `showEvfToggle` is the per-season `show_evf_toggle_calendar` config, and it
 * **constrains the data, not just the buttons**: with it off the calendar is
 * domestic-only whatever the scope state says. Hiding the control alone would
 * strand EVF events on screen with no way to filter them.
 */
export function filterByScope(
  events: CalendarEvent[],
  scope: CalendarScope,
  showEvfToggle: boolean,
): CalendarEvent[] {
  if (!showEvfToggle || scope === 'ppw') {
    return events.filter((e) => !isInternationalEvent(e))
  }
  return events.slice()
}

// ---------------------------------------------------------------------------
// Next upcoming
// ---------------------------------------------------------------------------

/**
 * The earliest event still ahead of today, which the barrel rings.
 *
 * Must be derived from the **filtered** set rather than assigned once, so
 * toggling scope moves the ring. A cancelled event is never "next upcoming" —
 * ringing one as the thing to look forward to would be wrong even while its
 * notice window keeps it visible.
 */
export function findNextUpcoming(
  events: CalendarEvent[],
  today: string = todayIso(),
): CalendarEvent | null {
  let best: CalendarEvent | null = null
  for (const event of events) {
    if (!event.dt_start || event.dt_start <= today) continue
    if (event.enum_status === 'CANCELLED') continue
    if (!best || event.dt_start < best.dt_start!) best = event
  }
  return best
}

// ---------------------------------------------------------------------------
// Registration — ADR-030 preserved, ADR-079 §7 entry list decoupled
// ---------------------------------------------------------------------------

/**
 * The registration block is a flow, not a field, and the date computation is
 * subtle enough that rewriting it from memory gets it wrong.
 *
 * - `regCutoff = dt_registration_deadline ?? dt_start`, so the links stay live
 *   until the deadline or, absent one, until the event starts. That fallback is
 *   what keeps them working for the 98 of 103 events with no stored deadline.
 * - The deadline **text** has a stricter test than the links: it needs
 *   `dt_registration_deadline` to be non-null in its own right.
 * - The **entry list is gated on `dt_start > today`**, decoupled from the
 *   registration cutoff, and never shown on a cancelled event (ADR-084 §9).
 *   Who has entered becomes *more* interesting once the list is final, so it
 *   must not share a date with registration.
 */
export function registrationState(
  event: CalendarEvent,
  today: string = todayIso(),
): RegistrationState {
  const deadline = event.dt_registration_deadline
  const regCutoff = deadline ?? event.dt_start ?? null
  const cutoffOpen = !!regCutoff && today <= regCutoff

  const hasStarted = !event.dt_start || event.dt_start <= today

  return {
    regCutoff,
    showDeadline: deadline != null && today <= deadline,
    showRegistrationLink: !!event.url_registration && cutoffOpen,
    showEntryListLink:
      !!event.url_entry_list && !hasStarted && event.enum_status !== 'CANCELLED',
    urgent: !!regCutoff && Date.parse(regCutoff) - Date.parse(today) < 7 * DAY_MS,
    useSpwsModal: event.bool_use_spws_registration === true,
  }
}

// ---------------------------------------------------------------------------
// Country
// ---------------------------------------------------------------------------

/**
 * `txt_country` is free text in mixed languages today — `Polska`, `Germany`,
 * `GRUZJA`, and both `Great Britain` and `United Kingdom` for one country.
 *
 * Returns `null` for anything unrecognised so `CountryFlag` degrades to no
 * flag rather than guessing, which keeps it unblocked by the one-time ISO
 * enrichment pass (ADR-084 §15). Never a per-render web lookup.
 */
export function countryCode(raw: string | null | undefined): string | null {
  const key = (raw ?? '').trim().toLowerCase()
  if (!key) return null
  return ISO_BY_COUNTRY[key] ?? null
}

// ---------------------------------------------------------------------------
// Barrel geometry — ADR-084 §5
// ---------------------------------------------------------------------------

/**
 * Plain panel width, and it MUST match `.ln.mid .p { flex: 0 0 68px }` in
 * CalendarBarrel.svelte. CSS cannot import this, so the two are coupled by
 * convention — the same arrangement as `ROW_H` and `.ln`'s height.
 *
 * It was 48 while the stylesheet rendered 68, which is a quiet failure: every
 * panel still LOOKED right because flex does the real layout, but the caret is
 * positioned from these numbers and so pointed ~20px left of the tile it was
 * meant to indicate, drifting further with each panel across the row.
 *
 * Monthly seams are what allowed the tiles to grow: a row holds at most four
 * events where a quarter held up to nine.
 */
export const PANEL_W = 68
export const PANEL_GAP = 3
/** The selected panel spells its month out in full, so it is never PANEL_W. */
export const PANEL_W_SELECTED = 74
/** …and needs more again when it also carries a city. */
export const PANEL_W_SELECTED_CITY = 78
/** Overlap never tightens past this, or panels stop being separable. */
export const PANEL_STEP_FLOOR = 13

export interface PanelPlacement {
  width: number
  marginLeft: number
  /** `null` while the row fits and paint order is irrelevant. */
  zIndex: number | null
  /** Tighter text tier: 0 comfortable, 1 tight, 2 very tight. */
  textTier: 0 | 1 | 2
}

export interface RowLayout {
  overlapping: boolean
  /** Distance between panel origins. */
  step: number
  panels: PanelPlacement[]
  /**
   * Total width the placed panels occupy.
   *
   * Past `PANEL_STEP_FLOOR` this exceeds `available` — overlap can only absorb
   * so much — so the focused row must stay horizontally scrollable. Clipping it
   * instead would strand the trailing panels: a panel is reachable only by
   * tapping it, and rotation moves between rows, never within one.
   */
  contentWidth: number
}

/**
 * Place a focused row's panels.
 *
 * When they do not fit, panels **fan and overlap at full size** rather than
 * compressing: at 320px a compressed panel stops being legible, whereas an
 * overlapped one still shows an edge. Positions are fixed at `i × step`, and
 * only `zIndex` changes on select, so selecting is a paint operation and never
 * a reflow.
 *
 * `zIndex = 200 − |i − selected| × 2` makes the stack a bidirectional pyramid
 * peaking on the selection, so panels to its left expose their left edge and
 * panels to its right expose their right edge.
 */
export function layoutRow(options: {
  count: number
  selectedIndex: number
  available: number
  selectedHasCity: boolean
}): RowLayout {
  const { count, available, selectedHasCity } = options
  const selectedIndex = Math.max(0, Math.min(count - 1, options.selectedIndex))
  const selectedWidth = selectedHasCity ? PANEL_W_SELECTED_CITY : PANEL_W_SELECTED

  if (count <= 0) {
    return { overlapping: false, step: PANEL_W + PANEL_GAP, panels: [], contentWidth: 0 }
  }

  const widthOf = (i: number) => (i === selectedIndex ? selectedWidth : PANEL_W)

  const flatWidth = (count - 1) * (PANEL_W + PANEL_GAP) + selectedWidth
  if (count === 1 || flatWidth <= available) {
    return {
      overlapping: false,
      step: PANEL_W + PANEL_GAP,
      panels: Array.from({ length: count }, (_, i) => ({
        width: widthOf(i),
        marginLeft: 0,
        zIndex: null,
        textTier: 0 as const,
      })),
      contentWidth: flatWidth,
    }
  }

  const raw = Math.floor((available - selectedWidth) / (count - 1))
  const step = Math.max(PANEL_STEP_FLOOR, Math.min(PANEL_W + PANEL_GAP, raw))
  const textTier: 0 | 1 | 2 = step <= 18 ? 2 : step <= 30 ? 1 : 0

  return {
    overlapping: true,
    step,
    panels: Array.from({ length: count }, (_, i) => ({
      width: widthOf(i),
      marginLeft: i > 0 ? -(PANEL_W - step) : 0,
      zIndex: 200 - Math.abs(i - selectedIndex) * 2,
      textTier,
    })),
    // Origins are fixed at `i × step`, so only the last panel's own width
    // extends past the final origin.
    contentWidth: (count - 1) * step + widthOf(count - 1),
  }
}

/** Half the caret's 12px width, so it points at a panel's centre. */
/** Half the caret's width. MUST match `.crt`'s border-left/right in
    CalendarBarrel.svelte, or the point lands beside the tile it indicates. */
const CARET_HALF = 8

/** Distance from the row's content start to panel `i`'s left edge. */
function panelOrigin(layout: RowLayout, i: number): number {
  if (layout.overlapping) return i * layout.step
  return layout.panels
    .slice(0, i)
    .reduce((sum, p) => sum + p.width + PANEL_GAP, 0)
}

/**
 * Left offset of the content group.
 *
 * Rows are LEFT-ALIGNED: every row starts at the same edge, whatever it holds.
 * Centring was tried twice — on the content and on the selection — and both
 * read as the row drifting, because the amount of blank space changes with the
 * row's width and moves as you rotate. A fixed left edge cannot drift.
 */
function groupOffset(_layout: RowLayout, _available: number): number {
  return 0
}

/**
 * How far the focused row is scrolled.
 *
 * **A row that fits is never scrolled and never shifted** — it stays centred,
 * exactly like the receded rows. Anything else leaves blank space down one
 * side, which reads as the row being stuck against the other. Centring on the
 * selection instead of the content was tried and is precisely that bug: with
 * an early selection the row emptied its left side and ran right.
 *
 * A row that does NOT fit fills the width edge to edge, and scrolls to bring
 * the selection as close to the middle as the ends allow. That is the case the
 * original complaint came from: the row was pinned at scroll 0 and simply ran
 * off the right, taking the selected panel with it.
 */
export function rowScroll(
  layout: RowLayout,
  selectedIndex: number | null,
  available: number,
): number {
  if (selectedIndex == null || available <= 0) return 0
  const panel = layout.panels[selectedIndex]
  if (!panel) return 0
  const maxScroll = Math.max(0, layout.contentWidth - available)
  if (maxScroll === 0) return 0
  const centre = panelOrigin(layout, selectedIndex) + panel.width / 2
  return Math.max(0, Math.min(maxScroll, centre - available / 2))
}

/** Keeps the caret clear of the viewport edges. */
const CARET_MIN_LEFT = 8
const CARET_EDGE_INSET = 20

/**
 * Where the caret sits, in pixels from the row's left edge, or `null` when
 * nothing is selected.
 *
 * It tracks the selected panel through both placements — the centring offset
 * of a row that fits, and the scroll of one that does not — and is clamped to
 * the viewport so it still points the right way when a long row holds its
 * selection at an end that cannot reach the middle.
 */
export function caretOffset(
  layout: RowLayout,
  selectedIndex: number | null,
  available: number,
): number | null {
  if (selectedIndex == null || available <= 0) return null
  const panel = layout.panels[selectedIndex]
  if (!panel) return null
  const centre =
    groupOffset(layout, available) +
    panelOrigin(layout, selectedIndex) +
    panel.width / 2 -
    rowScroll(layout, selectedIndex, available) -
    CARET_HALF
  return Math.max(CARET_MIN_LEFT, Math.min(available - CARET_EDGE_INSET, centre))
}

// ---------------------------------------------------------------------------
// Anchor + composition
// ---------------------------------------------------------------------------

/**
 * Which row the drum opens on.
 *
 * Order of preference: the row holding the next upcoming event, else the
 * row containing today (which may be an empty row — an off-season still
 * wants "now" centred), else the last row so an archived season still has
 * a focal point instead of rendering flat.
 *
 * ADR-084 open items 1 and 2 both land here. The time-sensitive opening policy
 * — show the result for seven days after an event ends, then the next upcoming
 * — is **not** applied yet; this is the mock's next-upcoming default, which was
 * demonstrated but never chosen.
 */
export function resolveAnchorRow(
  rows: MonthRow[],
  nextUpcoming: CalendarEvent | null,
  today: string = todayIso(),
): number {
  if (rows.length === 0) return 0

  if (nextUpcoming?.dt_start) {
    const key = monthKeyOf(nextUpcoming.dt_start)
    const index = rows.findIndex((r) => r.key === key)
    if (index >= 0) return index
  }

  const todayIndex = rows.findIndex((r) => r.key === monthKeyOf(today))
  // An off-season month is empty, and the drum must not rest on it: roll
  // forward to the next month that actually has something in it.
  if (todayIndex >= 0) return settleRow(rows, todayIndex, 1)

  return settleRow(rows, rows.length - 1, -1)
}

/**
 * The row the drum comes to rest on, given a target and a direction of travel.
 *
 * The drum renders quiet months but never STOPS on one — it continues in the
 * direction the user was rotating until it reaches a month with events. At the
 * end of the drum it reverses rather than falling off, so a trailing run of
 * empty months cannot strand the rotation.
 *
 * `direction` is +1 rolling forward in time, -1 rolling back.
 */
export function settleRow(rows: MonthRow[], target: number, direction: 1 | -1): number {
  if (rows.length === 0) return target

  let i = Math.max(0, Math.min(rows.length - 1, target))
  const step = direction >= 0 ? 1 : -1

  // Guarded by the row count: a list with no populated row at all terminates
  // rather than spinning.
  for (let guard = 0; rows[i]?.isEmpty && guard <= rows.length; guard++) {
    const next = i + step
    if (next < 0 || next >= rows.length) {
      // Reverse off the end and take the nearest populated row behind us.
      let back = i
      while (back >= 0 && back < rows.length && rows[back]!.isEmpty) back -= step
      return back >= 0 && back < rows.length ? back : i
    }
    i = next
  }
  return i
}

export type EventTimeState = 'past' | 'grace' | 'soon' | 'future'

/**
 * Two different windows, deliberately not the same number.
 *
 * `RECENT_DAYS` — how long a finished event keeps its colour before receding to
 * grey. Thirty days, because a competition stays worth looking at for about a
 * month after it runs: results arrive late, people compare placings, and the
 * ranking recomputes. ADR-084 open item 1 floated seven days; thirty is the
 * decision.
 *
 * `IMMINENT_DAYS` — how long before an event starts it is emphasised. Seven,
 * because that is a decision horizon: entries close, travel gets booked.
 */
const RECENT_DAYS = 30
const IMMINENT_DAYS = 7

/**
 * Where an event sits in time, which is what the tile's colour encodes.
 *
 * The palette is inverted from the original barrel: the past recedes to grey
 * and what is still ahead carries the colour. On the PROD pool 67 of 114 events
 * are finished, so the old fill — keyed off `enum_status === 'COMPLETED'` —
 * spent the entire colour budget on the majority nobody can act on.
 *
 * Decided by DATE, not by status, and that distinction is the point: an event
 * can sit un-ingested for weeks and still read PLANNED, so a status-driven
 * palette shows a competition that happened in January as though it were
 * upcoming. `grace` keeps a just-finished event coloured for a week, which is
 * ADR-084 open item 1 — proposed there, demonstrated, and never decided until
 * now — and it exists because that is exactly when people come looking for
 * results, and because a month is roughly how long an event stays worth
 * looking at once it has run.
 *
 * An event with no start date is `future`: it cannot be placed, so greying it
 * would assert something we do not know.
 */
export function eventTimeState(
  event: CalendarEvent,
  today: string = todayIso(),
): EventTimeState {
  const start = event.dt_start
  if (!start) return 'future'
  const end = event.dt_end ?? start

  if (end < today) {
    return daysBetween(end, today) <= RECENT_DAYS ? 'grace' : 'past'
  }
  return daysBetween(today, start) <= IMMINENT_DAYS ? 'soon' : 'future'
}

/** Whole days from `a` to `b`, both ISO dates. */
function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(b) - Date.parse(a)) / DAY_MS)
}

/**
 * Whether registration is open — ADR-030 / ADR-079.
 *
 * Open when the event carries a registration URL and has not finished.
 *
 * The URL is the signal because it is not hand-maintained trivia: EventManager's
 * "Rejestracja SPWS" checkbox DERIVES `url_registration` (and `url_entry_list`)
 * when ticked and CLEARS both to '' when unticked — see
 * `onToggleSpwsRegistration()`. So a non-empty URL means an administrator has
 * actually opened registration, and an empty one means they have not. An
 * externally hosted event behaves the same way: a URL exists precisely when
 * there is somewhere to enter.
 *
 * The window closes at `dt_end`, NOT at `dt_registration_deadline`. That is
 * deliberate: this marks a live registration/participation window rather than
 * the availability of the link, so it outlives the card's registration pill,
 * which `registrationState()` retires at the deadline.
 *
 * A cancelled event is never open, whatever URL it carries.
 */
export function isRegistrationOpen(
  event: CalendarEvent,
  today: string = todayIso(),
): boolean {
  if (event.enum_status === 'CANCELLED') return false
  if (!event.url_registration?.trim()) return false
  const closes = event.dt_end ?? event.dt_start
  return !!closes && today <= closes
}


/** The single call the orchestrator makes: filter, bucket, ring, anchor. */
export function buildCalendar(options: {
  events: CalendarEvent[]
  today?: string
  scope: CalendarScope
  showEvfToggle: boolean
}): CalendarModel {
  const today = options.today ?? todayIso()
  const scoped = filterByScope(visibleEvents(options.events, today), options.scope, options.showEvfToggle)
  const rows = buildMonths(scoped)
  const nextUpcoming = findNextUpcoming(scoped, today)
  return { rows, nextUpcoming, anchorIndex: resolveAnchorRow(rows, nextUpcoming, today) }
}
