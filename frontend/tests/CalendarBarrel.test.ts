// CalendarBarrel.svelte — the rotating three-row row drum.
// ADR-084 §§1-7. Test IDs CB.1–CB.20.
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
import { t } from '../src/lib/locale.svelte'
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

  // CB.3 — rotation is a translateY on the drum, offset so the focused row
  // sits in the middle of the three.
  // CB.3 — the drum is a true cylinder, not a sliding stack. It TURNS by its
  // own angle; each row holds a fixed angle on the cylinder's surface and is
  // never re-transformed, which is what lets a CSS transition animate the
  // rotation at all (a transition cannot cross replaced nodes).
  // R is fixed by the geometry: R = (rowHeight/2) / tan(theta/2)
  //                              = 41 / tan(13deg) = 178px at theta = 26deg.
  it('CB.3: rotates the drum as one body on a cylinder', () => {
    const { container } = barrel({ anchorIndex: 2 })
    const drum = container.querySelector('.drum') as HTMLElement
    expect(drum.style.transform).toBe('translateZ(-178px) rotateX(-52deg)')

    const lines = [...container.querySelectorAll('.ln')] as HTMLElement[]
    // Row angles are absolute positions on the surface, independent of `active`.
    // Angles are POSITIVE and increase with the row index, which lifts later
    // months up the screen: a point at angle theta sits at y = -R*sin(theta).
    // Time therefore runs UPWARD — future above the focused row, past below —
    // inverting the flat drum, where `.ln.up` was `active - 1`.
    expect(lines[0]!.style.transform).toBe('rotateX(0deg) translateZ(178px)')
    expect(lines[1]!.style.transform).toBe('rotateX(26deg) translateZ(178px)')
    expect(lines[2]!.style.transform).toBe('rotateX(52deg) translateZ(178px)')
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

    // The row below holds three events; tap the THIRD one.
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
   * Where the control is mounted. Going FORWARD it is pinned to the viewport
   * rather than parented to the lowest seam's row: that row sits at d = -3, so
   * it inherits rowOpacity 0.19, and it projects ~23px past the viewport's
   * bottom edge where `overflow: hidden` removes it outright. Both were
   * measured on screen before the control was hoisted.
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

  // Going BACK, the control stays on the adjacent upper seam — already the
  // shortest possible hop, with nothing to steady. Index order is chronological
  // and the cylinder puts later months higher, so `dn` (active + 1) is above.
  it('CB.26: points UP from the past, on the seam toward the anchor', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 6 })
    // rotate backwards, away from the anchor
    await fireEvent.click(container.querySelector('.ln.up')!)

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
    expect(jump.closest('.ln')!.classList.contains('dn')).toBe(true)
    // The drum travels vertically, so the glyph names the direction of travel.
    expect(mount(container)).toEqual({ present: true, pinned: false, insideRow: true, arrow: 'up' })
  })

  /**
   * Rolling FORWARD, the control stops tracking the focus and settles at the
   * lowest visible seam, so it holds one position instead of moving under the
   * reader at every step. VISIBLE_SPAN is floor(HORIZON / ROW_ANGLE) =
   * floor(80 / 26) = 3, so the host is `active - 3`.
   */
  it('CB.27: two or more rows into the future — DOWN, at the lowest seam', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 1 })
    await fireEvent.click(container.querySelector('.ln.dn')!) // active 2
    await fireEvent.click(container.querySelector('.ln.dn')!) // active 3
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[3]!))

    expect(mount(container)).toEqual({ present: true, pinned: true, insideRow: false, arrow: 'down' })
  })

  // Exactly one row ahead: the anchor is adjacent, so the arrow says "it is
  // right there" rather than naming a direction of travel. The control still
  // sits at the lowest seam — one home for every forward state.
  it('CB.27b: exactly one row into the future — LEFT, at the lowest seam', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 3 })
    await fireEvent.click(container.querySelector('.ln.dn')!) // active 4
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[4]!))

    expect(mount(container)).toEqual({ present: true, pinned: true, insideRow: false, arrow: 'left' })
  })

  // Near the start of the drum there is no row three below; the host clamps to
  // 0 rather than resolving to a negative index and rendering nothing at all.
  it('CB.27c: the lowest seam clamps to row 0 near the start of the drum', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 0 })
    await fireEvent.click(container.querySelector('.ln.dn')!) // active 1
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[1]!))

    // Near the drum's start there is no row three below at all; the pinned
    // control does not need one, which is the second reason it is hoisted.
    expect(mount(container)).toEqual({ present: true, pinned: true, insideRow: false, arrow: 'left' })
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
  it('CB.29: the tap does not also rotate the row it sits on', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 6 })
    await fireEvent.click(container.querySelector('.ln.up')!)
    await fireEvent.click(container.querySelector('.jmp')!)
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[6]!))
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
