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
  // CB.3 — a true cylinder, but the ROWS turn and the drum only holds the
  // axis. Each row's angle is relative to the focused one, so no angle ever
  // exceeds the horizon.
  //
  // The alternative — fixed row angles with a rotating drum — fails silently at
  // depth: the drum angle is `-active x theta`, which reaches -1638deg by row
  // 63, and a rotation that large is dropped from the composed matrix outright.
  // The rows kept their own large rotations, nothing cancelled, and the focused
  // row slid further down the screen the further you rolled until its tiles
  // buried the seam below. Relative angles cannot accumulate.
  //
  // R is fixed by the geometry: R = (rowHeight/2) / tan(theta/2)
  //                              = 42 / tan(13deg) = 182px at theta = 26deg.
  it('CB.3: turns the rows, with angles relative to the focused row', () => {
    const { container } = barrel({ anchorIndex: 2 })
    const drum = container.querySelector('.drum') as HTMLElement
    // the drum holds the axis and nothing else
    expect(drum.style.transform).toBe('translateZ(-182px)')

    const lines = [...container.querySelectorAll('.ln')] as HTMLElement[]
    expect(lines[2]!.style.transform).toBe('rotateX(0deg) translateZ(182px)') // focused
    expect(lines[3]!.style.transform).toContain('rotateX(26deg) translateZ(182px)')
    expect(lines[1]!.style.transform).toContain('rotateX(-26deg) translateZ(182px)')
    // receded rows also carry the squeeze
    expect(lines[1]!.style.transform).toContain('scale(')
    expect(lines[2]!.style.transform).not.toContain('scale(')
  })

  // CB.3c — the angle must not grow with depth. This is the regression that
  // broke the drum: at row 63 the drum was asking for -1638deg.
  it('CB.3c: angles stay bounded however deep into the drum you are', () => {
    const rows = buildMonths(
      Array.from({ length: 40 }, (_, i) =>
        ev({ txt_code: `E${i}-2026-2027`, dt_start: `20${26 + Math.floor(i / 12)}-${String((i % 12) + 1).padStart(2, '0')}-10` }),
      ),
    )
    const { container } = barrel({ rows, anchorIndex: 30 })
    const angles = [...container.querySelectorAll('.ln')].map(l => {
      const m = /rotateX\((-?[\d.]+)deg\)/.exec((l as HTMLElement).style.transform)
      return m ? Math.abs(+m[1]) : 0
    })
    expect(Math.max(...angles)).toBeLessThanOrEqual(40 * 26)
    // and the focused row is exactly zero, whatever its index
    expect((container.querySelector('.ln.mid') as HTMLElement).style.transform)
      .toContain('rotateX(0deg)')
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

  it('CB.25: no control while the drum is already where it opens', () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 4 })
    expect(container.querySelector('.jmp')).toBeNull()
  })

  // The control rides the receded row in the DIRECTION the drum must roll, so
  // its position is the direction cue. Index order is chronological and the
  // cylinder puts later months higher, so `dn` (active + 1) renders above.
  it('CB.26: sits on the row toward the anchor, and says what it does', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 6 })
    // rotate backwards, away from the anchor
    await fireEvent.click(container.querySelector('.ln.up')!)

    const jump = container.querySelector('.jmp') as HTMLElement
    expect(jump).not.toBeNull()
    // Labelled by what the destination IS, not which month it happens to be:
    // naming a month makes the reader decode a date, and naming it "today"
    // would be wrong, since today's month is often empty and never rested on.
    expect(jump.textContent!.trim()).toBe(t('calendar_jump_to_next'))
    // `dn` is a later month, which renders ABOVE, so the control pins to the
    // top edge. The edge is the direction cue.
    expect(jump.classList.contains('top')).toBe(true)
    expect(jump.classList.contains('bot')).toBe(false)
    // It is a sibling of the drum, NOT parented to the row it points at.
    // Inside a row it inherited RECEDED_SCALE, so it had to scale by the
    // inverse to stay legible, and the resulting ~52px pill covered that
    // row's tiles. Nesting it again would bring the overlap straight back.
    expect(jump.closest('.ln')).toBeNull()
  })

  it('CB.27: flips to the other side once the anchor is behind you', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 1 })
    await fireEvent.click(container.querySelector('.ln.dn')!)
    await fireEvent.click(container.querySelector('.ln.dn')!)

    const jump = container.querySelector('.jmp')!
    // `up` is an earlier month, which renders BELOW: bottom edge.
    expect(jump.classList.contains('bot')).toBe(true)
    expect(jump.classList.contains('top')).toBe(false)
    expect(jump.closest('.ln')).toBeNull()
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

  // Guards what used to need stopPropagation. The button sat inside a row that
  // is itself a tap target rotating ONE step, so the jump and a single step
  // fought over the same tap — exactly when someone is already lost in the
  // drum. Hoisting it out of the drum removed the conflict at the source; this
  // stays as the regression guard, because re-nesting it would restore it.
  it('CB.29: the tap does not also rotate the row it sits on', async () => {
    const rows = nine()
    const { container } = barrel({ rows, anchorIndex: 6 })
    await fireEvent.click(container.querySelector('.ln.up')!)
    await fireEvent.click(container.querySelector('.jmp')!)
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(seam(rows[6]!))
  })
})
