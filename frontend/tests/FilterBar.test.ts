// Plan tests: 6.2, 6.4, 6.10, 6.12 — FilterBar component.
// See doc/POC_development_plan.md §M6 test table.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import FilterBar from '../src/components/FilterBar.svelte'

describe('FilterBar', () => {
  // 6.2 — filter dropdowns rendered
  it('renders all filter controls', () => {
    const { container } = render(FilterBar)
    const selects = container.querySelectorAll('select')
    expect(selects.length).toBe(3) // weapon, gender, category
    const toggleBtns = container.querySelectorAll('.toggle-btn')
    expect(toggleBtns.length).toBe(2) // PPW, Kadra
  })

  // 6.10 — PPW/Kadra toggle, PPW default
  it('PPW is active by default', () => {
    const { container } = render(FilterBar)
    const btns = container.querySelectorAll('.toggle-btn')
    expect(btns[0].classList.contains('active')).toBe(true)
    expect(btns[1].classList.contains('active')).toBe(false)
  })

  // 6.12 — V0 disables Kadra toggle
  it('disables Kadra button when category is V0', () => {
    const { container } = render(FilterBar, { props: { category: 'V0' } })
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

  // 6.17 — env toggle hidden when dualEnv=false
  it('hides env toggle when dualEnv is false', () => {
    const { container } = render(FilterBar, { props: { dualEnv: false } })
    const toggleGroups = container.querySelectorAll('.toggle-group')
    expect(toggleGroups.length).toBe(1) // only PPW/Kadra toggle
  })

  // 6.18 — env toggle visible when dualEnv=true, CERT active by default
  it('shows env toggle when dualEnv is true with CERT active', () => {
    const { container } = render(FilterBar, { props: { dualEnv: true } })
    const toggleGroups = container.querySelectorAll('.toggle-group')
    expect(toggleGroups.length).toBe(2) // PPW/Kadra + CERT/PROD
    const envBtns = toggleGroups[1].querySelectorAll('.toggle-btn')
    expect(envBtns[0].textContent).toBe('CERT')
    expect(envBtns[0].classList.contains('active')).toBe(true)
    expect(envBtns[1].textContent).toBe('PROD')
    expect(envBtns[1].classList.contains('active')).toBe(false)
  })

  // 6.19 — switching env emits onenvchange callback
  it('emits onenvchange when PROD is clicked', async () => {
    const handler = vi.fn()
    const { container } = render(FilterBar, {
      props: { dualEnv: true, onenvchange: handler },
    })
    const toggleGroups = container.querySelectorAll('.toggle-group')
    const prodBtn = toggleGroups[1].querySelectorAll('.toggle-btn')[1]
    await fireEvent.click(prodBtn)
    expect(handler).toHaveBeenCalledWith('PROD')
  })

  // 6.20 — env toggle shows CERT and PROD labels
  it('env toggle displays CERT and PROD labels', () => {
    const { container } = render(FilterBar, { props: { dualEnv: true } })
    const toggleGroups = container.querySelectorAll('.toggle-group')
    const envBtns = toggleGroups[1].querySelectorAll('.toggle-btn')
    expect(envBtns.length).toBe(2)
    expect(envBtns[0].textContent).toBe('CERT')
    expect(envBtns[1].textContent).toBe('PROD')
  })
})
