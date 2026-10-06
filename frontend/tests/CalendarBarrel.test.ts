// CalendarBarrel.svelte — the rotating three-row row drum.
// ADR-084 §§1-7 and its amendments. Test IDs CB.1–CB.50; the 2026-10-06
// amendment (earlier above, ▲ ▼, keyboard) is CB.3, CB.26–CB.29 and CB.35–CB.50.
//
// NOTE ON SCOPE: the overlap geometry is NOT asserted here. jsdom has no layout
// engine, so every clientWidth is 0 and the barrel deliberately falls back to a
// flat row with no inline geometry. The maths lives in `layoutRow` and is
// asserted directly in calendarMonths.test.ts (CQ.59–CQ.69). What this file
// covers is structure, rotation state, detail tiers, tap targets and seams.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import type { CalendarEvent, EventStatus } from '../src/lib/types'
import { buildMonths } from '../src/lib/calendarMonths'
import { tick } from 'svelte'
import { t, setLocale } from '../src/lib/locale.svelte'
import CalendarBarrel from '../src/components/CalendarBarrel.svelte'

let nextId = 1

/** An ISO date `days` from now, for events that must read as clearly ahead. */
function futureIso(days: number): string {
  const d = new Date()
  d.setDate(d.getDate() + days)
  return d.toISOString().slice(0, 10)
}

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

/**
 * Four CONSECUTIVE populated months spanning a season boundary — enough rows
 * that two of them are `far`, which is what proves the DOM is not re-rendered
 * on rotate.
 *
 * The dates are deliberately one month apart. Under the old quarter bucketing
 * they could be spread across a season and still land in adjacent rows; with
 * monthly seams every skipped month materialises as an empty row in between,
 * which would put an empty row where these tests expect a populated one.
 */
function fourRows() {
  return buildMonths([
    ev({ txt_code: 'PPW4-2025-2026', dt_start: '2026-07-21', txt_season_code: 'SPWS-2025-2026' }),
    ev({ txt_code: 'GP8-2025-2026', dt_start: '2026-08-10', txt_season_code: 'SPWS-2025-2026' }),
    ev({ txt_code: 'PEW1efs-2026-2027', dt_start: '2026-09-12', txt_season_code: 'SPWS-2026-2027' }),
    ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26', txt_season_code: 'SPWS-2026-2027' }),
    ev({ txt_code: 'PPW2-2026-2027', dt_start: '2026-10-20', txt_season_code: 'SPWS-2026-2027' }),
  ])
}

/**
 * What the seam should read.
 *
 * `row.label` is the English fallback the model carries. The seam renders a
 * LOCALISED label instead, and the locale defaults to Polish — where a month
 * standing on its own takes the nominative ("Wrzesień"), not the genitive the
 * tile uses beside a day ("26 września"). Asserting against `row.label` would
 * pass only by accident of the two coinciding in English.
 */
function seam(row: { year: number; month: number }): string {
  return `${t(`month_${row.month}`)} ${row.year}`
}

/** The rotateX angle in a transform string, in degrees. */
function rotateXOf(transform: string): number {
  const m = /rotateX\((-?[\d.]+)deg\)/.exec(transform)
  if (!m) throw new Error(`no rotateX in "${transform}"`)
  return Number(m[1])
}

/**
 * Row `i`'s angle on screen: its own angle on the cylinder plus the drum's.
 * A point at angle φ sits at y = −R·sin φ, so a positive angle is ABOVE the
 * focused row (which is at 0) and a negative one below it.
 */
function netAngle(container: HTMLElement, i: number): number {
  const drum = container.querySelector('.drum') as HTMLElement
  const line = container.querySelectorAll('.ln')[i] as HTMLElement
  return rotateXOf(drum.style.transform) + rotateXOf(line.style.transform)
}

function barrel(props: Record<string, unknown> = {}) {
  const rows = (props.rows as ReturnType<typeof buildMonths>) ?? fourRows()
  return render(CalendarBarrel, { props: { rows, ...props } })
}

describe('CalendarBarrel — rotation state', () => {
  // CB.1 — three rows are live at once: focused, one receded above, one below.
  it('CB.1: gives exactly one row the focused state', () => {
    const { container } = barrel({ anchorIndex: 1 })
    expect(container.querySelectorAll('.ln.mid')).toHaveLength(1)
    expect(container.querySelectorAll('.ln.up')).toHaveLength(1)
    expect(container.querySelectorAll('.ln.dn')).toHaveLength(1)
  })

  // CB.2 — rows beyond the neighbours are present but invisible, because the
  // DOM must not re-render on rotate.
  it('CB.2: keeps distant rows in the DOM as far', () => {
    const { container } = barrel({ anchorIndex: 0 })
    const rows = container.querySelectorAll('.ln')
    expect(rows.length).toBeGreaterThan(3)
    expect(container.querySelectorAll('.ln.far').length).toBe(rows.length - 2)
  })

  // CB.3 — the drum is a true cylinder, not a sliding stack. It TURNS by its
  // own angle; each row holds a fixed angle on the cylinder's surface and is
  // never re-transformed, which is what lets a CSS transition animate the
  // rotation at all (a transition cannot cross replaced nodes).
  // R is fixed by the geometry: R = (rowHeight/2) / tan(theta/2)
  //                              = 41 / tan(13deg) = 178px at theta = 26deg.
  it('CB.3: rotates the drum as one body on a cylinder', () => {
    const { container } = barrel({ anchorIndex: 2 })
    const drum = container.querySelector('.drum') as HTMLElement
    expect(drum.style.transform).toBe('translateZ(-178px) rotateX(52deg)')

    const lines = [...container.querySelectorAll('.ln')] as HTMLElement[]
    // Row angles are absolute positions on the surface, independent of `active`.
    // Angles are NEGATIVE and fall with the row index, which lowers later
    // months down the screen: a point at angle theta sits at y = -R*sin(theta).
    // Time therefore runs DOWNWARD — earlier above the focused row, later
    // below — like a list (ADR-084 amendment 2026-10-06, §L). Row 0 renders
    // 0deg, not -0deg.
    expect(lines[0]!.style.transform).toBe('rotateX(0deg) translateZ(178px)')
    expect(lines[1]!.style.transform).toBe('rotateX(-26deg) translateZ(178px)')
    expect(lines[2]!.style.transform).toBe('rotateX(-52deg) translateZ(178px)')
  })

  // CB.35 — what is drawn above the focus, measured from the transforms rather
  // than read off the class names: a row's on-screen angle is its own angle
  // plus the drum's, and a positive angle lifts it up the screen.
  it('CB.35: the row drawn directly above the focus is the previous month', () => {
    const rows = fourRows()
    const { container } = barrel({ rows, anchorIndex: 2 })
    const lines = [...container.querySelectorAll('.ln')] as HTMLElement[]
    const net = lines.map((_, i) => netAngle(container, i))

    const above = net.findIndex((a) => a === 26)
    const below = net.findIndex((a) => a === -26)
    expect(above).toBe(1)
    expect(lines[above]!.classList.contains('up')).toBe(true)
    expect(lines[above]!.querySelector('.sm b')!.textContent).toBe(seam(rows[1]!))
    expect(below).toBe(3)
    expect(lines[below]!.classList.contains('dn')).toBe(true)
    // Every earlier month is above, every later one below.
    net.forEach((a, i) => expect(Math.sign(a)).toBe(Math.sign(2 - i)))
  })

  // CB.36 — the seam is engraved on a row's TOP edge, so the heavier
  // season-boundary rule lies between the boundary row and the row drawn
  // above it. That must be the last month of the previous season.
  it('CB.36: the season line separates two seasons', () => {
    const rows = fourRows()
    const { container } = barrel({ rows, anchorIndex: 2 })
    const b = rows.findIndex((r) => r.isSeasonBoundary)
    expect(b).toBe(2)
    const above = rows.findIndex((_, i) => netAngle(container, i) === netAngle(container, b) + 26)
    expect(above).toBeGreaterThanOrEqual(0)
    expect(rows[above]!.seasonCodes.at(-1)).not.toBe(rows[b]!.seasonCodes[0])
  })

  // CB.3b — rows past the 80deg horizon have turned away from the viewer and
  // are dropped, which is what stops a 66-row drum rendering a solid wall.
  it('CB.3b: fades rows toward the rim and drops them past the horizon', () => {
    const rows = buildMonths(
      Array.from({ length: 9 }, (_, i) =>
        ev({ txt_code: `E${i}`, dt_start: `2026-${String(i + 1).padStart(2, '0')}-10` }),
      ),
    )
    const { container } = barrel({ rows, anchorIndex: 0 })
    const lines = [...container.querySelectorAll('.ln')] as HTMLElement[]
    expect(Number(lines[0]!.style.opacity)).toBe(1)
    expect(Number(lines[1]!.style.opacity)).toBeLessThan(1)
    expect(Number(lines[3]!.style.opacity)).toBeGreaterThan(0) // 78deg, still inside
    expect(Number(lines[4]!.style.opacity)).toBe(0) // 104deg, over the horizon
    expect(lines[4]!.style.pointerEvents).toBe('none')
  })

  // CB.4 — the whole row is the tap target, not a separate control.
  it('CB.4: rotates a receded row to centre when it is tapped', async () => {
    const { container } = barrel({ anchorIndex: 0 })
    const down = container.querySelector('.ln.dn')!
    const labelBefore = container.querySelector('.ln.mid .sm b')!.textContent
    await fireEvent.click(down)
    const labelAfter = container.querySelector('.ln.mid .sm b')!.textContent
    expect(labelAfter).not.toBe(labelBefore)
    expect(container.querySelectorAll('.ln.mid')).toHaveLength(1)
  })

  // CB.5 — keyboard parity for the row target.
  it('CB.5: rotates on Enter', async () => {
    const { container } = barrel({ anchorIndex: 0 })
    const before = container.querySelector('.ln.mid .sm b')!.textContent
    await fireEvent.keyDown(container.querySelector('.ln.dn')!, { key: 'Enter' })
    expect(container.querySelector('.ln.mid .sm b')!.textContent).not.toBe(before)
  })

  // CB.6 — the anchor decides the opening row.
  it('CB.6: opens on the anchor row', () => {
    const rows = fourRows()
    const { container } = barrel({ rows, anchorIndex: 3 })
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[3]!))
  })
})

describe('CalendarBarrel — detail tiers', () => {
  // CB.7 — the focused row shows day, month and code; receded rows drop the
  // month. Both are asserted through the class the stylesheet keys off.
  it('CB.7: renders day, month and code on every panel', () => {
    const { container } = barrel({ anchorIndex: 2 })
    const panel = container.querySelector('.ln.mid .p')!
    expect(panel.querySelector('.dd')!.textContent).toBe('12')
    expect(panel.querySelector('.dm')).not.toBeNull()
    expect(panel.querySelector('.cdc')!.textContent).toBe('EVF1')
  })

  // CB.8 — both month forms are in the DOM; CSS picks by state, so rotating
  // never re-renders.
  it('CB.8: carries both the short and full month on every panel', () => {
    const { container } = barrel({ anchorIndex: 2 })
    const panel = container.querySelector('.ln.mid .p')!
    expect(panel.querySelector('.ms')!.textContent).toBe('wrz')
    expect(panel.querySelector('.mf')!.textContent).toBe('września')
  })

  // CB.9 — the selected panel is the only one carrying a city.
  // CB.9 — the city rides on every FOCUSED tile now, not just the selected one:
  // a monthly row holds at most four events where a quarter held up to nine, so
  // there is room. Receded rows drop it, which is a CSS rule and therefore NOT
  // asserted here — jsdom has no layout or cascade. What this pins is that the
  // node is present and correct on each panel, so selecting is a class change
  // rather than a re-render.
  it('CB.9: carries the city on each focused-row panel', () => {
    const rows = buildMonths([
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26', txt_location: 'Pabianice' }),
      ev({ txt_code: 'PPW2-2026-2027', dt_start: '2026-09-27', txt_location: 'Toruń' }),
    ])
    const { container } = barrel({ rows })
    const panels = [...container.querySelectorAll('.ln.mid .p')]
    expect(panels[0]!.classList.contains('sel')).toBe(true)
    expect(panels[0]!.querySelector('.cty')!.textContent).toBe('Pabianice')
    expect(panels[1]!.querySelector('.cty')!.textContent).toBe('Toruń')
  })

  // CB.33 — the tile's location line is a city or nothing, never a guessed
  // venue. txt_location sometimes holds a venue-only string the scraper wrote
  // into it ("Sporthalle der Städtischen Berufsschule"); splitLocation()
  // classifies that as venue, not city, and the tile used to fall back to
  // printing the raw venue there — cramped, and a poor substitute for a place
  // name in an 11px line. Now that every event can carry a real
  // txt_venue_address (ADR-087's PZSz enrichment; EVF's existing `address`),
  // the full venue string has a proper home on the card's address line and the
  // tile no longer needs to guess. No city means no line.
  it('CB.33: a venue-only location leaves the tile city line empty', () => {
    const rows = buildMonths([
      ev({
        txt_code: 'PEW1-2026-2027',
        dt_start: '2026-09-26',
        txt_location: 'Sporthalle der Städtischen Berufsschule',
      }),
    ])
    const { container } = barrel({ rows })
    const panel = container.querySelector('.ln.mid .p')!
    expect(panel.querySelector('.cty')).toBeNull()
  })

  // CB.34 — the 'Venue - City' pattern still yields the clean city; only the
  // pure-venue case (no city component at all) goes blank.
  it('CB.34: still extracts the city out of a "Venue - City" location', () => {
    const rows = buildMonths([
      ev({ txt_code: 'PEW1-2026-2027', dt_start: '2026-09-26', txt_location: 'Savoy Terrace - Buda' }),
    ])
    const { container } = barrel({ rows })
    const panel = container.querySelector('.ln.mid .p')!
    expect(panel.querySelector('.cty')!.textContent).toBe('Buda')
  })

  // CB.10 — EVF codes shorten on panels; the full code lives on the card.
  it('CB.10: shortens EVF codes and strips the weapon suffix', () => {
    const rows = buildMonths([
      ev({ txt_code: 'PEW63e-2026-2027', dt_start: '2026-09-12' }),
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' }),
    ])
    const { container } = barrel({ rows })
    expect([...container.querySelectorAll('.ln.mid .cdc')].map((c) => c.textContent)).toEqual([
      'EVF63',
      'PPW1',
    ])
  })
})

describe('CalendarBarrel — channels', () => {
  // CB.11 — hue for type, fill for completion, ring for next upcoming. The old
  // strip collapsed the first two into one channel; these must stay separate.
  // CB.11 — the palette is INVERTED and the channels reassigned. Time drives
  // the body (grey once past, tinted while ahead, saturated when imminent);
  // organizer drives the top edge only; the ring still carries next-upcoming.
  // The old `.f` fill keyed off enum_status === 'COMPLETED' and is gone: 67 of
  // 114 PROD events are finished, so it spent the colour on what nobody can act
  // on. Status no longer touches the palette at all.
  it('CB.11: time drives the body, organizer the edge, ring the next-upcoming', () => {
    const longPast = ev({
      txt_code: 'PEW1e-2026-2027',
      dt_start: '2026-01-10',
      dt_end: '2026-01-11',
      enum_status: 'PLANNED', // still un-ingested, and still unmistakably past
    })
    const ahead = ev({ txt_code: 'PPW1-2026-2027', dt_start: futureIso(60) })
    const rows = buildMonths([longPast, ahead])
    const past = barrel({ rows, anchorIndex: 0 })
    const later = barrel({ rows, anchorIndex: rows.length - 1, nextUpcoming: ahead })

    const pastPanel = past.container.querySelector('.ln.mid .p')!
    expect(pastPanel.classList.contains('pew')).toBe(true) // organizer, on the edge
    expect(pastPanel.classList.contains('past')).toBe(true) // time, on the body
    expect(pastPanel.classList.contains('f')).toBe(false) // the old channel is gone

    const aheadPanel = later.container.querySelector('.ln.mid .p')!
    expect(aheadPanel.classList.contains('ppw')).toBe(true)
    expect(aheadPanel.classList.contains('past')).toBe(false)
    expect(aheadPanel.classList.contains('nx')).toBe(true) // ring
  })

  // CB.12 — mpw keeps its own class even though it currently paints like ppw,
  // so the past-season anchor can style it later without new machinery.
  it('CB.12: classes mpw distinctly from ppw', () => {
    const rows = buildMonths([
      ev({ txt_code: 'MPW-2026-2027', dt_start: '2026-09-12' }),
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' }),
    ])
    const { container } = barrel({ rows })
    const panels = [...container.querySelectorAll('.ln.mid .p')]
    expect(panels[0]!.classList.contains('mpw')).toBe(true)
    expect(panels[1]!.classList.contains('ppw')).toBe(true)
  })

  // CB.13 — a cancelled event stays visible while its notice window is open,
  // but reads as withdrawn.
  it('CB.13: dims a cancelled event', () => {
    const rows = buildMonths([
      ev({ txt_code: 'PEW9s-2026-2027', dt_start: '2026-09-12', enum_status: 'CANCELLED' }),
    ])
    const { container } = barrel({ rows })
    expect(container.querySelector('.ln.mid .p')!.classList.contains('canc')).toBe(true)
  })
})

describe('CalendarBarrel — seams', () => {
  // CB.14 — the row label is engraved on every seam.
  it('CB.14: engraves the row label on every row', () => {
    const rows = fourRows()
    const { container } = barrel({ rows })
    const labels = [...container.querySelectorAll('.sm b')].map((b) => b.textContent)
    expect(labels).toEqual(rows.map(seam))
  })

  // CB.45 — a row's accessible name is what the eye reads on its seam, in the
  // page's language (ADR-084 amendment 2026-10-06, §O). It came from
  // monthLabel()'s hard-coded English list, so a Polish page announced
  // "January 2026" under a seam reading „Styczeń 2026".
  it('CB.45: a row is announced by its seam text, and follows a language switch', async () => {
    const rows = fourRows()
    const { container } = barrel({ rows })
    const named = () =>
      [...container.querySelectorAll('.ln')].map((ln) => [ln.getAttribute('aria-label'), ln.querySelector('.sm b')!.textContent])
    try {
      for (const [label, seamText] of named()) expect(label).toBe(seamText)
      expect(named()[2]![0]).toBe('Wrzesień 2026')

      setLocale('en')
      await tick()
      for (const [label, seamText] of named()) expect(label).toBe(seamText)
      expect(named()[2]![0]).toBe('September 2026')
    } finally {
      setLocale('pl')
    }
  })

  // CB.15 — a season boundary takes the heavier rule, and it is marked on
  // every row rather than only the focused one.
  it('CB.15: marks the season boundary seam', () => {
    const rows = fourRows()
    const { container } = barrel({ rows })
    const boundaryIndex = rows.findIndex((q) => q.isSeasonBoundary)
    expect(boundaryIndex).toBeGreaterThan(0)
    const seams = [...container.querySelectorAll('.sm')]
    expect(seams[boundaryIndex]!.classList.contains('bd')).toBe(true)
    expect(seams[0]!.classList.contains('bd')).toBe(false)
  })

  // CB.16 — the season code shows on the focused row and permanently on a
  // boundary; elsewhere the seam stays quiet. This is where the deleted season
  // dropdown's information went.
  it('CB.16: prints the season code on the focused row and on boundaries', () => {
    const rows = fourRows()
    const { container } = barrel({ rows, anchorIndex: 0 })
    const codes = [...container.querySelectorAll('.sm em')].map((e) => e.textContent!.trim())
    const boundaryIndex = rows.findIndex((q) => q.isSeasonBoundary)

    expect(codes[0]).toBe('25/26') // focused
    expect(codes[boundaryIndex]).toBe('26/27') // boundary, though not focused
    const quietIndex = rows.findIndex((q, i) => i !== 0 && !q.isSeasonBoundary)
    expect(codes[quietIndex]).toBe('')
  })

  // CB.17 — an empty row still renders as a row, so the drum does not jump
  // over a quiet stretch of history.
  it('CB.17: renders an empty row with a placeholder', () => {
    const rows = buildMonths([
      ev({ txt_code: 'A-2026-2027', dt_start: '2026-02-10' }),
      ev({ txt_code: 'B-2026-2027', dt_start: '2026-11-20' }),
    ])
    const { container } = barrel({ rows, anchorIndex: 1 })
    expect(container.querySelector('.ln.mid .mt')!.textContent).toBe('brak zawodów')
    expect(container.querySelector('.ln.mid .p')).toBeNull()
  })
})

describe('CalendarBarrel — selection', () => {
  // CB.18 — tapping a panel on the focused row selects that event and reports
  // it upward; the card is driven entirely by this.
  it('CB.18: selects a panel and reports the event', async () => {
    const onselect = vi.fn()
    const rows = buildMonths([
      ev({ txt_code: 'PEW1e-2026-2027', dt_start: '2026-09-12' }),
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' }),
    ])
    const { container } = barrel({ rows, onselect })
    onselect.mockClear()

    const panels = [...container.querySelectorAll('.ln.mid .p')]
    await fireEvent.click(panels[1]!)
    expect(onselect).toHaveBeenCalledOnce()
    expect(onselect.mock.calls[0]![0].txt_code).toBe('PPW1-2026-2027')
    expect(panels[1]!.classList.contains('sel')).toBe(true)
    expect(panels[0]!.classList.contains('sel')).toBe(false)
  })

  // CB.19 — the barrel opens on the ringed event rather than the row's first,
  // so the drum's focal point and the card agree.
  it('CB.19: opens on the next upcoming event within the anchor row', () => {
    const first = ev({ txt_code: 'PEW1e-2026-2027', dt_start: '2026-09-12' })
    const ringed = ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' })
    const onselect = vi.fn()
    const rows = buildMonths([first, ringed])
    const { container } = barrel({ rows, nextUpcoming: ringed, onselect })

    const panels = [...container.querySelectorAll('.ln.mid .p')]
    expect(panels[1]!.classList.contains('sel')).toBe(true)
    expect(onselect).toHaveBeenCalledWith(expect.objectContaining({ txt_code: 'PPW1-2026-2027' }))
  })

  // CB.20 — rotating to a new row selects within it, so the card never shows an
  // event from a row the user is no longer looking at.
  it('CB.20: reselects after rotating to another row', async () => {
    const onselect = vi.fn()
    const rows = fourRows()
    const { container } = barrel({ rows, anchorIndex: 0, onselect })
    onselect.mockClear()

    await fireEvent.click(container.querySelector('.ln.dn')!)
    expect(onselect).toHaveBeenCalledOnce()
    const selectedInMid = container.querySelectorAll('.ln.mid .p.sel')
    expect(selectedInMid).toHaveLength(1)
  })
})

describe('CalendarBarrel — selecting across a rotation', () => {
  // CB.23 — tapping a panel on a RECEDED row rotates that row to centre and
  // selects THE PANEL THAT WAS TAPPED. It used to rotate and then fall back to
  // the row's default (the ringed next-upcoming, else the first event), which
  // threw away the one thing the tap had already said: which event is wanted.
  it('CB.23: carries the tapped event to the card, not the row default', async () => {
    const rows = buildMonths([
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-05' }),
      ev({ txt_code: 'PEW1efs-2026-2027', dt_start: '2026-10-03' }),
      ev({ txt_code: 'PEW2es-2026-2027', dt_start: '2026-10-17' }),
      ev({ txt_code: 'PPW2-2026-2027', dt_start: '2026-10-24' }),
    ])
    const onselect = vi.fn()
    const { container } = render(CalendarBarrel, {
      props: { rows, anchorIndex: 0, onselect },
    })

    // The later month, drawn below the focus, holds three events; tap the THIRD.
    const target = [...container.querySelectorAll('.ln.dn .p')][2]!
    await fireEvent.click(target)

    expect(onselect).toHaveBeenCalled()
    expect(onselect.mock.calls.at(-1)![0].txt_code).toBe('PPW2-2026-2027')
    // and that panel is the selected one on the row now at centre
    const mid = [...container.querySelectorAll('.ln.mid .p')]
    expect(mid[2]!.classList.contains('sel')).toBe(true)
  })

  // CB.24 — tapping the ROW itself (its seam, not a panel) still uses the
  // default, because no event was named.
  it('CB.24: tapping the row body still selects the row default', async () => {
    const rows = buildMonths([
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-05' }),
      ev({ txt_code: 'PEW1efs-2026-2027', dt_start: '2026-10-03' }),
      ev({ txt_code: 'PPW2-2026-2027', dt_start: '2026-10-24' }),
    ])
    const onselect = vi.fn()
    const { container } = render(CalendarBarrel, {
      props: { rows, anchorIndex: 0, onselect },
    })
    await fireEvent.click(container.querySelector('.ln.dn .sm')!)
    expect(onselect.mock.calls.at(-1)![0].txt_code).toBe('PEW1efs-2026-2027')
  })
})

describe('CalendarBarrel — jump back to the opening row', () => {
  /** Nine consecutive months, so the drum can be rolled well away from home. */
  const nine = () =>
    buildMonths(
      Array.from({ length: 9 }, (_, i) =>
        ev({ txt_code: `E${i}-2026-2027`, dt_start: `2026-${String(i + 1).padStart(2, '0')}-10` }),
      ),
    )

  /**
   * Where the control is mounted. When the opening month is drawn BELOW the
   * focus it is pinned to the viewport rather than parented to the lowest
   * seam's row: that row sits three rows below, at -78°, so it inherits
   * rowOpacity 0.19, and it projects ~23px past the viewport's bottom edge
   * where `overflow: hidden` removes it outright. Both were measured on screen
   * before the control was hoisted.
   */
  const mount = (container: HTMLElement) => {
    const j = container.querySelector('.jmp')
    if (!j) return { present: false as const }
    return {
      present: true as const,
      pinned: j.classList.contains('pinned'),
      insideRow: j.closest('.ln') !== null,
      arrow: [...j.querySelector('.arw')!.classList].find((c) => ['up', 'left', 'down'].includes(c)),
    }
  }

  it('CB.25: no control while the drum is already where it opens', () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 4 })
    expect(container.querySelector('.jmp')).toBeNull()
  })

  // The drum went DOWN into the future, so the opening month is drawn above:
  // the control rides the adjacent upper seam — already the shortest possible
  // hop, with nothing to steady. Earlier months are above, so the upper seam
  // is `up` (active − 1). ADR-084 amendment 2026-10-06, §N.
  it('CB.26: points UP from the future, on the upper seam toward the anchor', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 4 })
    // rotate forward, away from the anchor
    await fireEvent.click(container.querySelector('.ln.dn')!)

    const jump = container.querySelector('.jmp') as HTMLElement
    expect(jump).not.toBeNull()
    // Labelled by what the destination IS, not which month it happens to be.
    // Naming the month makes the reader decode a date to know where they land,
    // and it changes under them as the pool moves.
    // The leading arrow is a decorative ICON: it must NOT reach the accessible
    // name, so it is aria-hidden and contributes no text. Asserting the button's
    // whole textContent equals the label is therefore the real guard — folding
    // the arrow back into the translated string would break it.
    const arrow = jump.querySelector('.arw')!
    expect(arrow.tagName.toLowerCase()).toBe('svg')
    expect(arrow.getAttribute('aria-hidden')).toBe('true')
    expect(jump.textContent!.trim()).toBe(t('calendar_jump_to_next'))
    expect(jump.closest('.ln')!.classList.contains('up')).toBe(true)
    // The drum travels vertically, so the glyph names the direction of travel.
    expect(mount(container)).toEqual({ present: true, pinned: false, insideRow: true, arrow: 'up' })
  })

  /**
   * The drum went UP into the past, so the opening month is drawn below. The
   * control stops tracking the focus and pins to the viewport's lower edge,
   * where the lowest seam sits, so it holds one position instead of moving
   * under the reader at every step.
   */
  it('CB.27: two or more rows into the past — DOWN, pinned to the lower edge', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 4 })
    await fireEvent.click(container.querySelector('.ln.up')!) // active 3
    await fireEvent.click(container.querySelector('.ln.up')!) // active 2
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[2]!))

    expect(mount(container)).toEqual({ present: true, pinned: true, insideRow: false, arrow: 'down' })
  })

  // Exactly one row into the past: the anchor is the adjacent row, so the arrow
  // says "it is right there" rather than naming a direction of travel. The
  // control still pins to the lower edge — one home for every such state.
  it('CB.27b: exactly one row into the past — LEFT, pinned to the lower edge', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 4 })
    await fireEvent.click(container.querySelector('.ln.up')!) // active 3
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[3]!))

    expect(mount(container)).toEqual({ present: true, pinned: true, insideRow: false, arrow: 'left' })
  })

  // Near the END of the drum there is no row three below the focus at all; the
  // pinned control does not need one, which is the second reason it is hoisted.
  it('CB.27c: pinned near the end of the drum, where no lower rows exist', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 8 })
    await fireEvent.click(container.querySelector('.ln.up')!) // active 7
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[7]!))

    expect(mount(container)).toEqual({ present: true, pinned: true, insideRow: false, arrow: 'left' })
  })

  // CB.47 — the rule behind CB.26–CB.27c, asserted from the geometry instead of
  // from indices: the arrow points to where the opening month is DRAWN. Up
  // exactly when its on-screen angle puts it above the focus, and then the
  // control rides the seam drawn directly above; otherwise it is pinned, with ←
  // for the adjacent row and ↓ beyond it. Every distance −4…+4.
  it('CB.47: the arrow points to where the opening month is drawn, at every distance', async () => {
    const rows = buildMonths(
      Array.from({ length: 13 }, (_, i) =>
        ev({ txt_code: `E${i}-2026-2027`, dt_start: `${2026 + Math.floor(i / 12)}-${String((i % 12) + 1).padStart(2, '0')}-10` }),
      ),
    )
    const anchor = 6
    for (let d = -4; d <= 4; d++) {
      const { container, unmount } = barrel({ rows, anchorIndex: anchor })
      for (let s = 0; s < Math.abs(d); s++) {
        await fireEvent.click(container.querySelector(d > 0 ? '.ln.dn' : '.ln.up')!)
      }
      expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[anchor + d]!))
      const cue = mount(container)
      if (d === 0) {
        expect(cue.present, `d=${d}`).toBe(false)
      } else if (netAngle(container, anchor) > 0) {
        expect(cue, `d=${d}: drawn above`).toEqual({ present: true, pinned: false, insideRow: true, arrow: 'up' })
        const host = [...container.querySelectorAll('.ln')].indexOf(container.querySelector('.jmp')!.closest('.ln')!)
        expect(netAngle(container, host), `d=${d}: on the seam drawn directly above`).toBe(26)
      } else {
        expect(cue, `d=${d}: drawn below`).toEqual({
          present: true, pinned: true, insideRow: false, arrow: Math.abs(d) === 1 ? 'left' : 'down',
        })
      }
      unmount()
    }
  })

  it('CB.28: tapping it returns to the opening row and selects there', async () => {
    const rows = nine()
    const onselect = vi.fn()
    const { container } = render(CalendarBarrel, { props: { rows, anchorIndex: 6, onselect } })
    await fireEvent.click(container.querySelector('.ln.up')!)
    await fireEvent.click(container.querySelector('.ln.up')!)
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[4]!))

    await fireEvent.click(container.querySelector('.jmp')!)
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[6]!))
    expect(onselect.mock.calls.at(-1)![0].txt_code).toBe(rows[6]!.events[0]!.txt_code)
    // and it stops advertising itself once you are home
    expect(container.querySelector('.jmp')).toBeNull()
  })

  // The row underneath is itself a tap target that rotates ONE step. Without
  // stopPropagation the jump and a single step fight over the same tap —
  // exactly when someone is already lost in the drum.
  //
  // Two rows from the anchor, not one: from one row away the host row IS the
  // anchor, a leaked tap would rotate to where the jump already landed, and the
  // test could not tell the difference. From two, a leaked tap lands one row
  // short. Proven by deleting stopPropagation once (plan §06, recorded run).
  it('CB.29: the tap does not also rotate the row it sits on', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 2 })
    await fireEvent.click(container.querySelector('.ln.dn')!) // active 3
    await fireEvent.click(container.querySelector('.ln.dn')!) // active 4
    const jump = container.querySelector('.jmp')!
    expect(jump.closest('.ln'), 'the control rides a row').not.toBeNull()
    await fireEvent.click(jump)
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[2]!))
  })
})

// ---------------------------------------------------------------------------
// CB.37–CB.43 — the ▲ ▼ step buttons. ADR-084 amendment 2026-10-06, §M.
// They float beside the neighbouring months as siblings of the drum, so they
// are drawn at full opacity and never clipped, and each does exactly what a
// tap on that neighbouring month does.
// ---------------------------------------------------------------------------
describe('CalendarBarrel — the step buttons', () => {
  const nine = () =>
    buildMonths(
      Array.from({ length: 9 }, (_, i) =>
        ev({ txt_code: `E${i}-2026-2027`, dt_start: `2026-${String(i + 1).padStart(2, '0')}-10` }),
      ),
    )

  /** Jan (A), quiet Feb and Mar, Apr (B), May (C). */
  const gappy = () =>
    buildMonths([
      ev({ txt_code: 'A-2026-2027', dt_start: '2026-01-10' }),
      ev({ txt_code: 'B-2026-2027', dt_start: '2026-04-10' }),
      ev({ txt_code: 'C-2026-2027', dt_start: '2026-05-10' }),
    ])

  const focusedLabel = (container: HTMLElement) => container.querySelector('.ln.mid .sm b')!.textContent

  it('CB.37: two labelled buttons beside the drum, ▲ before it and ▼ after it', () => {
    const { container } = barrel({ rows: nine(), anchorIndex: 4 })
    const vp = container.querySelector('.vp')!
    const prev = container.querySelector('button.stp.prev') as HTMLButtonElement
    const next = container.querySelector('button.stp.next') as HTMLButtonElement
    expect(prev.parentElement).toBe(vp)
    expect(next.parentElement).toBe(vp)
    expect(prev.closest('.ln')).toBeNull()
    expect(next.closest('.ln')).toBeNull()
    // DOM order, which is tab order: ▲, the drum, ▼.
    const order = [...vp.children]
    expect(order.indexOf(prev)).toBeLessThan(order.indexOf(container.querySelector('.drum')!))
    expect(order.indexOf(next)).toBeGreaterThan(order.indexOf(container.querySelector('.drum')!))
    expect(prev.type).toBe('button')
    expect(next.type).toBe('button')
    // Named from the locale, in the page's language — never the raw key.
    expect(prev.getAttribute('aria-label')).toBe('Wcześniejsze zawody')
    expect(next.getAttribute('aria-label')).toBe('Późniejsze zawody')
    expect(prev.getAttribute('aria-label')).toBe(t('calendar_step_prev'))
    expect(next.getAttribute('aria-label')).toBe(t('calendar_step_next'))
    // The chevron is decoration; the name is the label alone.
    for (const b of [prev, next]) {
      expect(b.textContent!.trim()).toBe('')
      expect(b.querySelector('svg')!.getAttribute('aria-hidden')).toBe('true')
    }
    // Existing tests count these classes and existing CSS sizes them.
    const forbidden = ['ln', 'up', 'dn', 'p', 'jmp', 'arw']
    for (const el of [prev, next, ...prev.querySelectorAll('*'), ...next.querySelectorAll('*')]) {
      for (const c of forbidden) expect(el.classList.contains(c), `.${c} on a step button`).toBe(false)
    }
  })

  it('CB.38: ▼ steps to the later month, reports one event, and animates', async () => {
    const rows = nine()
    const onselect = vi.fn()
    const { container } = barrel({ rows, anchorIndex: 4, onselect })
    await new Promise((r) => setTimeout(r, 0)) // the opening frame enables animation
    onselect.mockClear()

    await fireEvent.click(container.querySelector('.stp.next')!)
    expect(focusedLabel(container)).toBe(seam(rows[5]!))
    expect(onselect).toHaveBeenCalledOnce()
    expect(onselect.mock.calls[0]![0].txt_code).toBe(rows[5]!.events[0]!.txt_code)
    expect(container.querySelector('.drum')!.classList.contains('anim')).toBe(true)
  })

  it('CB.39: ▲ steps to the earlier month', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 4 })
    await fireEvent.click(container.querySelector('.stp.prev')!)
    expect(focusedLabel(container)).toBe(seam(rows[3]!))
  })

  it('CB.40: ▼ lands where a tap on the lower month lands, empty months skipped', async () => {
    for (const start of [0, 3]) {
      const rows = gappy()
      const byButton = barrel({ rows, anchorIndex: start })
      const byTap = barrel({ rows, anchorIndex: start })
      await fireEvent.click(byButton.container.querySelector('.stp.next')!)
      await fireEvent.click(byTap.container.querySelector('.ln.dn')!)
      expect(focusedLabel(byButton.container)).toBe(focusedLabel(byTap.container))
      expect(byButton.container.querySelector('.ln.mid .p')).not.toBeNull()
      byButton.unmount()
      byTap.unmount()
    }
  })

  it('CB.41: a button is absent where nothing lies further that way', () => {
    const first = barrel({ rows: nine(), anchorIndex: 0 })
    expect(first.container.querySelector('.stp.prev')).toBeNull()
    expect(first.container.querySelector('.stp.next')).not.toBeNull()
    const last = barrel({ rows: nine(), anchorIndex: 8 })
    expect(last.container.querySelector('.stp.next')).toBeNull()
    expect(last.container.querySelector('.stp.prev')).not.toBeNull()
  })

  it('CB.42: when the pressed button disappears, focus passes to the other one', async () => {
    const { container } = barrel({ rows: nine(), anchorIndex: 7 })
    const next = container.querySelector('.stp.next') as HTMLButtonElement
    next.focus()
    await fireEvent.click(next)
    expect(container.querySelector('.stp.next')).toBeNull()
    expect(document.activeElement).toBe(container.querySelector('.stp.prev'))

    const start = barrel({ rows: nine(), anchorIndex: 1 })
    const prev = start.container.querySelector('.stp.prev') as HTMLButtonElement
    prev.focus()
    await fireEvent.click(prev)
    expect(start.container.querySelector('.stp.prev')).toBeNull()
    expect(document.activeElement).toBe(start.container.querySelector('.stp.next'))
  })

  it('CB.43: after ▲ there is one pinned jump control and both buttons', async () => {
    const { container } = barrel({ rows: nine(), anchorIndex: 4 })
    await fireEvent.click(container.querySelector('.stp.prev')!)
    const jumps = container.querySelectorAll('.jmp')
    expect(jumps).toHaveLength(1)
    expect(jumps[0]!.classList.contains('pinned')).toBe(true)
    expect(container.querySelectorAll('.stp')).toHaveLength(2)
  })
})

// ---------------------------------------------------------------------------
// CB.44 — what cannot be seen cannot be reached (ADR-084 amendment 2026-10-06,
// §O). Months two or more rows from the focus are drawn faint or not at all
// and already ignore taps; on the live page 81 of 98 tiles were invisible yet
// reachable by Tab. They are `inert` now. jsdom does not enforce inert, so the
// assertion is that every focusable element in them sits under it.
// ---------------------------------------------------------------------------
describe('CalendarBarrel — turned-away months', () => {
  const FOCUSABLE = 'button, [tabindex]'
  const nine = () =>
    buildMonths(
      Array.from({ length: 9 }, (_, i) =>
        ev({ txt_code: `E${i}-2026-2027`, dt_start: `2026-${String(i + 1).padStart(2, '0')}-10` }),
      ),
    )

  /** Svelte sets the `inert` PROPERTY, which a browser reflects to the
   *  attribute; jsdom does not reflect it, so both are read. */
  const inertUnder = (el: Element) => {
    for (let n: Element | null = el; n; n = n.parentElement) {
      if ((n as HTMLElement).inert || n.hasAttribute('inert')) return true
    }
    return false
  }

  function reachable(container: HTMLElement) {
    const lines = [...container.querySelectorAll('.ln')]
    return lines.map((ln) => ({
      inert: inertUnder(ln),
      open: [ln, ...ln.querySelectorAll(FOCUSABLE)].filter((el) => el.matches(FOCUSABLE) && !inertUnder(el)).length,
    }))
  }

  it('CB.44: nothing in a month two or more rows away is focusable; months within one row are', async () => {
    const { container } = barrel({ rows: nine(), anchorIndex: 4 })
    const check = (active: number) => {
      reachable(container).forEach((row, i) => {
        if (Math.abs(i - active) >= 2) {
          expect(row, `row ${i}, active ${active}`).toEqual({ inert: true, open: 0 })
        } else {
          expect(row.inert, `row ${i}, active ${active}`).toBe(false)
          expect(row.open, `row ${i}, active ${active}`).toBeGreaterThan(0)
        }
      })
    }
    check(4)
    // It follows the drum: rotate, and the inert set moves with the focus.
    await fireEvent.click(container.querySelector('.ln.dn')!)
    check(5)
  })
})

// ---------------------------------------------------------------------------
// CB.46 — a crowded neighbouring month stops before the buttons (D9). A
// receded month's tiles take 41 × n − 3 px, and the buttons start 36 px from
// the drum's right edge (252 px on github.io at 320, 264 px on WordPress), so
// a month of seven would run under them. Its strip now stops 6 px short:
// 36 + 6 = 42 px from the right, and never past 294 px, the mock's cap, kept
// unchanged when the buttons moved to the right edge (CB.53). jsdom has no
// layout engine, so — like CV.W7 — the declaration is pinned; CB.E4 measures
// the result in a browser.
// ---------------------------------------------------------------------------
describe('CalendarBarrel — crowded neighbouring months', () => {
  it('CB.46: a receded row’s strip stops before the buttons; the focused row’s does not', () => {
    const { container } = barrel({ anchorIndex: 2 })
    for (const sel of ['.ln.up .rw', '.ln.dn .rw']) {
      expect(getComputedStyle(container.querySelector(sel)!).maxWidth, sel).toBe('min(calc(100% - 42px), 294px)')
    }
    expect(['', 'none']).toContain(getComputedStyle(container.querySelector('.ln.mid .rw')!).maxWidth)
  })
})

// ---------------------------------------------------------------------------
// CB.53 — ▲ and ▼ sit at the drum's RIGHT edge at every width (the user,
// 6 Oct 2026). The mock's `left: min(calc(100% - 36px), 300px)` was flush right
// only on a drum up to 336 px; on a wider one it held the buttons 300 px from
// the left, which reads as centred. jsdom has no layout engine, so the
// declaration is pinned here and CB.E5 measures the result in a browser.
// ---------------------------------------------------------------------------
describe('CalendarBarrel — step buttons on the right edge', () => {
  it('CB.53: ▲ and ▼ are anchored to the right edge, not offset from the left', () => {
    const { container } = barrel({ anchorIndex: 2 })
    for (const sel of ['.stp.prev', '.stp.next']) {
      const button = container.querySelector(sel)
      expect(button, sel).not.toBeNull()
      const style = getComputedStyle(button!)
      expect(['0', '0px'], `${sel} right`).toContain(style.right)
      expect(['', 'auto'], `${sel} left`).toContain(style.left)
    }
  })
})

// ---------------------------------------------------------------------------
// CB.48–CB.50 — the keyboard (D8 (a); ADR-084 amendment 2026-10-06, §P). With
// focus anywhere in the drum — ▲, ▼, a month, a tile or the jump control —
// ↑ and ↓ step exactly like the buttons, and the page does not scroll for that
// key press. Wheel and swipe are NOT built: they would trap page scrolling.
// ---------------------------------------------------------------------------
describe('CalendarBarrel — the keyboard', () => {
  const nine = () =>
    buildMonths(
      Array.from({ length: 9 }, (_, i) =>
        ev({ txt_code: `E${i}-2026-2027`, dt_start: `2026-${String(i + 1).padStart(2, '0')}-10` }),
      ),
    )
  const focusedLabel = (container: HTMLElement) => container.querySelector('.ln.mid .sm b')!.textContent

  it('CB.48: ↓ with focus in the drum steps to the later month, and the page does not scroll', async () => {
    const rows = nine()
    const onselect = vi.fn()
    const { container } = barrel({ rows, anchorIndex: 4, onselect })
    onselect.mockClear()
    const tile = container.querySelector('.ln.mid .p') as HTMLElement
    tile.focus()
    const notPrevented = await fireEvent.keyDown(tile, { key: 'ArrowDown' })
    expect(notPrevented, 'default prevented').toBe(false)
    expect(focusedLabel(container)).toBe(seam(rows[5]!))
    expect(onselect).toHaveBeenCalledOnce()
  })

  it('CB.49: ↑ with focus in the drum steps to the earlier month, from any control in it', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 4 })
    const prev = container.querySelector('.stp.prev') as HTMLElement
    prev.focus()
    expect(await fireEvent.keyDown(prev, { key: 'ArrowUp' })).toBe(false)
    expect(focusedLabel(container)).toBe(seam(rows[3]!))
    const month = container.querySelector('.ln.up') as HTMLElement
    month.focus()
    expect(await fireEvent.keyDown(month, { key: 'ArrowUp' })).toBe(false)
    expect(focusedLabel(container)).toBe(seam(rows[2]!))
  })

  it('CB.50: arrow keys with focus outside the drum leave it alone', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 4 })
    const outside = document.createElement('button')
    document.body.appendChild(outside)
    try {
      outside.focus()
      for (const key of ['ArrowDown', 'ArrowUp']) {
        expect(await fireEvent.keyDown(outside, { key }), `${key} not prevented`).toBe(true)
        expect(await fireEvent.keyDown(window, { key })).toBe(true)
      }
      expect(focusedLabel(container)).toBe(seam(rows[4]!))
      // Other keys inside the drum are not taken either.
      const tile = container.querySelector('.ln.mid .p') as HTMLElement
      expect(await fireEvent.keyDown(tile, { key: 'ArrowRight' })).toBe(true)
      expect(focusedLabel(container)).toBe(seam(rows[4]!))
    } finally {
      outside.remove()
    }
  })
})

// ---------------------------------------------------------------------------
// CB.30 — the geometry path, which jsdom normally never reaches.
//
// `midLayout` returns early while `available <= 0`, and jsdom reports every
// clientWidth as 0, so every test above this point skips the row-geometry
// branch entirely. Stubbing clientWidth is what makes the branch reachable —
// and it is the branch that took the calendar down on PROD on 2026-09-02.
// ---------------------------------------------------------------------------
describe('CalendarBarrel — a selection that outlives its row', () => {
  function withLayout<T>(run: () => T): T {
    const own = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'clientWidth')
    Object.defineProperty(HTMLElement.prototype, 'clientWidth', { configurable: true, get: () => 900 })
    try {
      return run()
    } finally {
      if (own) Object.defineProperty(HTMLElement.prototype, 'clientWidth', own)
      else delete (HTMLElement.prototype as unknown as Record<string, unknown>).clientWidth
    }
  }

  /** One month, `count` events in it — the focused row of a one-row drum. */
  function monthOf(count: number) {
    return buildMonths(
      Array.from({ length: count }, (_, i) =>
        ev({ txt_code: `PEW${i + 1}-2026-2027`, dt_start: '2026-09-12', txt_location: `Miasto ${i + 1}` }),
      ),
    )
  }

  // CB.30 — the PROD freeze of 2026-09-02. Saving an event refilled the calendar
  // from a narrower query, so a month that had held several events now held one
  // while the barrel still had the fourth of them selected. `midLayout` indexed
  // the row with that stale index, asserted the result non-null, and read
  // `txt_location` off `undefined`. The throw came from a `$derived`, which
  // tears down the component tree: the page kept running but stopped responding
  // to anything at all, the hamburger included, until it was reloaded.
  it('CB.30: survives the event set shrinking under the current selection', async () => {
    await withLayout(async () => {
      const { container, rerender } = render(CalendarBarrel, {
        props: { rows: monthOf(4), anchorIndex: 0 },
      })
      // Select the last tile, then let the row lose it.
      const tiles = container.querySelectorAll('.ln.mid button.p')
      await fireEvent.click(tiles[tiles.length - 1]!)
      await rerender({ rows: monthOf(1), anchorIndex: 0 })
      expect(container.querySelector('.ln.mid')).not.toBeNull()
    })
  })

  // The selection must also come back to something real, not merely avoid the
  // throw: a drum left pointing past the end of its row has no caret and no
  // scroll target.
  it('CB.31: re-points the selection at an event the row still holds', async () => {
    await withLayout(async () => {
      const onselect = vi.fn()
      const { container, rerender } = render(CalendarBarrel, {
        props: { rows: monthOf(4), anchorIndex: 0, onselect },
      })
      const tiles = container.querySelectorAll('.ln.mid button.p')
      await fireEvent.click(tiles[tiles.length - 1]!)
      await rerender({ rows: monthOf(2), anchorIndex: 0, onselect })
      expect(container.querySelectorAll('.ln.mid button.p.sel')).toHaveLength(1)
    })
  })
})

describe('CalendarBarrel — the geometry path under changing data', () => {
  // CB.32 — the systemic guard, and the reason CB.30 was possible at all.
  //
  // Every other test in this file runs with clientWidth 0, where `midLayout`
  // returns before it touches an event. That is most of the barrel's indexing
  // arithmetic, and 700 tests never executed a line of it. This sweep runs the
  // branch WITH layout across the data changes a live calendar actually meets —
  // the set shrinking, growing, emptying, and the row count changing under a
  // selection — because the failure mode is not a wrong pixel but a throw out
  // of a `$derived`, which takes the entire application down with it.
  const cases: Array<{ name: string; from: number; to: number }> = [
    { name: 'shrinks under the selection', from: 5, to: 1 },
    { name: 'shrinks by one', from: 3, to: 2 },
    { name: 'grows', from: 1, to: 4 },
    { name: 'is replaced wholesale', from: 4, to: 4 },
    { name: 'empties', from: 3, to: 0 },
  ]

  for (const c of cases) {
    it(`CB.32 (${c.name}): renders without throwing, and keeps a live selection`, async () => {
      const own = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'clientWidth')
      Object.defineProperty(HTMLElement.prototype, 'clientWidth', { configurable: true, get: () => 900 })
      try {
        const month = (n: number) =>
          buildMonths(
            Array.from({ length: n }, (_, i) =>
              ev({ txt_code: `PEW${i + 1}-2026-2027`, dt_start: '2026-09-12', txt_location: `Miasto ${i + 1}` }),
            ),
          )
        const { container, rerender } = render(CalendarBarrel, {
          props: { rows: month(c.from), anchorIndex: 0 },
        })
        const tiles = container.querySelectorAll('.ln.mid button.p')
        if (tiles.length) await fireEvent.click(tiles[tiles.length - 1]!)
        await rerender({ rows: month(c.to), anchorIndex: 0 })

        // At most one tile is selected, and never a tile the row no longer has.
        const chosen = container.querySelectorAll('.ln.mid button.p.sel')
        expect(chosen.length).toBeLessThanOrEqual(1)
        expect(chosen.length).toBe(c.to === 0 ? 0 : 1)
      } finally {
        if (own) Object.defineProperty(HTMLElement.prototype, 'clientWidth', own)
        else delete (HTMLElement.prototype as unknown as Record<string, unknown>).clientWidth
      }
    })
  }
})
