// Plan tests: 6.2, 6.4, 6.10, 6.12 — FilterBar component.
// See doc/archive/POC_development_plan.md §M6 test table.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import FilterBar from '../src/components/FilterBar.svelte'

describe('FilterBar', () => {
  // 11.7 — Season dropdown renders when seasons prop provided
  it('11.7: renders season dropdown as first filter when seasons provided', () => {
    const seasons = [
      { id_season: 1, txt_code: 'SPWS-2024-2025', dt_start: '2024-09-01', dt_end: '2025-06-30', bool_active: false },
      { id_season: 2, txt_code: 'SPWS-2025-2026', dt_start: '2025-09-01', dt_end: '2026-06-30', bool_active: true },
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
    expect(toggleBtns.length).toBe(2) // SPWS, EVF+
  })

  /**
   * 6.2b — the scope toggle reads SPWS / EVF+.
   *
   * ADR-017 records this control in THREE places: here, the drill-down modal
   * and the calendar footer. They were renamed together, so pinning the labels
   * in each is what stops one drifting back and leaving the same control
   * reading two different ways on two screens.
   *
   * The mode VALUES stay 'PPW' and 'KADRA' — those are data, not labels.
   */
  it('6.2b: the scope toggle is labelled SPWS / EVF+', () => {
    const { container } = render(FilterBar, { props: { showEvfToggle: true } })
    expect([...container.querySelectorAll('.toggle-btn')].map((b) => b.textContent!.trim()))
      .toEqual(['SPWS', 'EVF+'])
  })

  // 6.10 — PPW/Kadra toggle hidden by default (showEvfToggle=false)
  it('hides PPW/Kadra toggle when showEvfToggle is false', () => {
    const { container } = render(FilterBar)
    const toggleBtns = container.querySelectorAll('.toggle-btn')
    expect(toggleBtns.length).toBe(0)
  })

  // 6.10 — PPW/Kadra toggle, PPW default when showEvfToggle=true
  it('PPW is active by default when showEvfToggle is true', () => {
    const { container } = render(FilterBar, { props: { showEvfToggle: true } })
    const btns = container.querySelectorAll('.toggle-btn')
    expect(btns[0].classList.contains('active')).toBe(true)
    expect(btns[1].classList.contains('active')).toBe(false)
  })

  // 6.12 — V0 disables +EVF toggle
  it('disables +EVF button when category is V0', () => {
    const { container } = render(FilterBar, { props: { category: 'V0', showEvfToggle: true } })
    const kadraBtn = container.querySelectorAll('.toggle-btn')[1] as HTMLButtonElement
    expect(kadraBtn.disabled).toBe(true)
  })

  // 6.4 — filter change refreshes data
  it('emits filter change on weapon select', async () => {
    const handler = vi.fn()
    const { container } = render(FilterBar, { props: { onfilterchange: handler } })
    const weaponSelect = container.querySelectorAll('select')[0]
    await fireEvent.change(weaponSelect, { target: { value: 'FOIL' } })
    expect(handler).toHaveBeenCalled()
  })

  // 6.12 — V0 forces PPW mode
  it('switches to PPW when V0 selected while in Kadra mode', async () => {
    const handler = vi.fn()
    const { container } = render(FilterBar, {
      props: { mode: 'KADRA', onfilterchange: handler },
    })
    const categorySelect = container.querySelectorAll('select')[2]
    await fireEvent.change(categorySelect, { target: { value: 'V0' } })
    const call = handler.mock.calls[handler.mock.calls.length - 1][0]
    expect(call.mode).toBe('PPW')
  })

})
