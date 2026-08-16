// Calendar quarter barrel — pure derivation layer (ADR-084, Phase 1).
//
// Everything the old month-grouped view derived inline in CalendarView.svelte
// lives here so it can be unit-tested without mounting a component. No Svelte,
// no runes, no DOM. The barrel and the card are presentation only.
//
// Plan: doc/plans/kalendarz-barrel-2026-08-08.html §06.
// Tests: frontend/tests/calendarQuarters.test.ts (CQ.1–CQ.69).

import type { CalendarEvent } from './types'

/**
 * Four buckets, ported from `slotTypeClass()` (CalendarView.svelte:241-246)
 * with the fourth renamed `imew` → `int`.
 *
 * `mpw` is kept distinct even though nothing styles it differently yet. The
 * retired strip classified it separately and then painted it identically to
 * `ppw`; discarding the bucket now would turn the past-season anchor decision
 * (ADR-084 open item 2) into a prerequisite instead of a styling choice.
 */
export type PanelType = 'ppw' | 'mpw' | 'pew' | 'int'

export type CalendarScope = 'all' | 'ppw'

export interface Quarter {
  /** Sortable identity, e.g. `2026-Q4`. */
  key: string
  year: number
  quarter: number
  /** Engraved on the seam above the row, e.g. `4Q26`. */
  label: string
  events: CalendarEvent[]
  /**
   * Every season code present, in chronological order of its first event.
   * A quarter can legitimately hold two seasons — CERT has `PEW8f-2025-2026`
   * sitting among 2024-25 events. An empty quarter inherits the running season
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
  quarters: Quarter[]
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

export function quarterKeyOf(isoDate: string): string {
  const year = Number(isoDate.slice(0, 4))
  const month = Number(isoDate.slice(5, 7))
  return `${year}-Q${Math.floor((month - 1) / 3) + 1}`
}

export function quarterLabel(year: number, quarter: number): string {
  return `${quarter}Q${String(year).slice(2)}`
}

/** `SPWS-2025-2026` → `25/26`; anything unparseable → `''`. */
export function seasonShortCode(code: string | null | undefined): string {
  const match = /(\d{4})-(\d{4})/.exec(code ?? '')
  return match ? `${match[1]!.slice(2)}/${match[2]!.slice(2)}` : ''
}

function stepQuarter(year: number, quarter: number): [number, number] {
  return quarter === 4 ? [year + 1, 1] : [year, quarter + 1]
}

/**
 * Bucket events into a continuous run of quarters.
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
export function buildQuarters(events: CalendarEvent[]): Quarter[] {
  const dated = events
    .filter((e): e is CalendarEvent & { dt_start: string } => !!e.dt_start)
    .slice()
    .sort((a, b) => a.dt_start.localeCompare(b.dt_start) || a.txt_code.localeCompare(b.txt_code))

  if (dated.length === 0) return []

  const byKey = new Map<string, CalendarEvent[]>()
  for (const event of dated) {
    const key = quarterKeyOf(event.dt_start)
    const bucket = byKey.get(key)
    if (bucket) bucket.push(event)
    else byKey.set(key, [event])
  }

  const first = dated[0]!.dt_start
  const last = dated[dated.length - 1]!.dt_start
  let year = Number(first.slice(0, 4))
  let quarter = Math.floor((Number(first.slice(5, 7)) - 1) / 3) + 1
  const lastKey = quarterKeyOf(last)

  const quarters: Quarter[] = []
  let runningSeason: string | null = null

  for (;;) {
    const key = `${year}-Q${quarter}`
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
      // Inherit so the seam keeps showing a season across a quiet quarter.
      seasonCodes = runningSeason ? [runningSeason] : []
    }

    quarters.push({
      key,
      year,
      quarter,
      label: quarterLabel(year, quarter),
      events: rowEvents,
      seasonCodes,
      isSeasonBoundary,
      isEmpty: rowEvents.length === 0,
    })

    if (key === lastKey) break
    ;[year, quarter] = stepQuarter(year, quarter)
  }

  return quarters
}

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

export function panelType(code: string): PanelType {
  if (/^PEW/.test(code)) return 'pew'
  if (/^(IMEW|IMSW|MEW|MSW|PSW)/.test(code)) return 'int'
  if (/^MPW/.test(code)) return 'mpw'
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
export function registryOf(type: PanelType): 'SPWS' | 'EVF' | 'FIE' {
  if (type === 'pew') return 'EVF'
  if (type === 'int') return 'FIE'
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

/** Plain panel width. */
export const PANEL_W = 48
export const PANEL_GAP = 3
/** The selected panel spells its month out in full, so it is never 48px. */
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
const CARET_HALF = 6

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
 * Which quarter the drum opens on.
 *
 * Order of preference: the quarter holding the next upcoming event, else the
 * quarter containing today (which may be an empty row — an off-season still
 * wants "now" centred), else the last quarter so an archived season still has
 * a focal point instead of rendering flat.
 *
 * ADR-084 open items 1 and 2 both land here. The time-sensitive opening policy
 * — show the result for seven days after an event ends, then the next upcoming
 * — is **not** applied yet; this is the mock's next-upcoming default, which was
 * demonstrated but never chosen.
 */
export function resolveAnchorQuarter(
  quarters: Quarter[],
  nextUpcoming: CalendarEvent | null,
  today: string = todayIso(),
): number {
  if (quarters.length === 0) return 0

  if (nextUpcoming?.dt_start) {
    const key = quarterKeyOf(nextUpcoming.dt_start)
    const index = quarters.findIndex((q) => q.key === key)
    if (index >= 0) return index
  }

  const todayIndex = quarters.findIndex((q) => q.key === quarterKeyOf(today))
  if (todayIndex >= 0) return todayIndex

  return quarters.length - 1
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
  const quarters = buildQuarters(scoped)
  const nextUpcoming = findNextUpcoming(scoped, today)
  return { quarters, nextUpcoming, anchorIndex: resolveAnchorQuarter(quarters, nextUpcoming, today) }
}
