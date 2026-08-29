// Phase 1 of the calendar barrel redesign — ADR-084.
// Plan: doc/plans/kalendarz-barrel-2026-08-08.html §06 Phase 1.
// Test IDs CQ.1–CQ.75.
//
// This module is pure: no Svelte, no mounting. Everything the old view derived
// inline (CalendarView.svelte) lives here so it can be asserted directly.

import { describe, it, expect } from 'vitest'
import type { CalendarEvent, EventStatus } from '../src/lib/types'
import {
  buildCalendar,
  buildQuarters,
  countryCode,
  filterByScope,
  findNextUpcoming,
  isInternationalEvent,
  isWithinCancellationNoticeWindow,
  movedFromDate,
  panelType,
  quarterKeyOf,
  registrationState,
  resolveAnchorQuarter,
  seasonShortCode,
  visibleEvents,
  allowsFeeTier,
  composeAddress,
  formatDeadline,
  caretOffset,
  rowScroll,
  layoutRow,
  panelLabel,
  registryOf,
  PANEL_W,
  PANEL_GAP,
  PANEL_STEP_FLOOR,
  resultUrls,
  tournamentsPluralKey,
  weaponLetters,
} from '../src/lib/calendarQuarters'

const TODAY = '2026-08-09'

let nextId = 1

function ev(partial: Partial<CalendarEvent> & { txt_code: string }): CalendarEvent {
  return {
    id_event: nextId++,
    txt_name: partial.txt_code,
    id_season: 1,
    txt_season_code: 'SPWS-2026-2027',
    id_organizer: null,
    txt_organizer_name: null,
    txt_location: null,
    txt_country: null,
    txt_venue_address: null,
    url_invitation: null,
    num_entry_fee: null,
    txt_entry_fee_currency: null,
    dt_start: '2026-09-19',
    dt_end: null,
    arr_weapons: [],
    url_event: null,
    enum_status: 'PLANNED' as EventStatus,
    num_tournaments: 1,
    bool_has_international: false,
    url_registration: null,
    dt_registration_deadline: null,
    url_event_2: null,
    url_event_3: null,
    url_event_4: null,
    url_event_5: null,
    ...partial,
  }
}

// ---------------------------------------------------------------------------
// Quarter bucketing
// ---------------------------------------------------------------------------

describe('quarter bucketing', () => {
  // CQ.1 — dt_start decides the bucket, month boundaries included.
  it('CQ.1: buckets by dt_start into calendar quarters', () => {
    expect(quarterKeyOf('2026-01-01')).toBe('2026-Q1')
    expect(quarterKeyOf('2026-03-31')).toBe('2026-Q1')
    expect(quarterKeyOf('2026-04-01')).toBe('2026-Q2')
    expect(quarterKeyOf('2026-09-19')).toBe('2026-Q3')
    expect(quarterKeyOf('2026-12-31')).toBe('2026-Q4')
  })

  // CQ.2 — the multi-season fetch (fetchPriorSeasonEvents) orders by txt_code,
  // so PEW10 arrives before PEW2. The module must sort itself and never
  // inherit caller order. Input here is deliberately shuffled.
  it('CQ.2: sorts by dt_start, never trusting caller order', () => {
    const shuffled = [
      ev({ txt_code: 'PEW10e-2026-2027', dt_start: '2026-11-20' }),
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' }),
      ev({ txt_code: 'PEW2e-2026-2027', dt_start: '2026-10-31' }),
      ev({ txt_code: 'GP1-2026-2027', dt_start: '2026-09-12' }),
    ]
    const quarters = buildQuarters(shuffled)
    const codes = quarters.flatMap((q) => q.events.map((e) => e.txt_code))
    expect(codes).toEqual([
      'GP1-2026-2027',
      'PPW1-2026-2027',
      'PEW2e-2026-2027',
      'PEW10e-2026-2027',
    ])
  })

  // CQ.3 — the seam label the barrel engraves above each row.
  it('CQ.3: labels quarters as NQyy', () => {
    const quarters = buildQuarters([ev({ txt_code: 'PPW1', dt_start: '2026-11-20' })])
    expect(quarters[0]!.label).toBe('4Q26')
  })

  // CQ.4 — continuous history: the drum must not jump over a quiet quarter,
  // so gaps between the first and last populated quarter are materialised.
  it('CQ.4: fills empty quarters between populated ones', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'A', dt_start: '2026-02-10' }),
      ev({ txt_code: 'B', dt_start: '2026-11-20' }),
    ])
    expect(quarters.map((q) => q.key)).toEqual([
      '2026-Q1',
      '2026-Q2',
      '2026-Q3',
      '2026-Q4',
    ])
    expect(quarters[1]!.isEmpty).toBe(true)
    expect(quarters[2]!.isEmpty).toBe(true)
    expect(quarters[0]!.isEmpty).toBe(false)
  })

  // CQ.5 — an event with no dt_start cannot be placed on the drum.
  it('CQ.5: excludes events with a null dt_start', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'DATED', dt_start: '2026-09-19' }),
      ev({ txt_code: 'UNDATED', dt_start: null }),
    ])
    const codes = quarters.flatMap((q) => q.events.map((e) => e.txt_code))
    expect(codes).toEqual(['DATED'])
  })

  // CQ.6 — an empty input yields no rows rather than throwing.
  it('CQ.6: returns an empty list for no events', () => {
    expect(buildQuarters([])).toEqual([])
  })
})

// ---------------------------------------------------------------------------
// Season boundaries
// ---------------------------------------------------------------------------

describe('season boundaries', () => {
  // CQ.7 — crossing a boundary is what drives season state now that the
  // dropdown is gone, so the boundary must be detectable per quarter.
  it('CQ.7: marks the quarter that starts a new season', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'A', dt_start: '2026-05-10', txt_season_code: 'SPWS-2025-2026' }),
      ev({ txt_code: 'B', dt_start: '2026-09-19', txt_season_code: 'SPWS-2026-2027' }),
    ])
    const q2 = quarters.find((q) => q.key === '2026-Q2')!
    const q3 = quarters.find((q) => q.key === '2026-Q3')!
    expect(q2.isSeasonBoundary).toBe(false) // first row is not a boundary
    expect(q3.isSeasonBoundary).toBe(true)
  })

  // CQ.8 — CERT holds quarters spanning two seasons (PEW8f-2025-2026 sits
  // among 2024-25 events). Both codes must survive on the row.
  it('CQ.8: reports every season code present in a mixed quarter', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'A', dt_start: '2026-09-12', txt_season_code: 'SPWS-2025-2026' }),
      ev({ txt_code: 'B', dt_start: '2026-09-26', txt_season_code: 'SPWS-2026-2027' }),
    ])
    expect(quarters[0]!.seasonCodes).toEqual(['SPWS-2025-2026', 'SPWS-2026-2027'])
  })

  // CQ.9 — the seam prints the short form.
  it('CQ.9: shortens a season code to yy/yy', () => {
    expect(seasonShortCode('SPWS-2025-2026')).toBe('25/26')
    expect(seasonShortCode('SPWS-2026-2027')).toBe('26/27')
    expect(seasonShortCode('nonsense')).toBe('')
  })

  // CQ.10 — an empty quarter inherits the running season so the seam does not
  // blank out mid-drum.
  it('CQ.10: carries the running season across an empty quarter', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'A', dt_start: '2026-02-10', txt_season_code: 'SPWS-2025-2026' }),
      ev({ txt_code: 'B', dt_start: '2026-11-20', txt_season_code: 'SPWS-2025-2026' }),
    ])
    const q2 = quarters.find((q) => q.key === '2026-Q2')!
    expect(q2.isEmpty).toBe(true)
    expect(q2.seasonCodes).toEqual(['SPWS-2025-2026'])
    expect(q2.isSeasonBoundary).toBe(false)
  })
})

// ---------------------------------------------------------------------------
// Type split — four buckets, mpw kept distinct (ADR-084 §14)
// ---------------------------------------------------------------------------

describe('panelType', () => {
  // CQ.11 — ported from slotTypeClass (CalendarView.svelte:241-246), with the
  // fourth bucket renamed imew → int.
  it('CQ.11: splits four ways', () => {
    expect(panelType('PPW1-2026-2027')).toBe('ppw')
    expect(panelType('GP1-2026-2027')).toBe('ppw')
    expect(panelType('MPW-2026-2027')).toBe('mpw')
    expect(panelType('PEW3ef-2026-2027')).toBe('pew')
    expect(panelType('IMEW-2026')).toBe('int')
    expect(panelType('IMSW-2026')).toBe('int')
    expect(panelType('MEW-2026')).toBe('int')
    expect(panelType('MSW-2026')).toBe('int')
    expect(panelType('PSW-2026')).toBe('int')
  })

  // CQ.12 — the strip classified MPW separately then painted it as ppw. The
  // bucket is kept so the past-season anchor can style it later without
  // reinstating machinery.
  it('CQ.12: keeps mpw distinct from ppw', () => {
    expect(panelType('MPW-2026-2027')).not.toBe(panelType('PPW1-2026-2027'))
  })

  // CQ.13 — an unknown prefix must not throw; ppw is the fallback.
  it('CQ.13: falls back to ppw on an unknown prefix', () => {
    expect(panelType('VFC-2026')).toBe('ppw')
    expect(panelType('')).toBe('ppw')
  })
})

// ---------------------------------------------------------------------------
// Visibility — ADR-037 / ADR-077 rules ported unchanged
// ---------------------------------------------------------------------------

describe('visibility rules', () => {
  // CQ.14 — CREATED events are dateless planning skeletons (ADR-077).
  it('CQ.14: hides CREATED skeletons', () => {
    const out = visibleEvents(
      [ev({ txt_code: 'SKEL', enum_status: 'CREATED' }), ev({ txt_code: 'REAL' })],
      TODAY,
    )
    expect(out.map((e) => e.txt_code)).toEqual(['REAL'])
  })

  // CQ.15 — ADR-037 amendment: a cancelled event stays visible for seven days
  // after dt_end so the notice is seen, then disappears.
  it('CQ.15: keeps a cancelled event inside the 7-day notice window', () => {
    const inside = ev({
      txt_code: 'CANC',
      enum_status: 'CANCELLED',
      dt_end: '2026-08-05', // 4 days before TODAY
    })
    expect(isWithinCancellationNoticeWindow(inside, TODAY)).toBe(true)
  })

  it('CQ.16: drops a cancelled event past the notice window', () => {
    const outside = ev({
      txt_code: 'CANC',
      enum_status: 'CANCELLED',
      dt_end: '2026-07-01',
    })
    expect(isWithinCancellationNoticeWindow(outside, TODAY)).toBe(false)
    expect(visibleEvents([outside], TODAY)).toEqual([])
  })

  // CQ.17 — the window only ever applies to CANCELLED.
  it('CQ.17: leaves non-cancelled events alone regardless of age', () => {
    const old = ev({ txt_code: 'DONE', enum_status: 'COMPLETED', dt_end: '2024-01-01' })
    expect(isWithinCancellationNoticeWindow(old, TODAY)).toBe(true)
    expect(visibleEvents([old], TODAY)).toHaveLength(1)
  })

  // CQ.18 — a cancelled event with no dt_end has no window to fall out of.
  it('CQ.18: keeps a cancelled event with a null dt_end', () => {
    const noEnd = ev({ txt_code: 'CANC', enum_status: 'CANCELLED', dt_end: null })
    expect(isWithinCancellationNoticeWindow(noEnd, TODAY)).toBe(true)
  })
})

// ---------------------------------------------------------------------------
// Scope filter — ADR-017 as amended by ADR-084 §10
// ---------------------------------------------------------------------------

describe('scope filter', () => {
  // CQ.19 — ported verbatim from CalendarView.svelte:231-233.
  it('CQ.19: isInternationalEvent honours the bool flag', () => {
    expect(isInternationalEvent(ev({ txt_code: 'PPW1', bool_has_international: true }))).toBe(true)
    expect(isInternationalEvent(ev({ txt_code: 'PPW1' }))).toBe(false)
  })

  it('CQ.20: isInternationalEvent honours the code prefixes', () => {
    for (const code of ['PEW1e', 'MEW-2026', 'MSW-2026', 'PSW-2026', 'IMEW-2026', 'IMSW-2026']) {
      expect(isInternationalEvent(ev({ txt_code: code }))).toBe(true)
    }
    expect(isInternationalEvent(ev({ txt_code: 'MPW-2026-2027' }))).toBe(false)
  })

  const mixed = () => [
    ev({ txt_code: 'PPW1-2026-2027' }),
    ev({ txt_code: 'MPW-2026-2027' }),
    ev({ txt_code: 'PEW1e-2026-2027' }),
  ]

  it('CQ.21: ppw scope drops international events', () => {
    const out = filterByScope(mixed(), 'ppw', true)
    expect(out.map((e) => e.txt_code)).toEqual(['PPW1-2026-2027', 'MPW-2026-2027'])
  })

  it('CQ.22: all scope keeps everything', () => {
    expect(filterByScope(mixed(), 'all', true)).toHaveLength(3)
  })

  // CQ.23 — the load-bearing half of ADR-017's amendment: the season config
  // being off constrains the data, not just the buttons. Scope 'all' must not
  // be able to smuggle EVF events past a disabled toggle.
  it('CQ.23: a disabled season toggle forces domestic-only even at scope all', () => {
    const out = filterByScope(mixed(), 'all', false)
    expect(out.map((e) => e.txt_code)).toEqual(['PPW1-2026-2027', 'MPW-2026-2027'])
  })
})

// ---------------------------------------------------------------------------
// Next upcoming
// ---------------------------------------------------------------------------

describe('findNextUpcoming', () => {
  // CQ.24 — the earliest event still ahead of today.
  it('CQ.24: picks the earliest future event', () => {
    const out = findNextUpcoming(
      [
        ev({ txt_code: 'PAST', dt_start: '2026-07-01' }),
        ev({ txt_code: 'SOON', dt_start: '2026-09-12' }),
        ev({ txt_code: 'LATER', dt_start: '2026-11-20' }),
      ],
      TODAY,
    )
    expect(out?.txt_code).toBe('SOON')
  })

  it('CQ.25: returns null when every event is past', () => {
    expect(findNextUpcoming([ev({ txt_code: 'PAST', dt_start: '2020-01-01' })], TODAY)).toBeNull()
  })

  // CQ.26 — derived from the *filtered* set, not assigned once: toggling scope
  // must move the ring.
  it('CQ.26: is derived from the filtered set so scope moves the ring', () => {
    const events = [
      ev({ txt_code: 'PEW1e-2026-2027', dt_start: '2026-09-12' }),
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' }),
    ]
    expect(findNextUpcoming(filterByScope(events, 'all', true), TODAY)?.txt_code)
      .toBe('PEW1e-2026-2027')
    expect(findNextUpcoming(filterByScope(events, 'ppw', true), TODAY)?.txt_code)
      .toBe('PPW1-2026-2027')
  })
})

// ---------------------------------------------------------------------------
// registrationState — ADR-030 preserved, ADR-079 §7 entry list changed
// ---------------------------------------------------------------------------

describe('registrationState', () => {
  // CQ.27 — the subtle computation the plan warns against rewriting from
  // memory: cutoff falls back to dt_start when no deadline is stored, which is
  // what keeps links live for the 98 of 103 events with no deadline.
  it('CQ.27: regCutoff falls back from deadline to dt_start', () => {
    const withDeadline = registrationState(
      ev({ txt_code: 'A', dt_start: '2026-09-19', dt_registration_deadline: '2026-09-06' }),
      TODAY,
    )
    expect(withDeadline.regCutoff).toBe('2026-09-06')

    const withoutDeadline = registrationState(
      ev({ txt_code: 'A', dt_start: '2026-09-19', dt_registration_deadline: null }),
      TODAY,
    )
    expect(withoutDeadline.regCutoff).toBe('2026-09-19')
  })

  // CQ.28 — the deadline *text* has a stricter test than the links: it needs
  // dt_registration_deadline non-null in its own right.
  it('CQ.28: deadline text requires a stored deadline, links do not', () => {
    const noDeadline = registrationState(
      ev({
        txt_code: 'A',
        dt_start: '2026-09-19',
        dt_registration_deadline: null,
        url_registration: 'https://example.test/reg',
      }),
      TODAY,
    )
    expect(noDeadline.showDeadline).toBe(false)
    expect(noDeadline.showRegistrationLink).toBe(true)
  })

  it('CQ.29: hides the registration link once the cutoff has passed', () => {
    const out = registrationState(
      ev({
        txt_code: 'A',
        dt_start: '2026-06-01',
        dt_registration_deadline: '2026-05-01',
        url_registration: 'https://example.test/reg',
      }),
      TODAY,
    )
    expect(out.showRegistrationLink).toBe(false)
    expect(out.showDeadline).toBe(false)
  })

  // CQ.30 — ADR-030's two-tier urgency, unchanged.
  it('CQ.30: flags urgency under seven days to the cutoff', () => {
    const urgent = registrationState(
      ev({ txt_code: 'A', dt_start: '2026-08-12', url_registration: 'https://x.test' }),
      TODAY,
    )
    expect(urgent.urgent).toBe(true)

    const calm = registrationState(
      ev({ txt_code: 'A', dt_start: '2026-10-12', url_registration: 'https://x.test' }),
      TODAY,
    )
    expect(calm.urgent).toBe(false)
  })

  // CQ.31 — THE RULE CHANGE (ADR-084 §9). The entry list is gated on the event
  // not having started, decoupled from the registration cutoff. This is the
  // case the old coupling got wrong: entries closed, event still ahead.
  it('CQ.31: shows the entry list after the deadline while the event is future', () => {
    const out = registrationState(
      ev({
        txt_code: 'A',
        dt_start: '2026-09-19',
        dt_registration_deadline: '2026-08-01', // already passed
        url_entry_list: 'https://example.test/list',
      }),
      TODAY,
    )
    expect(out.showRegistrationLink).toBe(false) // registration is closed
    expect(out.showEntryListLink).toBe(true) // the list is not
  })

  it('CQ.32: hides the entry list once the event has started', () => {
    const out = registrationState(
      ev({
        txt_code: 'A',
        dt_start: '2026-08-01',
        url_entry_list: 'https://example.test/list',
      }),
      TODAY,
    )
    expect(out.showEntryListLink).toBe(false)
  })

  it('CQ.33: never shows the entry list on a cancelled event', () => {
    const out = registrationState(
      ev({
        txt_code: 'A',
        dt_start: '2026-09-19',
        enum_status: 'CANCELLED',
        url_entry_list: 'https://example.test/list',
      }),
      TODAY,
    )
    expect(out.showEntryListLink).toBe(false)
  })

  it('CQ.34: requires a url_entry_list to show the link', () => {
    const out = registrationState(
      ev({ txt_code: 'A', dt_start: '2026-09-19', url_entry_list: null }),
      TODAY,
    )
    expect(out.showEntryListLink).toBe(false)
  })

  // CQ.35 — ADR-079 §7: the in-app modal flag travels with the state.
  it('CQ.35: reports the SPWS modal flag', () => {
    const spws = registrationState(
      ev({
        txt_code: 'A',
        dt_start: '2026-09-19',
        url_registration: 'https://x.test',
        bool_use_spws_registration: true,
      }),
      TODAY,
    )
    expect(spws.useSpwsModal).toBe(true)

    const external = registrationState(
      ev({ txt_code: 'A', dt_start: '2026-09-19', url_registration: 'https://x.test' }),
      TODAY,
    )
    expect(external.useSpwsModal).toBe(false)
  })
})

// ---------------------------------------------------------------------------
// countryCode — CountryFlag must not block on the enrichment pass
// ---------------------------------------------------------------------------

describe('countryCode', () => {
  // CQ.36 — the free-text values actually present in CERT.
  it('CQ.36: maps the known free-text country names', () => {
    expect(countryCode('Polska')).toBe('PL')
    expect(countryCode('Germany')).toBe('DE')
    expect(countryCode('GRUZJA')).toBe('GE')
  })

  // CQ.37 — both spellings of one country resolve to one code.
  it('CQ.37: folds Great Britain and United Kingdom onto GB', () => {
    expect(countryCode('Great Britain')).toBe('GB')
    expect(countryCode('United Kingdom')).toBe('GB')
  })

  // CQ.38 — casing and padding are incidental, not identity.
  it('CQ.38: is insensitive to case and surrounding whitespace', () => {
    expect(countryCode('  polska ')).toBe('PL')
    expect(countryCode('FRANCE')).toBe('FR')
  })

  // CQ.39 — degrade to no flag rather than guessing; this is what keeps
  // CountryFlag unblocked by the ISO enrichment pass.
  it('CQ.39: returns null for unrecognised or empty input', () => {
    expect(countryCode('Ruritania')).toBeNull()
    expect(countryCode('')).toBeNull()
    expect(countryCode(null)).toBeNull()
  })

  // CQ.45 — txt_country is written in both languages, so both resolve.
  it('CQ.45: resolves Polish and English names to the same code', () => {
    const pairs: [string, string, string][] = [
      ['Niemcy', 'Germany', 'DE'],
      ['Włochy', 'Italy', 'IT'],
      ['Węgry', 'Hungary', 'HU'],
      ['Szwecja', 'Sweden', 'SE'],
      ['Łotwa', 'Latvia', 'LV'],
      ['Białoruś', 'Belarus', 'BY'],
      ['Hiszpania', 'Spain', 'ES'],
    ]
    for (const [pl, en, code] of pairs) {
      expect(countryCode(pl), pl).toBe(code)
      expect(countryCode(en), en).toBe(code)
    }
  })

  // CQ.46 — identity and rendering are separate concerns. GB resolves cleanly
  // even though CountryFlag has no Union-flag primitive and draws nothing for
  // it; the card then shows the place without a chip.
  it('CQ.46: resolves codes that have no drawable flag', () => {
    expect(countryCode('United Kingdom')).toBe('GB')
    expect(countryCode('Great Britain')).toBe('GB')
    expect(countryCode('Wielka Brytania')).toBe('GB')
  })
})

// ---------------------------------------------------------------------------
// Card field derivation — ADR-084 §8, §12, §14
// ---------------------------------------------------------------------------

describe('card field derivation', () => {
  // CQ.47 — the second status chip: which body owns the event.
  it('CQ.47: maps a panel type to its registry', () => {
    expect(registryOf('ppw')).toBe('SPWS')
    expect(registryOf('mpw')).toBe('SPWS')
    expect(registryOf('pew')).toBe('EVF')
    expect(registryOf('int')).toBe('FIE')
  })

  // CQ.48 — weapons come from the code suffix (ADR-046), not arr_weapons,
  // which sits on its all-three default for 102 of 103 events.
  it('CQ.48: reads weapons from the code suffix', () => {
    expect(weaponLetters('PEW3ef-2026-2027')).toEqual(['E', 'F'])
    expect(weaponLetters('PEW12s-2026-2027')).toEqual(['S'])
    expect(weaponLetters('PEW1efs-2026-2027')).toEqual(['E', 'F', 'S'])
  })

  it('CQ.49: normalises suffix order and returns nothing when unsuffixed', () => {
    expect(weaponLetters('PEW9sfe-2026-2027')).toEqual(['E', 'F', 'S'])
    expect(weaponLetters('PPW1-2026-2027')).toEqual([])
    expect(weaponLetters('MPW-2026-2027')).toEqual([])
  })

  // CQ.50 — a tier can only exist where the tier does. A foil-only event has
  // no two-weapon price to quote.
  it('CQ.50: gates fee tiers on the event weapon count', () => {
    expect(allowsFeeTier('PEW12s-2026-2027', 2)).toBe(false)
    expect(allowsFeeTier('PEW3ef-2026-2027', 2)).toBe(true)
    expect(allowsFeeTier('PEW3ef-2026-2027', 3)).toBe(false)
    expect(allowsFeeTier('PEW1efs-2026-2027', 3)).toBe(true)
  })

  // CQ.51 — unknown weapon coverage must not suppress real pricing.
  it('CQ.51: allows tiers when the weapon count is unknown', () => {
    expect(allowsFeeTier('PPW1-2026-2027', 2)).toBe(true)
    expect(allowsFeeTier('PPW1-2026-2027', 3)).toBe(true)
  })

  // CQ.52 — ADR-030's deadline format.
  it('CQ.52: formats the deadline as dd/mm/yyyy', () => {
    expect(formatDeadline('2026-09-06')).toBe('06/09/2026')
    expect(formatDeadline('2026-12-31')).toBe('31/12/2026')
  })

  // CQ.53 — the Polish three-form plural, including the 12–14 genitive trap
  // that the current flat `tournaments_count` string gets wrong in production.
  it('CQ.53: picks the Polish plural form by count', () => {
    expect(tournamentsPluralKey(1)).toBe('tournaments_one')
    expect(tournamentsPluralKey(2)).toBe('tournaments_few')
    expect(tournamentsPluralKey(4)).toBe('tournaments_few')
    expect(tournamentsPluralKey(5)).toBe('tournaments_many')
    expect(tournamentsPluralKey(0)).toBe('tournaments_many')
  })

  it('CQ.54: takes the genitive for 12-14 but not 22-24', () => {
    for (const n of [12, 13, 14]) expect(tournamentsPluralKey(n), `${n}`).toBe('tournaments_many')
    for (const n of [22, 23, 24]) expect(tournamentsPluralKey(n), `${n}`).toBe('tournaments_few')
    expect(tournamentsPluralKey(112)).toBe('tournaments_many')
  })

  // CQ.55 — ADR-040: equal-status slots, compacted, labelled at render time.
  it('CQ.55: collects result URLs in slot order, closing gaps', () => {
    const event = ev({
      txt_code: 'A',
      url_event: 'https://a.test',
      url_event_2: null,
      url_event_3: 'https://c.test',
    })
    expect(resultUrls(event)).toEqual(['https://a.test', 'https://c.test'])
    expect(resultUrls(ev({ txt_code: 'A' }))).toEqual([])
  })

  // CQ.56 — the clipboard carries the country even though the card shows only
  // a flag, because a pasted string cannot see the flag.
  it('CQ.56: composes the full address for the clipboard', () => {
    expect(
      composeAddress({ venue: 'Complexe Sportif', city: 'Nevers', country: 'Francja' }),
    ).toBe('Complexe Sportif, Nevers, Francja')
    expect(composeAddress({ city: 'Pabianice', country: 'Polska' })).toBe('Pabianice, Polska')
    expect(composeAddress({ venue: null, city: null, country: null })).toBe('')
  })
})

// ---------------------------------------------------------------------------
// Panel labels + barrel geometry — ADR-084 §5
// ---------------------------------------------------------------------------

describe('panelLabel', () => {
  // CQ.57 — a panel is 48px, so EVF codes shorten. The weapon suffix goes
  // because it bought nothing once the weapon filter was dropped.
  it('CQ.57: shortens EVF codes to EVF + number', () => {
    expect(panelLabel('PEW63e-2026-2027')).toBe('EVF63')
    expect(panelLabel('PEW1efs-2026-2027')).toBe('EVF1')
    expect(panelLabel('PEW12s-2026-2027')).toBe('EVF12')
  })

  // CQ.58 — domestic codes keep their identity, minus the weapon letters.
  it('CQ.58: keeps domestic codes, dropping the weapon suffix', () => {
    expect(panelLabel('PPW1-2026-2027')).toBe('PPW1')
    expect(panelLabel('MPW-2026-2027')).toBe('MPW')
    expect(panelLabel('GP4-2026-2027')).toBe('GP4')
    expect(panelLabel('MSW-2026')).toBe('MSW')
  })
})

describe('layoutRow', () => {
  // CQ.59 — the plan's acceptance criterion, exactly: five panels flat at
  // 320px, six fanning. Verified here rather than in a component test, because
  // jsdom has no layout engine and every clientWidth there is 0.
  it('CQ.59: five panels sit flat at 320px, six fan', () => {
    const five = layoutRow({ count: 5, selectedIndex: 0, available: 320, selectedHasCity: false })
    expect(five.overlapping).toBe(false)

    const six = layoutRow({ count: 6, selectedIndex: 0, available: 320, selectedHasCity: false })
    expect(six.overlapping).toBe(true)
  })

  // CQ.60 — panels never shrink. Overlap trades visibility for size, because a
  // compressed panel at 320px stops being legible while an overlapped one
  // still shows an edge.
  it('CQ.60: keeps every panel at full width when overlapping', () => {
    const out = layoutRow({ count: 10, selectedIndex: 4, available: 304, selectedHasCity: true })
    expect(out.overlapping).toBe(true)
    for (const [i, p] of out.panels.entries()) {
      expect(p.width, `panel ${i}`).toBe(i === 4 ? 78 : PANEL_W)
    }
  })

  // CQ.61 — the exact geometry measured against the live mock: a ten-panel
  // quarter at 320px fans at step 25, i.e. margin-left -23.
  it('CQ.61: reproduces the mock geometry for a ten-panel quarter', () => {
    const out = layoutRow({ count: 10, selectedIndex: 4, available: 304, selectedHasCity: true })
    expect(out.step).toBe(25)
    expect(out.panels[0]!.marginLeft).toBe(0)
    for (const p of out.panels.slice(1)) expect(p.marginLeft).toBe(-23)
  })

  // CQ.62 — z-index peaks on the selection so panels to its left expose their
  // left edge and panels to its right expose their right edge.
  it('CQ.62: builds the z-index pyramid around the selection', () => {
    const out = layoutRow({ count: 10, selectedIndex: 4, available: 304, selectedHasCity: true })
    expect(out.panels.map((p) => p.zIndex)).toEqual([
      192, 194, 196, 198, 200, 198, 196, 194, 192, 190,
    ])
  })

  // CQ.63 — the selected panel spells its month out in full, so it can never
  // be a plain 48px; a city needs more again.
  it('CQ.63: widens the selected panel, more so when it carries a city', () => {
    const plain = layoutRow({ count: 3, selectedIndex: 1, available: 320, selectedHasCity: false })
    expect(plain.panels[1]!.width).toBe(74)

    const withCity = layoutRow({ count: 3, selectedIndex: 1, available: 320, selectedHasCity: true })
    expect(withCity.panels[1]!.width).toBe(78)
  })

  // CQ.64 — overlap has a floor: past it, panels stop being separable.
  it('CQ.64: never tightens the step past the floor', () => {
    const out = layoutRow({ count: 40, selectedIndex: 0, available: 320, selectedHasCity: false })
    expect(out.step).toBe(PANEL_STEP_FLOOR)
  })

  // CQ.65 — and a ceiling: the step never exceeds the flat pitch, or panels
  // would drift apart instead of overlapping.
  it('CQ.65: never widens the step past the flat pitch', () => {
    const out = layoutRow({ count: 6, selectedIndex: 0, available: 5000, selectedHasCity: false })
    expect(out.overlapping).toBe(false)
    expect(out.step).toBe(PANEL_W + PANEL_GAP)
  })

  // CQ.66 — while the row fits, paint order is irrelevant and no z-index is
  // emitted, so selecting cannot trigger a repaint of the whole row.
  it('CQ.66: emits no z-index while the row fits', () => {
    const out = layoutRow({ count: 3, selectedIndex: 1, available: 320, selectedHasCity: false })
    for (const p of out.panels) {
      expect(p.zIndex).toBeNull()
      expect(p.marginLeft).toBe(0)
    }
  })

  // CQ.67 — text tightens as the step does, so a code still fits its panel.
  it('CQ.67: tightens the text tier as the step narrows', () => {
    expect(layoutRow({ count: 3, selectedIndex: 0, available: 320, selectedHasCity: false })
      .panels[0]!.textTier).toBe(0)
    expect(layoutRow({ count: 12, selectedIndex: 0, available: 320, selectedHasCity: false })
      .panels[0]!.textTier).toBe(1)
    expect(layoutRow({ count: 30, selectedIndex: 0, available: 320, selectedHasCity: false })
      .panels[0]!.textTier).toBe(2)
  })

  // CQ.68 — degenerate rows must not throw or divide by zero.
  it('CQ.68: handles empty and single-panel rows', () => {
    expect(layoutRow({ count: 0, selectedIndex: 0, available: 320, selectedHasCity: false }).panels)
      .toEqual([])
    const one = layoutRow({ count: 1, selectedIndex: 0, available: 40, selectedHasCity: false })
    expect(one.overlapping).toBe(false)
    expect(one.panels).toHaveLength(1)
  })

  // CQ.69 — an out-of-range selection is clamped rather than producing a
  // lopsided pyramid.
  it('CQ.69: clamps the selected index into range', () => {
    const out = layoutRow({ count: 6, selectedIndex: 99, available: 200, selectedHasCity: false })
    expect(out.panels[5]!.zIndex).toBe(200)
    expect(out.panels[5]!.width).toBe(74)
  })

  // CQ.70 — past the step floor the row genuinely outgrows the viewport. The
  // layout must SAY so, because the barrel has to keep the focused row
  // scrollable (the mock's `.rw{overflow-x:auto}`) or those trailing panels
  // become unreachable: there is no rotation path to a panel, only a tap.
  it('CQ.70: reports a content width that outgrows the viewport past the floor', () => {
    const fits = layoutRow({ count: 21, selectedIndex: 0, available: 320, selectedHasCity: false })
    expect(fits.step).toBe(PANEL_STEP_FLOOR)
    expect(fits.contentWidth).toBe(308)
    expect(fits.contentWidth).toBeLessThanOrEqual(320)

    const spills = layoutRow({ count: 22, selectedIndex: 0, available: 320, selectedHasCity: false })
    expect(spills.step).toBe(PANEL_STEP_FLOOR)
    expect(spills.contentWidth).toBe(321)
    expect(spills.contentWidth).toBeGreaterThan(320)
  })
})

describe('caretOffset and rowScroll', () => {
  // CQ.71 — a row that FITS is centred and never scrolled, focused or not.
  // Shifting it toward the selection empties one side, which reads as the row
  // being stuck against the other — the exact defect this replaced.
  it('CQ.71: never scrolls or shifts a row that fits', () => {
    const layout = layoutRow({ count: 3, selectedIndex: 0, available: 320, selectedHasCity: false })
    expect(layout.contentWidth).toBeLessThanOrEqual(320)
    expect(rowScroll(layout, 0, 320)).toBe(0)
    expect(rowScroll(layout, 2, 320)).toBe(0)
  })

  // CQ.72 — a row that does NOT fit scrolls to bring the selection toward the
  // middle, clamped so the ends stay flush and no blank edge ever appears.
  it('CQ.72: scrolls an overflowing row, keeping both ends flush', () => {
    const layout = layoutRow({ count: 30, selectedIndex: 0, available: 320, selectedHasCity: false })
    const maxScroll = layout.contentWidth - 320
    expect(maxScroll).toBeGreaterThan(0)

    expect(rowScroll(layout, 0, 320)).toBe(0)
    expect(rowScroll(layout, 29, 320)).toBe(maxScroll)

    const middle = rowScroll(layout, 15, 320)
    expect(middle).toBeGreaterThan(0)
    expect(middle).toBeLessThan(maxScroll)
  })

  // CQ.73 — the caret follows the selection. Rows are left-aligned, so for a
  // row that fits this is just the panel's own offset: 48 + 3 gap + half of
  // the 74px selected panel, less half the caret.
  it('CQ.73: tracks the selected panel whether the row is left-aligned or scrolled', () => {
    const fits = layoutRow({ count: 3, selectedIndex: 1, available: 320, selectedHasCity: false })
    expect(caretOffset(fits, 1, 320)).toBe(48 + PANEL_GAP + 74 / 2 - 6)

    const spills = layoutRow({ count: 30, selectedIndex: 15, available: 320, selectedHasCity: false })
    const caret = caretOffset(spills, 15, 320)!
    expect(caret).toBeGreaterThan(8)
    expect(caret).toBeLessThan(300)
  })

  // CQ.74 — a selection at an end cannot reach the middle, so the caret must
  // stay inside the viewport rather than pointing off it.
  it('CQ.74: keeps the caret on screen for a selection at either end', () => {
    const layout = layoutRow({ count: 30, selectedIndex: 0, available: 320, selectedHasCity: false })
    for (const i of [0, 29]) {
      const c = caretOffset(layout, i, 320)!
      expect(c, `index ${i}`).toBeGreaterThanOrEqual(8)
      expect(c, `index ${i}`).toBeLessThanOrEqual(300)
    }
  })

  // CQ.75 — nothing selected, nothing to place.
  it('CQ.75: reports no caret and no scroll without a selection', () => {
    const layout = layoutRow({ count: 0, selectedIndex: 0, available: 320, selectedHasCity: false })
    expect(caretOffset(layout, null, 320)).toBeNull()
    expect(rowScroll(layout, null, 320)).toBe(0)
  })
})

// ---------------------------------------------------------------------------
// Composition + anchor
// ---------------------------------------------------------------------------

describe('buildCalendar', () => {
  // CQ.40 — the single call the orchestrator makes: filter, bucket, ring.
  it('CQ.40: composes visibility, scope, bucketing and next-upcoming', () => {
    const events = [
      ev({ txt_code: 'SKEL', enum_status: 'CREATED', dt_start: '2026-09-01' }),
      ev({ txt_code: 'PEW1e-2026-2027', dt_start: '2026-09-12' }),
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' }),
    ]
    const out = buildCalendar({ events, today: TODAY, scope: 'ppw', showEvfToggle: true })
    const codes = out.quarters.flatMap((q) => q.events.map((e) => e.txt_code))
    expect(codes).toEqual(['PPW1-2026-2027'])
    expect(out.nextUpcoming?.txt_code).toBe('PPW1-2026-2027')
  })

  // CQ.41 — an archived season has no future event; the drum must still anchor
  // somewhere rather than returning -1 and rendering flat.
  it('CQ.41: anchors on the last quarter when nothing is upcoming', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'OLD1', dt_start: '2023-10-01' }),
      ev({ txt_code: 'OLD2', dt_start: '2024-02-01' }),
    ])
    const idx = resolveAnchorQuarter(quarters, null, TODAY)
    expect(idx).toBe(quarters.length - 1)
  })

  // CQ.42 — with a next-upcoming event, the drum opens on its quarter.
  it('CQ.42: anchors on the quarter holding the next upcoming event', () => {
    const soon = ev({ txt_code: 'SOON', dt_start: '2026-11-20' })
    const quarters = buildQuarters([ev({ txt_code: 'PAST', dt_start: '2026-02-01' }), soon])
    const idx = resolveAnchorQuarter(quarters, soon, TODAY)
    expect(quarters[idx]!.key).toBe('2026-Q4')
  })

  // CQ.43 — off-season: today sits in a quarter the calendar has no events
  // for. Anchor on that quarter anyway so "now" stays centred.
  it('CQ.43: anchors on the quarter containing today when it exists but is empty', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'SPRING', dt_start: '2026-04-01' }),
      ev({ txt_code: 'WINTER', dt_start: '2026-12-01' }),
    ])
    const idx = resolveAnchorQuarter(quarters, null, TODAY)
    // TODAY is 2026-08-09 → Q3, which exists as an empty row.
    expect(quarters[idx]!.key).toBe('2026-Q3')
  })

  it('CQ.44: returns 0 for an empty drum', () => {
    expect(resolveAnchorQuarter([], null, TODAY)).toBe(0)
  })
})


// ---------------------------------------------------------------------------
// movedFromDate — the "moved from" pill (ADR-077 amendment)
//
// CHANGED was designed to flag an EVF reschedule and never implemented. The
// replacement is a pill, and its whole value is that it never cries wolf: every
// date change in recorded history sat on a COMPLETED event and was a data
// repair, not a reschedule. The three conditions below are what keep it silent.
// ---------------------------------------------------------------------------
describe('movedFromDate', () => {
  const TODAY = '2026-08-28'
  const AHEAD = '2027-01-23'
  const ANCHOR = '2026-12-12'

  it('returns the first published date when a future PLANNED event moved', () => {
    const e = ev({
      txt_code: 'PEW7es-2026-2027',
      enum_status: 'PLANNED',
      dt_start: AHEAD,
      dt_start_first_published: ANCHOR,
    })
    expect(movedFromDate(e, TODAY)).toBe(ANCHOR)
  })

  it('returns null when the date never moved', () => {
    const e = ev({
      txt_code: 'PEW7es-2026-2027',
      enum_status: 'PLANNED',
      dt_start: AHEAD,
      dt_start_first_published: AHEAD,
    })
    expect(movedFromDate(e, TODAY)).toBeNull()
  })

  it('stays silent once the event is in the past', () => {
    const e = ev({
      txt_code: 'PEW8es-2025-2026',
      enum_status: 'PLANNED',
      dt_start: '2026-05-02',
      dt_start_first_published: '2025-03-29',
    })
    expect(movedFromDate(e, TODAY)).toBeNull()
  })

  it('stays silent on any status other than PLANNED', () => {
    for (const status of ['CREATED', 'IN_PROGRESS', 'SCORED', 'COMPLETED', 'CANCELLED'] as EventStatus[]) {
      const e = ev({
        txt_code: 'PEW9ef-2023-2024',
        enum_status: status,
        dt_start: AHEAD,
        dt_start_first_published: ANCHOR,
      })
      expect(movedFromDate(e, TODAY)).toBeNull()
    }
  })

  it('stays silent when the anchor is missing', () => {
    const e = ev({
      txt_code: 'PEW7es-2026-2027',
      enum_status: 'PLANNED',
      dt_start: AHEAD,
      dt_start_first_published: null,
    })
    expect(movedFromDate(e, TODAY)).toBeNull()
  })

  it('anchors to the FIRST published date, not the previous one', () => {
    const e = ev({
      txt_code: 'PEW5efs-2026-2027',
      enum_status: 'PLANNED',
      dt_start: '2027-01-09',
      dt_start_first_published: '2026-12-12',
    })
    expect(movedFromDate(e, TODAY)).toBe('2026-12-12')
  })
})
