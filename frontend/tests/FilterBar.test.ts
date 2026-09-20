// Plan tests: 6.2, 6.4, 6.10, 6.12 — FilterBar component.
// See doc/archive/POC_development_plan.md §M6 test table.
// SS26.UI (design step 7, ADR-101): mode renamed KADRA -> RANKING; toggle
// labels renamed SPWS/EVF+ -> PPW/Ranking; V0 no longer disables Ranking.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import FilterBar from '../src/components/FilterBar.svelte'

describe('FilterBar', () => {
  // 11.7 — Season dropdown renders when seasons prop provided
  it('11.7: renders season dropdown as first filter when seasons provided', () => {
    const seasons = [
      { id_season: 1, txt_code: 'SPWS-2024-2025', dt_start: '2024-09-01', dt_end: '2025-06-30', bool_active: false, enum_ranking_publication: 'PPW_ONLY' as const },
      { id_season: 2, txt_code: 'SPWS-2025-2026', dt_start: '2025-09-01', dt_end: '2026-06-30', bool_active: true, enum_ranking_publication: 'PPW_ONLY' as const },
    ]
    const { container } = render(FilterBar, {
      props: { seasons, selectedSeasonId: 2 },
    })
    const selects = container.querySelectorAll('select')
    expect(selects.length).toBe(4) // season + weapon + gender + category
    // First select should contain season codes
    expect(selects[0].textContent).toContain('SPWS-2025-2026')
  })

  // 6.2 — filter dropdowns rendered
  it('renders all filter controls', () => {
    const { container } = render(FilterBar, { props: { showEvfToggle: true } })
    const selects = container.querySelectorAll('select')
    expect(selects.length).toBe(3) // weapon, gender, category (no seasons passed)
    const toggleBtns = container.querySelectorAll('.toggle-btn')
    expect(toggleBtns.length).toBe(2) // PPW, Ranking
  })

  /**
   * SS26.UI — the scope toggle reads PPW / Ranking (design step 7, ADR-101).
   *
   * ADR-017 originally recorded this control in THREE places: here, the
   * drill-down modal and the calendar footer. Design step 7 renames the
   * combined-mode option from "EVF+" to "Ranking" and the domestic-only
   * option from "SPWS" to "PPW" — the mode VALUES rename in step with the
   * labels this time ('PPW' stays, 'KADRA' becomes 'RANKING'), since the
   * design's own definition of done treats the internal name, not just the
   * display label, as part of the "Ranking/PPW" contract.
   */
  it('SS26.UI: the scope toggle is labelled PPW / Ranking', () => {
    const { container } = render(FilterBar, { props: { showEvfToggle: true } })
    expect([...container.querySelectorAll('.toggle-btn')].map((b) => b.textContent!.trim()))
      .toEqual(['PPW', 'Ranking'])
  })

  // 6.10 — PPW/Ranking toggle hidden by default (showEvfToggle=false)
  it('hides PPW/Ranking toggle when showEvfToggle is false', () => {
    const { container } = render(FilterBar)
    const toggleBtns = container.querySelectorAll('.toggle-btn')
    expect(toggleBtns.length).toBe(0)
  })

  // 6.10 — PPW/Ranking toggle, PPW default when showEvfToggle=true
  it('PPW is active by default when showEvfToggle is true', () => {
    const { container } = render(FilterBar, { props: { showEvfToggle: true } })
    const btns = container.querySelectorAll('.toggle-btn')
    expect(btns[0].classList.contains('active')).toBe(true)
    expect(btns[1].classList.contains('active')).toBe(false)
  })

  // SS26.UI: V0 no longer disables Ranking mode (design step 7 removes the
  // guard — a PZSz senior field admits any age, including V0; §06 of the
  // design: "V0 can use Ranking. Its EVF/FIE subsection is naturally empty,
  // while SPWS and PZSz can contribute.")
  it('SS26.UI: does not disable the Ranking button when category is V0', () => {
    const { container } = render(FilterBar, { props: { category: 'V0', showEvfToggle: true } })
    const rankingBtn = container.querySelectorAll('.toggle-btn')[1] as HTMLButtonElement
    expect(rankingBtn.disabled).toBe(false)
  })

  // SS26.UI: V0 no longer force-flips mode back to PPW.
  it('SS26.UI: selecting V0 while in Ranking mode does not force PPW', async () => {
    const handler = vi.fn()
    const { container } = render(FilterBar, {
      props: { mode: 'RANKING', onfilterchange: handler },
    })
    const categorySelect = container.querySelectorAll('select')[2]
    await fireEvent.change(categorySelect, { target: { value: 'V0' } })
    const call = handler.mock.calls[handler.mock.calls.length - 1][0]
    expect(call.mode).toBe('RANKING')
  })

  // 6.4 — filter change refreshes data
  it('emits filter change on weapon select', async () => {
    const handler = vi.fn()
    const { container } = render(FilterBar, { props: { onfilterchange: handler } })
    const weaponSelect = container.querySelectorAll('select')[0]
    await fireEvent.change(weaponSelect, { target: { value: 'FOIL' } })
    expect(handler).toHaveBeenCalled()
  })

  // SS26.UI: clicking Ranking while on V0 now actually switches (was refused).
  it('SS26.UI: clicking Ranking while category is V0 switches mode', () => {
    const handler = vi.fn()
    const { container } = render(FilterBar, {
      props: { category: 'V0', showEvfToggle: true, onfilterchange: handler },
    })
    const rankingBtn = container.querySelectorAll('.toggle-btn')[1] as HTMLButtonElement
    rankingBtn.click()
    const call = handler.mock.calls[handler.mock.calls.length - 1][0]
    expect(call.mode).toBe('RANKING')
  })
})
