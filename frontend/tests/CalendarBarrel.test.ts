// CalendarBarrel.svelte — the rotating three-row quarter drum.
// ADR-084 §§1-7. Test IDs CB.1–CB.20.
//
// NOTE ON SCOPE: the overlap geometry is NOT asserted here. jsdom has no layout
// engine, so every clientWidth is 0 and the barrel deliberately falls back to a
// flat row with no inline geometry. The maths lives in `layoutRow` and is
// asserted directly in calendarQuarters.test.ts (CQ.59–CQ.69). What this file
// covers is structure, rotation state, detail tiers, tap targets and seams.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import type { CalendarEvent, EventStatus } from '../src/lib/types'
import { buildQuarters } from '../src/lib/calendarQuarters'
import CalendarBarrel from '../src/components/CalendarBarrel.svelte'

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

/**
 * Four consecutive populated quarters spanning a season boundary — enough rows
 * that two of them are `far`, which is what proves the DOM is not re-rendered
 * on rotate.
 */
function fourQuarters() {
  return buildQuarters([
    ev({ txt_code: 'PPW4-2025-2026', dt_start: '2026-02-21', txt_season_code: 'SPWS-2025-2026' }),
    ev({ txt_code: 'GP8-2025-2026', dt_start: '2026-05-10', txt_season_code: 'SPWS-2025-2026' }),
    ev({ txt_code: 'PEW1efs-2026-2027', dt_start: '2026-09-12', txt_season_code: 'SPWS-2026-2027' }),
    ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26', txt_season_code: 'SPWS-2026-2027' }),
    ev({ txt_code: 'PPW2-2026-2027', dt_start: '2026-11-20', txt_season_code: 'SPWS-2026-2027' }),
  ])
}

function barrel(props: Record<string, unknown> = {}) {
  const quarters = (props.quarters as ReturnType<typeof buildQuarters>) ?? fourQuarters()
  return render(CalendarBarrel, { props: { quarters, ...props } })
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
  it('CB.3: rotates by translating the drum', () => {
    const { container } = barrel({ anchorIndex: 2 })
    const drum = container.querySelector('.drum') as HTMLElement
    expect(drum.style.transform).toBe('translateY(-82px)')
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
  it('CB.6: opens on the anchor quarter', () => {
    const quarters = fourQuarters()
    const { container } = barrel({ quarters, anchorIndex: 3 })
    expect(container.querySelector('.ln.mid .sm b')!.textContent).toBe(quarters[3]!.label)
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
  it('CB.9: puts the city only on the selected panel', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26', txt_location: 'Pabianice' }),
      ev({ txt_code: 'PPW2-2026-2027', dt_start: '2026-09-27', txt_location: 'Toruń' }),
    ])
    const { container } = barrel({ quarters })
    const panels = [...container.querySelectorAll('.ln.mid .p')]
    expect(panels[0]!.classList.contains('sel')).toBe(true)
    expect(panels[0]!.querySelector('.cty')!.textContent).toBe('Pabianice')
    // The unselected panel still has the node — CSS hides it, so selecting is
    // a class change rather than a re-render.
    expect(panels[1]!.querySelector('.cty')!.textContent).toBe('Toruń')
  })

  // CB.10 — EVF codes shorten on panels; the full code lives on the card.
  it('CB.10: shortens EVF codes and strips the weapon suffix', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'PEW63e-2026-2027', dt_start: '2026-09-12' }),
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' }),
    ])
    const { container } = barrel({ quarters })
    expect([...container.querySelectorAll('.ln.mid .cdc')].map((c) => c.textContent)).toEqual([
      'EVF63',
      'PPW1',
    ])
  })
})

describe('CalendarBarrel — channels', () => {
  // CB.11 — hue for type, fill for completion, ring for next upcoming. The old
  // strip collapsed the first two into one channel; these must stay separate.
  it('CB.11: keeps type, completion and next-upcoming on separate channels', () => {
    const completed = ev({
      txt_code: 'PEW1e-2026-2027',
      dt_start: '2026-09-12',
      enum_status: 'COMPLETED',
    })
    const upcoming = ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' })
    const quarters = buildQuarters([completed, upcoming])
    const { container } = barrel({ quarters, nextUpcoming: upcoming })
    const panels = [...container.querySelectorAll('.ln.mid .p')]

    expect(panels[0]!.classList.contains('pew')).toBe(true) // hue
    expect(panels[0]!.classList.contains('f')).toBe(true) // fill
    expect(panels[1]!.classList.contains('ppw')).toBe(true)
    expect(panels[1]!.classList.contains('f')).toBe(false)
    expect(panels[1]!.classList.contains('nx')).toBe(true) // ring
  })

  // CB.12 — mpw keeps its own class even though it currently paints like ppw,
  // so the past-season anchor can style it later without new machinery.
  it('CB.12: classes mpw distinctly from ppw', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'MPW-2026-2027', dt_start: '2026-09-12' }),
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' }),
    ])
    const { container } = barrel({ quarters })
    const panels = [...container.querySelectorAll('.ln.mid .p')]
    expect(panels[0]!.classList.contains('mpw')).toBe(true)
    expect(panels[1]!.classList.contains('ppw')).toBe(true)
  })

  // CB.13 — a cancelled event stays visible while its notice window is open,
  // but reads as withdrawn.
  it('CB.13: dims a cancelled event', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'PEW9s-2026-2027', dt_start: '2026-09-12', enum_status: 'CANCELLED' }),
    ])
    const { container } = barrel({ quarters })
    expect(container.querySelector('.ln.mid .p')!.classList.contains('canc')).toBe(true)
  })
})

describe('CalendarBarrel — seams', () => {
  // CB.14 — the quarter label is engraved on every seam.
  it('CB.14: engraves the quarter label on every row', () => {
    const quarters = fourQuarters()
    const { container } = barrel({ quarters })
    const labels = [...container.querySelectorAll('.sm b')].map((b) => b.textContent)
    expect(labels).toEqual(quarters.map((q) => q.label))
  })

  // CB.15 — a season boundary takes the heavier rule, and it is marked on
  // every row rather than only the focused one.
  it('CB.15: marks the season boundary seam', () => {
    const quarters = fourQuarters()
    const { container } = barrel({ quarters })
    const boundaryIndex = quarters.findIndex((q) => q.isSeasonBoundary)
    expect(boundaryIndex).toBeGreaterThan(0)
    const seams = [...container.querySelectorAll('.sm')]
    expect(seams[boundaryIndex]!.classList.contains('bd')).toBe(true)
    expect(seams[0]!.classList.contains('bd')).toBe(false)
  })

  // CB.16 — the season code shows on the focused row and permanently on a
  // boundary; elsewhere the seam stays quiet. This is where the deleted season
  // dropdown's information went.
  it('CB.16: prints the season code on the focused row and on boundaries', () => {
    const quarters = fourQuarters()
    const { container } = barrel({ quarters, anchorIndex: 0 })
    const codes = [...container.querySelectorAll('.sm em')].map((e) => e.textContent!.trim())
    const boundaryIndex = quarters.findIndex((q) => q.isSeasonBoundary)

    expect(codes[0]).toBe('25/26') // focused
    expect(codes[boundaryIndex]).toBe('26/27') // boundary, though not focused
    const quietIndex = quarters.findIndex((q, i) => i !== 0 && !q.isSeasonBoundary)
    expect(codes[quietIndex]).toBe('')
  })

  // CB.17 — an empty quarter still renders as a row, so the drum does not jump
  // over a quiet stretch of history.
  it('CB.17: renders an empty quarter with a placeholder', () => {
    const quarters = buildQuarters([
      ev({ txt_code: 'A-2026-2027', dt_start: '2026-02-10' }),
      ev({ txt_code: 'B-2026-2027', dt_start: '2026-11-20' }),
    ])
    const { container } = barrel({ quarters, anchorIndex: 1 })
    expect(container.querySelector('.ln.mid .mt')!.textContent).toBe('brak zawodów')
    expect(container.querySelector('.ln.mid .p')).toBeNull()
  })
})

describe('CalendarBarrel — selection', () => {
  // CB.18 — tapping a panel on the focused row selects that event and reports
  // it upward; the card is driven entirely by this.
  it('CB.18: selects a panel and reports the event', async () => {
    const onselect = vi.fn()
    const quarters = buildQuarters([
      ev({ txt_code: 'PEW1e-2026-2027', dt_start: '2026-09-12' }),
      ev({ txt_code: 'PPW1-2026-2027', dt_start: '2026-09-26' }),
    ])
    const { container } = barrel({ quarters, onselect })
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
    const quarters = buildQuarters([first, ringed])
    const { container } = barrel({ quarters, nextUpcoming: ringed, onselect })

    const panels = [...container.querySelectorAll('.ln.mid .p')]
    expect(panels[1]!.classList.contains('sel')).toBe(true)
    expect(onselect).toHaveBeenCalledWith(expect.objectContaining({ txt_code: 'PPW1-2026-2027' }))
  })

  // CB.20 — rotating to a new row selects within it, so the card never shows an
  // event from a row the user is no longer looking at.
  it('CB.20: reselects after rotating to another row', async () => {
    const onselect = vi.fn()
    const quarters = fourQuarters()
    const { container } = barrel({ quarters, anchorIndex: 0, onselect })
    onselect.mockClear()

    await fireEvent.click(container.querySelector('.ln.dn')!)
    expect(onselect).toHaveBeenCalledOnce()
    const selectedInMid = container.querySelectorAll('.ln.mid .p.sel')
    expect(selectedInMid).toHaveLength(1)
  })
})
